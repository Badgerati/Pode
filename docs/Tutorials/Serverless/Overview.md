# Serverless

Pode has support for being used within a serverless context, such as Azure Functions or AWS Lambda, helping you with routing, but also leveraging middleware, authentication, and other features of Pode.

## Usage

When you use Pode in a serverless environment, the server logic is run once, and the route logic immediately parsed; any response is returned, and the server disposed. Unlike the normal web-server logic of Pode, when in serverless the server logic doesn't continually loop.

The server, when in a serverless environment, should be supplied the request object that is supplied to your Functions/Lambda script. You'll also need to specify which environment your server is running under:

```powershell
Start-PodeServer -Request <request> -Type 'AzureFunctions' {
    # route logic
}
```

## Unsupported Features

Unfortunately not all the features of Pode can be used within a serverless environment. Below is a list of functions from Pode that cannot be used when running under serverless:

* [`Access`](../../../Functions/Middleware/Access)
* [`Gui`](../../../Functions/Core/Gui)
* [`Handler`](../../../Functions/Core/Handler)
* [`Limit`](../../../Functions/Middleware/Limit)
* [`Listen`](../../../Functions/Core/Listen)
* [`Logger`](../../../Functions/Core/Logger)
* [`Schedule`](../../../Functions/Core/Schedule)
* [`Tcp`](../../../Functions/Utility/Tcp)
* [`Timer`](../../../Functions/Core/Timer)

And the below is a list of some features that aren't supported:

* File Monitoring
* Server Restarting