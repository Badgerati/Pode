# Serverless

Pode has support for being used within a serverless context - such as Azure Functions or AWS Lambda - helping you with routing, but also leveraging middleware, authentication, and other features of Pode.

## Usage

When you use Pode in a serverless environment, the server logic is run once, and the route logic immediately parsed; any response is returned, and the server disposed. Unlike the normal web-server logic of Pode, when in serverless the server logic doesn't continually loop.

The server, when in a serverless environment, should be supplied the request object that is supplied to your Functions/Lambda script. You'll also need to specify which environment your server is running under:

```powershell
Start-PodeServer -Request <request> -Type 'AzureFunctions' {
    # route logic
}
```

## Unsupported Features

Unfortunately not all the features of Pode can be used within a serverless environment. Below is a list of features in Pode that cannot be used when running in a serverless context:

* Access Middleware.
* Limit Middleware.
* Opening your server as a GUI.
* TCP/Service Handler logic.
* Listening on endpoints (as Azure/AWS does this for you).
* Logging.
* Schedules.
* Timers.
* File Monitoring.
* Server Restarting.
