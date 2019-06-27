# Route

## Description

The `route` function allows you to bind logic to be invoked against a URL path and HTTP method. The function also accepts custom middleware to be invoked, before running the main route logic - such as authentication.

You can also use the `route` function to specify routes to static content paths. Normally if you request a static file Pode will check the `/public` directory, but you can specify other paths using `route static` (example below). If you call a directory path with the directory structure, then a default file (such as `index.html`) will be searched for and returned.

Routes can also be bound against a specific protocol or endpoint. This allows you to bind multiple routes against different endpoints - if you're listening to multiple endpoints.

!!! info
    The scriptblock supplied for the main route logic is invoked with a single parameter for the current web event. This parameter will contain the `Request` and `Response` objects; `Data` (from POST requests), and the `Query` (from the query string of the URL), as well as any `Parameters` from the route itself (eg: `/:accountId`).

!!! tip
    You can force a content type for a route's payload by using the `-ContentType` parameter. By setting it, Pode will attempt to parse any request payload as that content type - regardless of what might be set on the request.

## Examples

### Example 1

The following example sets up a `GET /ping` route, that returns `{ "value": "pong" }`:

```powershell
server {
    listen *:8080 http

    route get '/ping' {
        json @{ 'value' = 'ping' }
    }
}
```

### Example 2

The following example sets up a `GET /ping` route, and the scriptblock to use is sourced from an external script:

*server.ps1*
```powershell
server {
    listen *:8080 http

    route get '/ping' -fp './routes/ping.ps1'
}
```

*./routes/ping.ps1*
```powershell
return {
    json @{ 'value' = 'ping' }
}
```

### Example 3

The following example sets up a `GET /ping` route, and then removes it:

```powershell
server {
    listen *:8080 http

    route get '/ping' {
        json @{ 'value' = 'ping' }
    }

    route -remove get '/ping'
}
```

### Example 4

The following example sets up a `POST /users` route, that creates a new user using post data:

```powershell
server {
    listen *:8080 http

    route post '/users' {
        param($event)

        # create the user using POST data
        $userId = New-DummyUser $event.Data.Email $event.Data.Name $event.Data.Password

        # return with userId
        json @{ 'userId' = $userId; }
    }
}
```

!!! important
    On PowerShell 4 and 5, referencing JSON data on `$event.Data` must be done as `$event.Data.Key`. This also works in PowerShell 6+, but you can also use `$event.Data['Key']` on PowerShell 6+.

### Example 5

The following example sets up a static route of `/assets` using the directory `./content/assets`. In the `home.html` view if you reference the image `<img src="/assets/images/icon.png" />`, then Pode will get the image from `./content/assets/images/icon.png`.

```powershell
server {
    listen *:8080 http

    route static '/assets' './content/assets'

    route get '/' {
        view 'home'
    }
}
```

!!! tip
    Furthermore, if you attempt to navigate to `http://localhost:8080/assets`, then Pode will attempt to display a default page such as `index.html` - [see here](../../../Tutorials/Routes/Overview#default-pages).

### Example 6

The following example sets up a `GET /users/:userId` route, that returns a user based on the route parameter `userId`:

```powershell
server {
    listen *:8080 http

    route get '/users/:userId'{
        param($event)

        # get the user, using the parameter userId
        $user = Get-DummyUser -UserId $event.Parameters['userId']

        # if no user, return 404
        if ($user -eq $null) {
            status 404
        }

        # return the user object
        json @{ 'user' = $user; }
    }
}
```

### Example 7

The following example sets up a `GET /` route, that has custom middleware to check the user agent first. If the user agent is from PowerShell deny the call, and don't invoke the route's logic:

```powershell
server {
    listen *:8080 http

    $agent_mid = {
        param($event)

        if ($event.Request.UserAgent -ilike '*powershell*') {
            status 403

            # stop running
            return $false
        }

        $event.Agent = $event.Request.UserAgent

        # run the route logic
        return $true
    }

    route get '/' $agent_mid {
        view 'index'
    }
}
```

### Example 8

The following example sets up two `GET /ping` routes: one that applies to only http requests, and another for everything else:

```powershell
server {
    listen *:8080 http

    route get '/ping' {
        json @{ 'value' = 'ping' }
    }

    route get '/ping' -protocol http {
        json @{ 'value' = 'pong' }
    }
}
```

### Example 9

The following example sets up two `GET /ping` routes: one that applies to one endpoint, and the other to the other endpoint:

```powershell
server {
    listen pode.foo.com:8080 http
    listen pode.bar.com:8080 http

    route get '/ping' -endpoint pode.foo.com {
        json @{ 'value' = 'ping' }
    }

    route get '/ping' -endpoint pode.bar.com {
        json @{ 'value' = 'pong' }
    }
}
```

### Example 10

The following example sets up two `GET /ping` routes: one that applies to one endpoint, and the other to the other endpoint; this is done using the name supplied to the `listen` function:

```powershell
server {
    listen pode.foo.com:8080 http -name 'pode1'
    listen pode.bar.com:8080 http -name 'pode2'

    route get '/ping' -listenName 'pode1' {
        json @{ 'value' = 'ping' }
    }

    route get '/ping' -listenName 'pode2' {
        json @{ 'value' = 'pong' }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| HttpMethod | string | true | The HTTP method to bind the route onto (Values: DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, TRACE, STATIC, *) | null |
| Route | string | true | The route path to listen on, the root path is `/`. The path can also contain parameters such as `/:userId` | empty |
| Middleware | object[] | false | Custom middleware for the `route` that will be invoked before the main logic is invoked - such as authentication. For non-static routes this is an array of `scriptblocks`, but for a static route this is the path to the static content directory | null |
| ScriptBlock | scriptblock | true | The main route logic that will be invoked when the route endpoint is hit | null |
| FilePath | string | false | A file path to a script that will return a scriptblock for the main route logic | null |
| Defaults | string[] | false | For static routes only. This is an array of default pages that could be displayed when the static directory is called | ['index.html', 'index.htm', 'default.html', 'default.htm'] |
| Protocol | string | false | The protocol to bind the route against (Values: Empty, HTTP, HTTPS) | empty |
| Endpoint | string | false | The endpoint to bind the route against - this will typically be the endpoint used in your `listen` function | empty |
| ListenName | string | false | The name of a [`listen`](../Listen) endpoint to bind the route against. This can be use instead of `-Protocol` and `-Endpoint`, but if used with them, will override their values | empty |
| ContentType | string | false | If supplied, Pode will attempt to parse any request payload as the supplied content type - regardless of what might be set on the request. (eg: `application/json`) | empty |
| ErrorType | string | false | If supplied, When an error occurs in the route, Pode will attempt to render an error page using the supplied content type. (eg: `application/json`) | empty |
| Remove | switch | false | When passed, will remove a defined route | false |
| DownloadOnly | switch | false | For static routes only. If passed, will cause all files in the static directory to be attached for downloading rather than rendered | false |

!!! tip
    The special `*` method allows you to bind a route against every HTTP method. This method takes priority over the other methods; if you have a route for `/` against `GET` and `*`, then the `*` method will be used.