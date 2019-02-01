import ballerina/http;
import ballerina/log;
import ballerina/runtime;
import ballerina/time;

// ***** This service acts as a backend and is not exposed via playground samples ******


public int counter = 1;

listener http:Listener ep = new(9095);

@http:ServiceConfig {basePath:"/legacy"}
service legacy_time on ep {
    @http:ResourceConfig{
        path: "/localtime",  methods: ["GET"]
    }
    resource function getTime (http:Caller caller, http:Request request) {
        http:Response response = new;

        time:Time currentTime = time:currentTime();
        string customTimeString = time:format(currentTime, "HH:mm:ss");

        if (counter % 5 == 0) {
            log:printInfo("Legacy Service : Behavior - Slow");
            runtime:sleep(1000);
            counter = counter + 1;
            response.setPayload(customTimeString);
            var result = caller -> respond(response);
            handleError(result);
        } else if (counter % 5 == 3) {
            counter = counter + 1;
            response.statusCode = 500;
            log:printInfo("Legacy Service : Behavior - Faulty");
            response.setPayload("Internal error occurred while processing the request.");
            var result = caller -> respond(response);
            handleError(result);
        } else {
            log:printInfo("Legacy Service : Behavior - Normal");
            counter = counter + 1;
            response.setPayload(customTimeString);
            var result = caller -> respond(response);
            handleError(result);
        }
    }
}

function handleError(error? result) {
    if (result is error) {
        log:printError(result.reason(), err = result);
    }
}
