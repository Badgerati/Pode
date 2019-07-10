# Middleware

## Description

The `middleware` function allows you to add middleware scripts, that run prior to `route` logic. They allow you to do things like rate-limiting, access restriction, authentication, sessions, etc.

Middleware in Pode allows you to observe and edit the request/response objects for a current web event - you can alter the response, add custom objects to the request for later use, or terminate the response without processing the `route` logic.

## Examples

### Example 1

The following example is `middleware` that observes the user agent of the request. If the request comes from a PowerShell session then stop processing and return forbidden, otherwise create a new Agent key on the event for later `middleware`/`route`:

```powershell
Start-PodeServer {
    middleware {
        param($event)

        if ($event.Request.UserAgent -ilike '*powershell*') {
            status 403
            return $false
        }

        $event.Agent = $event.Request.UserAgent
        return $true
    }
}
```

### Example 2

The following example uses rate limiting, and defines `middleware` that will override the inbuilt rate limiting middleware logic so that it never limits requests:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    limit ip @('127.0.0.1', '[::1]') 8 5

    middleware -Name '@limit' {
        return $true
    }

    route get '/' {
        # logic
    }
}
```

### Example 3

The following example is `middleware` that only runs on `/api` routes. If the request comes from a PowerShell session then stop processing and return forbidden, otherwise create a new Agent key on the event for later `middleware`/`route`:

```powershell
Start-PodeServer {
    middleware '/api' {
        param($event)

        if ($event.Request.UserAgent -ilike '*powershell*') {
            status 403
            return $false
        }

        $event.Agent = $event.Request.UserAgent
        return $true
    }
}
```

### Example 4

The following example is `middleware` that will run Basic authenticaion validation on every `/api` request (assumes authentication has been set-up):

```powershell
Start-PodeServer {
    middleware '/api' (auth check basic)
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| ScriptBlock | scriptblock | true if no hashtable | Main logic for the middleware; the scriptblock will be supplied a single parameter which contains the `Request` and `Response` objects | null |
| HashTable | hashtable | true if no scriptblock | Main logic for the middleware; the hashtable requires a 'Logic' key with a scriptblock value (with the same rules as above) | null |
| Route | string | false | Specifies which routes the middleware should be invoked on | / |
| Name | string | false | Only use this parameter if you plan to override any of the inbuilt middleware. Names for the inbuilt middleware can be found below | empty |
| Return | switch | false | If supplied, the middleware won't be added but will instead be returned - for use on specific routes | false |

## Notes

Middleware in Pode is executed in a specific order due to having inbuilt middleware, this order of running is as follows:

* Access control - allowing/denying IP addresses (if `access` logic is defined)
* Rate limiting - limiting access to IP addresses (if `limit` logic is defined)
* Public content - static content such as images/css/js/html in the `/public` directory (or other defined static paths)
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