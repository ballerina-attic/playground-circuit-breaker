import ballerina/http;
import ballerina/io;

string previousRes;

endpoint http:Listener listener {
  port:9090
};

// Endpoint with circuit breaker can short circuit responses
// under some conditions. Circuit flips to OPEN state when
// errors or responses take longer than timeout. OPEN circuits
// bypass endpoint and return error.
endpoint http:Client legacyServiceResilientEP {
  // URL of the remote service.
  url: "http://localhost:9095",
  circuitBreaker: {

    // Failure calculation window.
    rollingWindow: {
      // Duration of the window.
      timeWindowMillis: 10000,

      // Each time window is divided into buckets.
      bucketSizeMillis: 2000,

      // Minimum number of requests in a `RollingWindow` that will trip the circuit.
      requestVolumeThreshold: 0
    },
    // Percentage of failures allowed.
    failureThreshold: 0,

    // Reset circuit to CLOSED state after timeout.
    resetTimeMillis: 1000,

    // Error codes that open the circuit.
    statusCodes: [400, 404, 500]
  },

  // Invocation timeout - independent of circuit.
  timeoutMillis: 2000
};

@http:ServiceConfig {
  basePath:"/resilient/time"
}
service<http:Service> timeInfo bind listener {

  @http:ResourceConfig {
    methods:["GET"],
    path:"/"
  }
  getTime (endpoint caller, http:Request req) {

    var response = legacyServiceResilientEP
        -> get("/legacy/localtime");

    // Match response for successful or failed messages.
    match response {

      // Circuit breaker not tripped, process response.
      http:Response res => {
        http:Response okResponse = new;
        if (res.statusCode == 200) {
          string payloadContent = check res.getTextPayload();
          // Verify that the request payload doesn't contain
          // any malicious data.
          previousRes = untaint payloadContent;
          okResponse.setTextPayload(untaint payloadContent);
          io:println("Remote service OK, data received");
        } else {
            // Remote endpoint returns an error.
            io:println("Error received from remote service.");
            okResponse.setTextPayload("Previous Response : "
                + previousRes);
        }
        okResponse.statusCode = http:OK_200;
        _ = caller -> respond(okResponse);
      }

      // Circuit breaker tripped and generates error.
      error err => {
        http:Response errResponse = new;
        // Use the last successful response.
        io:println("Circuit open, using cached data");
        errResponse.setTextPayload( "Previous Response : "
            + previousRes);

        // Inform client service is unavailable.
        errResponse.statusCode = http:OK_200;
        _ = caller -> respond(errResponse);
      }
    }
  }
}
