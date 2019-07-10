# Middleware Overview

When working with web servers in Pode - rest apis, routes, web-pages, etc. - they have support for using [`middleware`](../../../Functions/Core/Middleware). Middleware in Pode allows you to observe and edit the request/response objects for a current web event - you can alter the response, add custom objects to the web event for later use, or terminate the response without processing the `route` logic.

Middleware is supported as a general [`middleware`](../../../Functions/Core/Middleware) function, as well as on the [`route`](../../../Functions/Core/Route) function for custom middleware - like authentication.

Pode itself has some inbuilt middleware, which is overridable so you can use your own custom middleware. For example, Pode has inbuilt middleware for rate limiting, but you can override this with `middleware` and the name `@limit` (more on the [Access Rules](../AccessRules) and [Rate Limiting](../RateLimiting) page).

## Global Middleware

To setup and use middleware in Pode you use the [`middleware`](../../../Functions/Core/Middleware) function. This will setup global middleware that will run, in the order created, on every request prior to `route` logic being invoked.

The make-up of the `middleware` function is as follows:

```powershell
middleware [<route>] <scriptblock> [-name <string>]
```

The `middleware` function takes a scriptblock, of which itself accepts a single parameter for the current web event (similar to a `route`). The event object passed contains the current `Request` and `Response` objects - you can also add more custom objects to it, as the event is just a `hashtable`. The `-Name` parameter is defined later, but is solely used for allowing you to override the inbuilt middleware of Pode. The `route` value allows you to specify which routes to run the middleware against.

If you want to keep processing and proceed to the next middleware/route then `return $true` from the scriptblock, otherwise `return $false` and the response will be closed immediately.

The following example is middleware that observes the user agent of the request. If the request comes from a PowerShell session then stop processing and return forbidden, otherwise create a new `Agent` key on the session for later `middleware`/`route` logic:

```powershell
Start-PodeServer {
    middleware {
        # event which contains the Request/Response, and other keys
        param($event)

        # if the user agent is powershell, deny access
        if ($event.Request.UserAgent -ilike '*powershell*') {
            # forbidden
            Set-PodeResponseStatus -Code 403

            # stop processing
            return $false
        }

        # create a new key on the event for the next middleware/route
        $event.Agent = $event.Request.UserAgent

        # continue processing other middleware
        return $true
    }
}
```

Where as the following example is middleware that will only be run on requests against the `/api` route. Here, it will run Basic authentication on every API request:

```powershell
Start-PodeServer {
    middleware '/api' (auth check basic)
}
```

## Route Middleware

Custom middleware on a `route` is basically the same as above however, you don't use the `middleware` function and instead insert it straight on the `route`. Normally a route is defined as follows:

```powershell
route <method> <path> <logic>
```

but when you need to add custom middleware to a route, the make-up of the `route` looks like:

```powershell
route <method> <path> <middleware> <logic>
```

The middleware on a route can either be a single `scriptblock` or an an array of `scriptblocks`. Middleware defined on routes will be run before the route itself, but after any global middleware that may have been configured.

The following example defines a `scriptblock` to reject calls that come from a specific IP address on a specific `route`:

```powershell
Start-PodeServer {
    # custom middleware to reject access to a specific IP address
    $reject_ip = {
        # same event object as supplied to global middleware/routes
        param($event)

        # forbid access to the stated IP address
        if ($event.Request.RemoteEndPoint.Address.IPAddressToString -ieq '10.10.1.8') {
            Set-PodeResponseStatus -Code 403
            return $false
        }

        # allow the next custom middleware or the route itself to run
        return $true
    }

    # the middleware above is linked to this route, and checked before running the route logic
    route get '/users' $reject_ip {
        # route logic
    }

    # this route has no custom middleware, and just runs the route logic
    route get '/alive' {
        # route logic
    }
}
```

## Order of Running

Although you can define your own custom middleware, Pode does have some legacy middleware with a predefined run order. This order of running is as follows:

| Order | Middleware | Description |
| ----- | ---------- | ----------- |
| 1 | **Access Rules** | Allowing/Denying IP addresses (if [`access`](../../../Functions/Core/Access) logic is defined) |
| 2 | **Rate Limiting** | Limiting access to IP addresses (if [`limit`](../../../Functions/Core/Limit) logic is defined) |
| 3 | **Public Content** | Static Content such as images/css/js/html in the `/public` directory (or other defined static paths) |
| 4 | **Body Parsing** | Parsing request payload as JSON, XML, or other types |
| 5 | **Query String** | Getting any query string parameters currently on the request URL |
| 6 | **Cookie Parsing** | Parse the cookies from the request's header (this only applies to serverless) |
| 7 | **Custom Middleware** | Runs any defined `middleware` in the order it was created |
| 8 | **Route Middleware** | Runs any `route` middleware for the current route being processed |
| 9 | **Route** | Finally, the route itself is processed |

## Overriding Inbuilt

Pode has inbuilt middleware as defined in the order of running above. Sometimes you probably don't want to use the inbuilt rate limiting, and use a custom rate limiting library that utilises REDIS instead. Each of the inbuilt middlewares have a defined name, that you can pass to the `middleware` function via the `-Name` parameter:

* Access Control    - `@access`
* Rate Limiting     - `@limit`
* Public Content    - `@public`
* Body Parsing      - `@body`
* Query String      - `@query`
* Cookie Parsing    - `@cookie`

The following example uses rate limiting, and defines `middleware` that will override the inbuilt rate limiting logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    # assign rate limiting to localhost, and allow 8 request per 5 seconds
    limit ip @('127.0.0.1', '[::1]') 8 5

    # create middleware to override the inbuilt rate limiting (to stop the limiting)
    middleware -name '@limit' {
        return $true
    }

    # basic route
    route get '/' {
        # logic
    }
}
```