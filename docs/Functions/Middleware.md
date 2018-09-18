# Middleware

## Description

The `middleware` function allows you to add Middleware scripts, that run prior to `route` logic. They allow you to do things like rate-limiting, access restriction, sessions, etc.

Middleware in Pode allows you to observe and edit the request/response objects for a current web request - you can alter the response, add custom objects to the request for later use, or terminate the response without processing the `route` logic.

## Examples

### Example 1

The following example is `middleware` that observes the user agent of the request. If the request comes from a PowerShell session then stop processing and return forbidden, otherwise create a new Agent key on the session for later `middleware`/`route`:

```powershell
Server {
    middleware {
        param($session)

        if ($session.Request.UserAgent -ilike '*powershell*') {
            status 403
            return $false
        }

        $session.Agent = $session.Request.UserAgent
        return $true
    }
}
```

### Example 2

The following example uses rate limiting, and defines `middleware` that will override the inbuilt rate limiting middleware logic so that it never limits requests:

```powershell
Server {
    listen *:8080 http

    limit ip @('127.0.0.1', '[::1]') 8 5

    middleware -Name '@limit' {
        return $true
    }

    route get '/' {
        # logic
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| ScriptBlock | scriptblock | true | The main logic for the middleware; this scriptblock will be supplied a single parameter which contains the `Request` and `Response` objects | null |
| Name | string | false | Only use this parameter if you plan to override any of the inbuilt middleware. Names for the inbuilt middleware can be found below | empty |

## Notes

Middleware in Pode is executed in a specific order due to having inbuilt middleware, this order of running is as follows:

* Access control - allowing/denying IP addresses (if `access` logic is defined)
* Rate limiting - limiting access to IP addresses (if `limit` logic is defined)
* Public content - content such as images/css/js in the public directory
* Body parsing - parsing request payload a JSON or XML
* Querystring - getting any query string parameters currently on the request URL
* Custom middleware - runs any defined middleware in the order it was created
* Route middleware - runs any `route` middleware for the current route being processed
* Route - finally, the route itself is processed

Pode has some inbuilt middleware, as defined in the order of running above. Sometimes you probably don't want to use the inbuilt rate limiting, and use a custom rate limiting library that utilises REDIS instead. Each of the inbuilt middlewares have a defined name, that you can pass to the `middleware` function via `-Name`:

* Access control - `@access`
* Rate limiting - `@limit`
* Public content - `@public`
* Body parsing - `@body`
* Querystring - `@query`

> An example of overriding the inbuilt middleware can be found in the examples above