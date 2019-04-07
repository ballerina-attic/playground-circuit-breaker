import ballerina/http;
import ballerina/log;

string previousRes = "";

listener http:Listener ep = new(9090);

// Endpoint with circuit breaker can short circuit responses under
// some conditions. Circuit flips to OPEN state when errors or
// responses take longer than timeout. OPEN circuits bypass
// endpoint and return error.
http:Client legacyServiceResilientEP = new("http://localhost:9095",
  config = {
      circuitBreaker: {
        // Failure calculation window.
        rollingWindow: {
          // Duration of the window
          timeWindowMillis: 10000,

          // Each time window is divided into buckets.
          bucketSizeMillis: 2000,

          // Min # of requests in a `RollingWindow` to trip.
          requestVolumeThreshold: 0
        },

        // Percentage of failures allowed.
        failureThreshold: 0.0,

        // Reset circuit to CLOSED state after timeout.
        resetTimeMillis: 1000,

        // Error codes that open the circuit.
        statusCodes: [400, 404, 500]
    },

  // Invocation timeout - independent of circuit.
  timeoutMillis: 2000
});

@http:ServiceConfig {
  basePath:"/resilient/time"
}
service timeInfo on ep {

  @http:ResourceConfig {
    methods:["GET"],
    path:"/"
  }
  resource function getTime(http:Caller caller, http:Request req)
                                                 returns error? {

    var response = legacyServiceResilientEP->
                    get("/legacy/localtime");

    if (response is http:Response) {

      // Circuit breaker not tripped.
        http:Response okResponse = new;
        if (response.statusCode == 200) {

          string payloadContent = check response.getTextPayload();
          previousRes = untaint payloadContent;
          okResponse.setPayload(untaint payloadContent);
          log:printInfo("Remote service OK, data received");

        } else {

            // Remote endpoint returns an error.
            log:printError("Error received from remote service.");
            okResponse.setPayload("Previous Response : "
                                  + previousRes);

        }
        okResponse.statusCode = http:OK_200;
        _ = check caller->respond(okResponse);

    } else {

        // Circuit breaker tripped and generates error
        http:Response errResponse = new;
        log:printInfo("Circuit open, using cached data");
        errResponse.setPayload( "Previous Response : "
                                + previousRes);

        // Inform client service unavailability.
        errResponse.statusCode = http:OK_200;
        _ = check caller->respond(errResponse);
    }
    return;
  }
}
