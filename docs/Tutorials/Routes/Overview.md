# Overview

Routes in Pode allow you to bind logic that should be invoked when a users call certain paths on a URL, for a specific HTTP method, against your server. Routes allow you to host REST APIs and Web Pages, as well as using custom Middleware for logic such as authentication.

You can also create static routes, that redirect requests for static content to internal directories.

Routes can also be bound against a specific protocol or endpoint. This allows you to bind multiple root (`/`) routes against different endpoints - if you're listening to multiple endpoints.

!!! info
    The following HTTP methods are supported by routes in Pode:
    DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, and TRACE.

## Usage

To setup and use Routes in Pode you should use the Routing functions. For example, let's say you want a basic `GET /ping` endpoint to just return `pong` as a JSON response:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/ping' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'pong'; }
    }
}
```

Here, anyone who calls `http://localhost:8080/ping` will receive the following response:

```json
{
    "value": "pong"
}
```

The scriptblock for the route will be supplied with a single argument that contains information about the current [web event](../../WebEvent). This argument will contain the `Request` and `Response` objects, `Data` (from POST), and the `Query` (from the query string of the URL), as well as any `Parameters` from the route itself (eg: `/:accountId`).

## Payloads

The following is an example of using data from a request's payload - ie, the data in the body of POST request. To retrieve values from the payload you can use the `.Data` hashtable on the supplied web-session to a route's logic. This example will get the `userId` and "find" user, returning the users data:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Post -Path '/users' -ScriptBlock {
        # get the user
        $user = Get-DummyUser -UserId $WebEvent.Data.userId

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/users' -Method Post -Body '{ "userId": 12345 }' -ContentType 'application/json'
```

!!! important
    The `ContentType` is required as it informs Pode on how to parse the requests payload. For example, if the content type were `application/json`, then Pode will attempt to parse the body of the request as JSON - converting it to a hashtable.

!!! important
    On PowerShell 4 and 5, referencing JSON data on `$WebEvent.Data` must be done as `$WebEvent.Data.userId`. This also works in PowerShell 6+, but you can also use `$WebEvent.Data['userId']` on PowerShell 6+.

## Query Strings

The following is an example of using data from a request's query string. To retrieve values from the query string you can use the `.Query` hashtable on the supplied web-session to a route's logic. This example will return a user based on the `userId` supplied:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users' -ScriptBlock {
        # get the user
        $user = Get-DummyUser -UserId $WebEvent.Query['userId']

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/users?userId=12345' -Method Get
```

## Parameters

The following is an example of using values supplied on a request's URL using parameters. To retrieve values that match a request's URL parameters you can use the `.Parameters` hashtable on the supplied web-session to a route's logic. This example will get the `:userId` and "find" user, returning the users data:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users/:userId' -ScriptBlock {
        # get the user
        $user = Get-DummyUser -UserId $WebEvent.Parameters['userId']

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/users/12345' -Method Get
```

## Script from File

You normally define a route's script using the `-ScriptBlock` parameter however, you can also reference a file with the required scriptblock using `-FilePath`. Using the `-FilePath` parameter will dot-source a scriptblock from the file, and set it as the route's script.

For example, to create a route from a file that will write a simple JSON response on a route:

* File.ps1
```powershell
{
    Write-PodeJsonResponse -Value @{ 'value' = 'pong'; }
}
```

* Route
```powershell
Add-PodeRoute -Method Get -Path '/ping' -FilePath './Routes/File.ps1'
```

## Getting Routes

There are two helper function that allow you get retrieve a list of routes, and filter routes as well: [`Get-PodeRoute`](../../../Functions/Routes/Get-PodeRoute) and [`Get-PodeStaticRoute`](../../../Functions/Routes/Get-PodeStaticRoute).

You can use these functions to retrieve all routes, or routes for a specific HTTP method, path, endpoint, etc.

To retrieve all routes, you can call the functions with no parameters. To filter, here are some examples:

```powershell
# all routes for method
Get-PodeRoute -Method Get

# all routes for a Path
Get-PodeRoute -Path '/users'

# all routes for an Endpoint by name
Get-PodeRoute -EndpointName Admin
```

The [`Get-PodeStaticRoute`](../../../Functions/Routes/Get-PodeStaticRoute) function works in the same way as above - but with no `-Method` parameter.

## Route Object

!!! warning
    Be careful if you choose to edit these objects, as they will affect the server.

The following is the structure of the Route object internally, as well as the object that is returned from `Add-PodeRoute -PassThru` or [`Get-PodeRoute`](../../../Functions/Routes/Get-PodeRoute):

| Name | Type | Description |
| ---- | ---- | ----------- |
| Arguments | object[] | Array of arguments that are splatted onto the route's scriptblock (after the web event) |
| ContentType | string | The content type to use when parsing the payload in the request |
| Endpoint | hashtable | Contains the Address, Protocol, and Name of the Endpoint the route is bound to |
| ErrorType | string | Content type of the error page to use for the route |
| IsStatic | bool | Fixed to false for normal routes |
| Logic | scriptblock | The main scriptblock logic of the route |
| Method | string | HTTP method of the route |
| Metrics | hashtable | Metrics for the route, such as Request counts |
| Middleware | hashtable[] | Array of middleware that runs prior to the route's scriptblock |
| OpenApi | hashtable[] | The OpenAPI definition/settings for the route |
| Path | string | The path of the route - this path will have regex in place of route parameters |
| TransferEncoding | string | The transfer encoding to use when parsing the payload in the request |

Static routes have a slightly different format:

| Name | Type | Description |
| ---- | ---- | ----------- |
| ContentType | string | Content type to use when parsing the payload a request to the route |
| Defaults | string[] | Array of default file names to render if path in request is a folder |
| Download | bool | Specifies whether files are rendered in the response, or downloaded |
| Endpoint | hashtable | Contains the Address, Protocol, and Name of the Endpoint the route is bound to |
| ErrorType | string | Content type of the error page to use for the route |
| IsStatic | bool | Fixed to true for static routes |
| Method | string | HTTP method of the route |
| Metrics | hashtable | Metrics for the route, such as Request counts |
| Middleware | hashtable[] | Array of middleware that runs prior to the route's scriptblock |
| OpenApi | hashtable[] | The OpenAPI definition/settings for the route |
| Path | string | The path of the route - this path will have regex in place of dynamic file names |
| Source | string | The source path within the server that is used for the route |
| TransferEncoding | string | The transfer encoding to use when parsing the payload in the request |
