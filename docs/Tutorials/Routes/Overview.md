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


## Body Payloads

The following is an example of using data from a request's payload—i.e., the data in the body of a POST request. To retrieve values from the payload, you can use the `.Data` property on the `$WebEvent` variable in a route's logic.

Alternatively, you can use the `Get-PodeBodyData` function to retrieve the body data, with additional support for deserialization.

Depending on the Content-Type supplied, Pode has built-in body-parsing logic for JSON, XML, CSV, and Form data.

This example will get the `userId` and "find" the user, returning the user's data:

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
    The `ContentType` is required as it informs Pode on how to parse the request's payload. For example, if the content type is `application/json`, Pode will attempt to parse the body of the request as JSON—converting it to a hashtable.

!!! important
    On PowerShell 5, referencing JSON data on `$WebEvent.Data` must be done as `$WebEvent.Data.userId`. This also works in PowerShell 6+, but you can also use `$WebEvent.Data['userId']` on PowerShell 6+.

### Using Get-PodeBodyData

Alternatively, you can use the `Get-PodeBodyData` function to retrieve the body data. This function works similarly to the `.Data` property on `$WebEvent` and supports the same content types.

Here is the same example using `Get-PodeBodyData`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Post -Path '/users' -ScriptBlock {
        # get the body data
        $body = Get-PodeBodyData

        # get the user
        $user = Get-DummyUser -UserId $body.userId

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

### Deserialization with Get-PodeBodyData

The `Get-PodeBodyData` function can also deserialize body data from requests, allowing for more complex data handling scenarios. This feature is especially useful when dealing with serialized data structures that require specific interpretation styles.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-NoExplode`**: Prevents deserialization from exploding arrays in the body data. This is useful when dealing with comma-separated values where array expansion is not desired.
- **`-Style`**: Defines the deserialization style (`'Simple'`, `'Label'`, `'Matrix'`, `'Form'`, `'SpaceDelimited'`, `'PipeDelimited'`, `'DeepObject'`) to interpret the body data correctly. The default style is `'Form'`.
- **`-KeyName`**: Specifies the key name to use when deserializing, allowing accurate mapping of the body data. The default value for `KeyName` is `'id'`.

### Example with Deserialization

This example demonstrates deserialization of body data using specific styles and options:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Post -Path '/items' -ScriptBlock {
        # retrieve and deserialize the body data
        $body = Get-PodeBodyData -Deserialize -Style 'Matrix' -NoExplode

        # get the item based on the deserialized data
        $item = Get-DummyItem -ItemId $body.id

        # return the item details
        Write-PodeJsonResponse -Value @{
            Name = $item.name
            Quantity = $item.quantity
        }
    }
}
```

In this example, `Get-PodeBodyData` is used to deserialize the body data with the `'Matrix'` style and prevent array explosion (`-NoExplode`). This approach provides flexible and precise handling of incoming body data, enhancing the capability of your Pode routes to manage complex payloads.

## Query Parameters

The following is an example of using data from a request's query string. To retrieve values from the query parameters, you can use the `Query` property on the `$WebEvent` variable in a route's logic.

Alternatively, you can use the `Get-PodeQueryParameter` function to retrieve the query parameter data, with additional support for deserialization.

This example will return a user based on the `userId` supplied:

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

### Using Get-PodeQueryParameter

Alternatively, you can use the `Get-PodeQueryParameter` function to retrieve the query data. This function works similarly to the `Query` property on `$WebEvent` but provides additional options for deserialization when needed.

Here is the same example using `Get-PodeQueryParameter`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users' -ScriptBlock {
        # get the query data
        $userId = Get-PodeQueryParameter -Name 'userId'

        # get the user
        $user = Get-DummyUser -UserId $userId

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

#### Deserialization with Get-PodeQueryParameter

The `Get-PodeQueryParameter` function can also deserialize query parameters passed in the URL, using specific styles to interpret the data correctly. This feature is particularly useful when handling complex data structures or encoded parameter values.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-NoExplode`**: Prevents deserialization from exploding arrays when handling comma-separated values. This is useful when array expansion is not desired.
- **`-Style`**: Defines the deserialization style (`'Simple'`, `'Label'`, `'Matrix'`, `'Form'`, `'SpaceDelimited'`, `'PipeDelimited'`, `'DeepObject'`) to interpret the query parameter value correctly. The default style is `'Form'`.
- **`-KeyName`**: Specifies the key name to use when deserializing, allowing you to map the query parameter data accurately. The default value for `KeyName` is `'id'`.

#### Example with Deserialization

This example demonstrates deserialization of a query parameter with specific styles and options:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/items' -ScriptBlock {
        # retrieve and deserialize the 'filter' query parameter
        $filter = Get-PodeQueryParameter -Name 'filter' -Deserialize -Style 'SpaceDelimited' -NoExplode

        # get items based on the deserialized filter data
        $items = Get-DummyItems -Filter $filter

        # return the item details
        Write-PodeJsonResponse -Value $items
    }
}
```

In this example, the `Get-PodeQueryParameter` function is used to deserialize the `filter` query parameter, interpreting it according to the specified style (`SpaceDelimited`) and preventing array explosion (`-NoExplode`). This approach allows for dynamic and precise handling of complex query data, enhancing the flexibility of your Pode routes.


## Path Parameters

The following is an example of using values supplied on a request's URL using parameters. To retrieve values that match a request's URL parameters, you can use the `Parameters` property from the `$WebEvent` variable.

Alternatively, you can use the `Get-PodePathParameter` function to retrieve the parameter data.

This example will get the `:userId` and "find" user, returning the user's data:

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

### Using Get-PodePathParameter

Alternatively, you can use the `Get-PodePathParameter` function to retrieve the parameter data. This function works similarly to the `Parameters` property on `$WebEvent` but provides additional options for deserialization when needed.

Here is the same example using `Get-PodePathParameter`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/users/:userId' -ScriptBlock {
        # get the parameter data
        $userId = Get-PodePathParameter -Name 'userId'

        # get the user
        $user = Get-DummyUser -UserId $userId

        # return the user
        Write-PodeJsonResponse -Value @{
            Username = $user.username
            Age = $user.age
        }
    }
}
```

#### Deserialization with Get-PodePathParameter

The `Get-PodePathParameter` function can handle deserialization of parameters passed in the URL path, query string, or body, using specific styles to interpret the data correctly. This is useful when dealing with more complex data structures or encoded parameter values.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-Explode`**: Specifies whether to explode arrays when deserializing, useful when parameters contain comma-separated values.
- **`-Style`**: Defines the deserialization style (`'Simple'`, `'Label'`, or `'Matrix'`) to interpret the parameter value correctly. The default style is `'Simple'`.
- **`-KeyName`**: Specifies the key name to use when deserializing, allowing you to map the parameter data accurately. The default value for `KeyName` is `'id'`.

#### Example with Deserialization

This example demonstrates deserialization of a parameter that is styled and exploded as part of the request:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/items/:itemId' -ScriptBlock {
        # retrieve and deserialize the 'itemId' parameter
        $itemId = Get-PodePathParameter -Name 'itemId' -Deserialize -Style 'Label' -Explode

        # get the item based on the deserialized data
        $item = Get-DummyItem -ItemId $itemId

        # return the item details
        Write-PodeJsonResponse -Value @{
            Name = $item.name
            Quantity = $item.quantity
        }
    }
}
```

In this example, the `Get-PodePathParameter` function is used to deserialize the `itemId` parameter, interpreting it according to the specified style (`Label`) and handling arrays if present (`-Explode`). The default `KeyName` is `'id'`, but it can be customized as needed. This approach allows for dynamic and precise handling of incoming request data, making your Pode routes more versatile and resilient.

## Headers

The following is an example of using values supplied in a request's headers. To retrieve values from the headers, you can use the `Headers` property from the `$WebEvent.Request` variable. Alternatively, you can use the `Get-PodeHeader` function to retrieve the header data.

This example will get the Authorization header and validate the token, returning a success message:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/validate' -ScriptBlock {
        # get the token
        $token = $WebEvent.Request.Headers['Authorization']

        # validate the token
        $isValid = Test-PodeJwt -payload $token

        # return the result
        Write-PodeJsonResponse -Value @{
            Success = $isValid
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/validate' -Method Get -Headers @{ Authorization = 'Bearer some_token' }
```

Alternatively, you can use the `Get-PodeHeader` function to retrieve the header data. This function works similarly to the `Headers` property on `$WebEvent.Request`.

Here is the same example using `Get-PodeHeader`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/validate' -ScriptBlock {
        # get the token
        $token = Get-PodeHeader -Name 'Authorization'

        # validate the token
        $isValid = Test-PodeJwt -payload $token

        # return the result
        Write-PodeJsonResponse -Value @{
            Success = $isValid
        }
    }
}
```

### Deserialization with Get-PodeHeader

The `Get-PodeHeader` function can also deserialize header values, enabling more advanced handling of serialized data sent in headers. This feature is useful when dealing with complex data structures or when headers contain encoded or serialized content.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-Explode`**: Specifies whether the deserialization process should explode arrays in the header value. This is useful when handling comma-separated values within the header.
- **`-Deserialize`**: Indicates that the retrieved header value should be deserialized, interpreting the content based on the deserialization style and options.

### Example with Deserialization

This example demonstrates deserialization of a header value:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/deserialize' -ScriptBlock {
        # retrieve and deserialize the 'X-SerializedHeader' header
        $headerData = Get-PodeHeader -Name 'X-SerializedHeader' -Deserialize -Explode

        # process the deserialized header data
        # (example processing logic here)

        # return the processed header data
        Write-PodeJsonResponse -Value @{
            HeaderData = $headerData
        }
    }
}
```

In this example, `Get-PodeHeader` is used to deserialize the `X-SerializedHeader` header, interpreting it according to the provided deserialization options. The `-Explode` switch ensures that any arrays within the header value are properly expanded during deserialization.

For further information on general usage and retrieving headers, please refer to the [Headers Documentation](Headers.md).


## Cookies

The following is an example of using values supplied in a request's cookies. To retrieve values from the cookies, you can use the `Cookies` property from the `$WebEvent` variable.

Alternatively, you can use the `Get-PodeCookie` function to retrieve the cookie data, with additional support for deserialization and secure handling.

This example will get the `SessionId` cookie and use it to authenticate the user, returning a success message:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/authenticate' -ScriptBlock {
        # get the session ID from the cookie
        $sessionId = $WebEvent.Cookies['SessionId']

        # authenticate the session
        $isAuthenticated = Authenticate-Session -SessionId $sessionId

        # return the result
        Write-PodeJsonResponse -Value @{
            Authenticated = $isAuthenticated
        }
    }
}
```

The following request will invoke the above route:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/authenticate' -Method Get -Headers @{ Cookie = 'SessionId=abc123' }
```

### Using Get-PodeCookie

Alternatively, you can use the `Get-PodeCookie` function to retrieve the cookie data. This function works similarly to the `Cookies` property on `$WebEvent`, but it provides additional options for deserialization and secure cookie handling.

Here is the same example using `Get-PodeCookie`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/authenticate' -ScriptBlock {
        # get the session ID from the cookie
        $sessionId = Get-PodeCookie -Name 'SessionId'

        # authenticate the session
        $isAuthenticated = Authenticate-Session -SessionId $sessionId

        # return the result
        Write-PodeJsonResponse -Value @{
            Authenticated = $isAuthenticated
        }
    }
}
```

### Deserialization with Get-PodeCookie

The `Get-PodeCookie` function can also deserialize cookie values, allowing for more complex handling of serialized data sent in cookies. This feature is particularly useful when cookies contain encoded or structured content that needs specific parsing.

To enable deserialization, use the `-Deserialize` switch along with the following options:

- **`-NoExplode`**: Prevents deserialization from exploding arrays in the cookie value. This is useful when handling comma-separated values where array expansion is not desired.
- **`-Deserialize`**: Indicates that the retrieved cookie value should be deserialized, interpreting the content based on the provided deserialization style and options.

### Example with Deserialization

This example demonstrates deserialization of a cookie value:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/deserialize-cookie' -ScriptBlock {
        # retrieve and deserialize the 'Session' cookie
        $sessionData = Get-PodeCookie -Name 'Session' -Deserialize -NoExplode

        # process the deserialized cookie data
        # (example processing logic here)

        # return the processed cookie data
        Write-PodeJsonResponse -Value @{
            SessionData = $sessionData
        }
    }
}
```

In this example, `Get-PodeCookie` is used to deserialize the `Session` cookie, interpreting it according to the provided deserialization options. The `-NoExplode` switch ensures that any arrays within the cookie value are not expanded during deserialization.

For further information on general usage and retrieving cookies, please refer to the [Headers Documentation](Cookies.md).

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