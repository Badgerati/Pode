# Route

## Description

The `route` function allows you to bind logic to be invoked against a URL path and HTTP method. The function also accepts custom middleware to be invoked, before running the main route logic - such as authentication.

You can also use the `route` function to specify routes to static content paths. Normally if you request a static file Pode will check the `/public` directory, but you can specify other paths using `route static` (example below).

!!! info
    The scriptblock supplied for the main route logic is invoked with a single parameter. This parameter will contain the `Request` and `Response` objects; `Data` (from POST requests), and the `Query` (from the query string of the URL), as well as any `Parameters` from the route itself (eg: `/:accountId`).

## Examples

### Example 1

The following example sets up a `GET /ping` route, that returns `value: pong`:

```powershell
Server {
    listen *:8080 http

    route get '/ping' {
        json @{ 'value' = 'ping' }
    }
}
```

### Example 2

The following example sets up a `POST /users` route, that creates a new user using post data:

```powershell
Server {
    listen *:8080 http

    route post '/users' {
        param($session)

        # create the user using POST data
        $userId = New-DummyUser $session.Data.Email $session.Data.Name $session.Data.Password

        # return with userId
        json @{ 'userId' = $userId; }
    }
}
```

### Example 3

The following example sets up a static route of `/assets` using the directory `./content/assets`. In the `home.html` view if you reference the image `<img src="/assets/images/icon.png" />`, then Pode will get the image from `./content/assets/images/icon.png`.

```powershell
Server {
    listen *:8080 http

    route static '/assets' './content/assets'

    route get '/' {
        view 'home'
    }
}
```

!!! tip
    Furthermore, if you attempt to navigate to `http://localhost:8080/assets`, then Pode will attempt to display a default page such as `index.html`.

### Example 4

The following example sets up a `GET /users/:userId` route, that returns a user based on the route parameter `userId`:

```powershell
Server {
    listen *:8080 http

    route get '/users/:userId'{
        param($session)

        # get the user, using the parameter userId
        $user = Get-DummyUser -UserId $session.Parameters['userId']

        # if no user, return 404
        if ($user -eq $null) {
            status 404
        }

        # return the user object
        json @{ 'user' = $user; }
    }
}
```

### Example 5

The following example sets up a `GET /` route, that has custom middleware to check the user agent first. If the user agent is from PowerShell deny the call, and don't invoke the route's logic:

```powershell
Server {
    listen *:8080 http

    $agent_mid = {
        param($session)

        if ($session.Request.UserAgent -ilike '*powershell*') {
            status 403

            # stop running
            return $false
        }

        $session.Agent = $session.Request.UserAgent

        # run the route logic
        return $true
    }

    route get '/' $agent_mid {
        view 'index'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| HttpMethod | string | true | The HTTP method to bind the route onto (Values: DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, TRACE, STATIC) | null |
| Route | string | true | The route path to listen on, the root path is `/`. The path can also contain parameters such as `/:userId` | empty |
| Middleware | object[] | false | Custom middleware for the `route` that will be invoked before the main logic is invoked - such as authentication. For non-static routes this is an array of `scriptblocks`, but for a static route this is the path to the static content directory | null |
| ScriptBlock | scriptblock | true | The main route logic that will be invoked when the route endpoint is hit | null |
| Defaults | string[] | false | For static routes only, this is an array of default pages that could be displayed when the static directory is called | ['index.html', 'index.htm', 'default.html', 'default.htm'] |

!!! tip
    There is a special `*` method you can use, which means a route that applies to every HTTP method