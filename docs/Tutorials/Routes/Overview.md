# Overview

Routes in Pode allow you to bind logic that should be invoked when a users call certain paths on a URL, for a specific HTTP method, against your server. Routes allow you to host REST APIs and Web Pages, as well as using custom Middleware for logic such as authentication.

You can also create static routes, that redirect requests for static content to internal directories.

Routes can also be bound against a specific protocol or endpoint. This allows you to bind multiple root (`/`) routes against different endpoints - if you're listening to multiple endpoints.

!!! info
    The following HTTP methods are supported by routes in Pode:
    CONNECT, DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, and TRACE.

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

!!! tip
    You can supply more than 1 `-Method` if required, such as: `-Method Get, Post`

The scriptblock for the route will have access to the `$WebEvent` variable which contains information about the current [web event](../../WebEvent). This argument will contain the `Request` and `Response` objects, `Data` (from POST), and the `Query` (from the query string of the URL), as well as any `Parameters` from the route itself (eg: `/:accountId`).

You can add your routes straight into the [`Start-PodeServer`](../../../Functions/Core/Start-PodeServer) scriptblock, or separate them into different files. These files can then be dot-sourced, or you can use [`Use-PodeRoutes`](../../../Functions/Routes/Use-PodeRoutes) to automatically load all ps1 files within a `/routes` directory at the root of your server.

## Retrieving Client Parameters

When working with REST calls, data can be passed by the client using various methods, including Cookies, Headers, Paths, Queries, and Body. Each of these methods has specific ways to retrieve the data:

- **Cookies**: Cookies sent by the client can be accessed using the `$WebEvent.Cookies` property or the `Get-PodeCookie` function for more advanced handling. For more details, refer to the [Cookies Documentation](./Parameters/Cookies.md).

- **Headers**: Headers can be retrieved using the `$WebEvent.Request.Headers` property or the `Get-PodeHeader` function, which provides additional deserialization options. Learn more in the [Headers Documentation](./Parameters/Headers.md).

- **Paths**: Parameters passed through the URL path can be accessed using the `$WebEvent.Parameters` property or the `Get-PodePathParameter` function. Detailed information can be found in the [Path Parameters Documentation](./Parameters/Paths.md).

- **Queries**: Query parameters from the URL can be accessed via `$WebEvent.Query` or retrieved using the `Get-PodeQueryParameter` function for deserialization support. Check the [Query Parameters Documentation](./Parameters/Queries.md).

- **Body**: Data sent in the request body, such as in POST requests, can be retrieved using the `$WebEvent.Data` property or the `Get-PodeBodyData` function for enhanced deserialization capabilities. See the [Body Data Documentation](./Parameters/Body.md) for more information.

Each link provides detailed usage and examples to help you retrieve and manipulate the parameters passed by the client effectively.

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

## If Exists Preference

By default when you try and add a Route with the same Method and Path twice, Pode will throw an error when attempting to add the second Route.

You can alter this behaviour by using the `-IfExists` parameter on several of the Route functions:

* [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute)
* [`Add-PodeStaticRoute`](../../../Functions/Routes/Add-PodeStaticRoute)
* [`Add-PodeSignalRoute`](../../../Functions/Routes/Add-PodeSignalRoute)
* [`Add-PodeRouteGroup`](../../../Functions/Routes/Add-PodeRouteGroup)
* [`Add-PodeStaticRouteGroup`](../../../Functions/Routes/Add-PodeStaticRouteGroup)
* [`Add-PodeSignalRouteGroup`](../../../Functions/Routes/Add-PodeSignalRouteGroup)
* [`Use-PodeRoutes`](../../../Functions/Routes/Use-PodeRoutes)

Or you can alter the global default preference for all Routes using [`Set-PodeRouteIfExistsPreference`](../../../Functions/Routes/Set-PodeRouteIfExistsPreference).

This parameter accepts the following options:

| Option | Description |
| ------ | ----------- |
| Default | This will use the `-IfExists` value from higher up the hierarchy (as defined see below) - if none defined, Error is the final default |
| Error | Throw an error if the Route already exists |
| Overwrite | Delete the existing Route if one exists, and then recreate the Route with the new definition |
| Skip | Skip over adding the Route if it already exists |

and the following hierarchy is used when deciding which behaviour to use. At each step if the value defined is `Default` then check the next value in the hierarchy:

1. Use the value defined directly on the Route, such as [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute)
2. Use the value defined on a Route Group, such as [`Add-PodeRouteGroup`](../../../Functions/Routes/Add-PodeRouteGroup)
3. Use the value defined on [`Use-PodeRoutes`](../../../Functions/Routes/Use-PodeRoutes)
4. Use the value defined from [`Set-PodeRouteIfExistsPreference`](../../../Functions/Routes/Set-PodeRouteIfExistsPreference)
5. Throw an error if the Route already exists

For example, the following will now skip attempting to add the second Route because it already exists; meaning the value returned from `http://localhost:8080` is `1` not `2`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 1 }
    }

    Add-PodeRoute -Method Get -Path '/' -IfExists Skip -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 2 }
    }
}
```

Or, we could use Overwrite and the value returned will now be `2` not `1`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 1 }
    }

    Add-PodeRoute -Method Get -Path '/' -IfExists Overwrite -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 2 }
    }
}
```

## Grouping

If you have a number of Routes that all share the same base path, middleware, authentication, or other parameters, then you can add these Routes within a Route Group (via [`Add-PodeRouteGroup`](../../../Functions/Routes/Add-PodeRouteGroup)) to share the parameter values:

```powershell
Add-PodeRouteGroup -Path '/api' -Authentication Basic -Routes {
    Add-PodeRoute -Method Get -Path '/route1' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ ID = 1 }
    }

    Add-PodeRoute -Method Get -Path '/route2' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ ID = 2 }
    }

    Add-PodeRoute -Method Get -Path '/route3' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ ID = 3 }
    }
}
```

In the above example, this will create 3 Routes: `/api/route1`, `/api/route2`, and `/api/route3`. Each of the Routes will also all require some Basic authentication.

You can also do the same with Static and Signal Routes via [`Add-PodeStaticRouteGroup`](../../../Functions/Routes/Add-PodeStaticRouteGroup) and [`Add-PodeSignalRouteGroup`](../../../Functions/Routes/Add-PodeSignalRouteGroup).

More information on Route grouping can be [found here](../Utilities/RouteGrouping).

## Route Object

!!! warning
    Be careful if you choose to edit these objects, as they will affect the server.

The following is the structure of the Route object internally, as well as the object that is returned from `Add-PodeRoute -PassThru` or [`Get-PodeRoute`](../../../Functions/Routes/Get-PodeRoute):

| Name | Type | Description |
| ---- | ---- | ----------- |
| Arguments | object[] | Array of arguments that are splatted onto the route's scriptblock |
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