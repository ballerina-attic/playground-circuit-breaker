import ballerina/http;
import ballerina/io;
import ballerina/time;
import ballerina/runtime;


// ***** This service acts as a backend and is not exposed via playground samples ******


public  int counter = 1;

endpoint http:Listener listener {
    port:9095
};
@http:ServiceConfig {basePath:"/legacy"}
service<http:Service> legacy_time bind listener {
    @http:ResourceConfig{
        path: "/localtime",  methods: ["GET"]
    }
    getTime (endpoint caller, http:Request request) {
        http:Response response = new;

        time:Time currentTime = time:currentTime();
        string customTimeString = currentTime.format("HH:mm:ss");

        if (counter % 5 == 0) {
            io:println("Legacy Service : Behavior - Slow");
            runtime:sleep(1000);
            counter = counter + 1;
            response.setTextPayload(customTimeString);
            _ = caller -> respond(response);
        } else if (counter % 5 == 3) {
            counter = counter + 1;
            response.statusCode = 500;
            io:println("Legacy Service : Behavior - Faulty");
            response.setTextPayload("Internal error occurred while processing the request.");
            _ = caller -> respond(response);
        } else {
            io:println("Legacy Service : Behavior - Normal");
            counter = counter + 1;
            response.setTextPayload(customTimeString);
            _ = caller -> respond(response);
        }
    }
}