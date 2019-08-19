# Overview

Middleware in Pode allows you to observe and edit the request/response objects for a current web event - you can alter the response, add custom objects to the web event for later use, or terminate the response without processing the main Route logic.

Middleware is supported in both a global scope, using  [`Add-PodeMiddleware`](../../../Functions/Core/Add-PodeMiddleware), as well as at the Route level using the `-Middleware` parameter on  [`Add-PodeMiddleware`](../../../Functions/Core/Add-PodeMiddleware),

Pode itself has some inbuilt Middleware, which is overridable, so you can use your own custom middleware. For example, Pode has inbuilt Middleware for rate limiting, but you can override this with  [`Add-PodeMiddleware`](../../../Functions/Core/Add-PodeMiddleware) and the Name `__pode_mw_rate_limit__` (more on the [Access Rules](../Types/AccessRules) and [Rate Limiting](../Types/RateLimiting) page).

## Global Middleware

To setup and use middleware in Pode you use the Middleware function:  [`Add-PodeMiddleware`](../../../Functions/Core/Add-PodeMiddleware). This will setup global middleware that will run, in the order created, on every request prior to any Route logic being invoked.

The function takes a ScriptBlock, which itself accepts a single parameter for the current web event (similar to Routes). The event object passed contains the current `Request` and `Response` objects - you can also add more custom objects to it, as the event is just a `hashtable`.

If you want to keep processing and proceed to the next Middleware/Route then `return $true` from the ScriptBlock, otherwise `return $false` and the response will be closed immediately.

The following example is middleware that observes the user agent of the request. If the request comes from a PowerShell session then stop processing and return forbidden, otherwise create a new `Agent` key on the session for later Middleware/Route logic:

```powershell
Start-PodeServer {
    Add-PodeMiddleware -Name 'BlockPowershell' -ScriptBlock {
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

Where as the following example is Middleware that will only be run on requests against the `/api` route. Here, it will run Basic Authentication on every API request. You'll notice that this time we're piping  [`Get-PodeAuthMiddleware`](../../../Functions/Authentication/Get-PodeAuthMiddleware), this is because it returns valid Middleware.

```powershell
Start-PodeServer {
    Get-PodeAuthMiddleware -Name 'Main' | Add-PodeMiddleware -Name 'GlobalApiAuthCheck' -Route '/api'
}
```

## Route Middleware

Custom middleware on a Route is basically the same as above however, you don't use the main Middleware functions and instead insert it straight on the Route. To do this, you can use the `-Middleware` parameter on the  [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute) function.

The middleware on a route can either be a single `scriptblock` or an an array of `scriptblocks`. Middleware defined on routes will be run before the route itself, but after any global middleware that may have been configured.

The following example defines a `scriptblock` to reject calls that come from a specific IP address on a specific Route:

```powershell
Start-PodeServer {
    # custom middleware to reject access to a specific IP address
    $reject_ip = {
        # same event object as supplied to global middleware/routes
        param($event)

        # forbid access to the stated IP address
        if ($event.RemoteIpAddress.IPAddressToString -ieq '10.10.1.8') {
            Set-PodeResponseStatus -Code 403
            return $false
        }

        # allow the next custom middleware or the route itself to run
        return $true
    }

    # the middleware above is linked to this route, and checked before running the route logic
    Add-PodeRoute -Method Get -Path '/users' -Middleware $reject_ip -ScriptBlock {
        # route logic
    }

    # this route has no custom middleware, and just runs the route logic
    Add-PodeRoute -Method Get -Path '/alive' -ScriptBlock {
        # route logic
    }
}
```

## Order of Running

Although you can define your own custom middleware, Pode does have some inbuilt middleware with a predefined run order. This order of running is as follows:

| Order | Middleware | Description |
| ----- | ---------- | ----------- |
| 1 | **Access Rules** | Allowing/Denying IP addresses (if access rules have been defined) |
| 2 | **Rate Limiting** | Limiting access to IP addresses (if rate limiting rules have been defined) |
| 3 | **Static Content** | Static Content such as images/css/js/html in the `/public` directory (or other defined static routes) |
| 4 | **Body Parsing** | Parsing request payload as JSON, XML, or other types |
| 5 | **Query String** | Getting any query string parameters currently on the request URL |
| 6 | **Cookie Parsing** | Parse the cookies from the request's header (this only applies to serverless) |
| 7 | **Custom Middleware** | Runs any defined user defined global Middleware in the order it was created |
| 8 | **Route Middleware** | Runs any Route level Middleware for the current Route being processed |
| 9 | **Route** | Finally, the route itself is processed |

## Overriding Inbuilt

Pode has inbuilt Middleware as defined in the order of running above. Sometimes you probably don't want to use the inbuilt rate limiting, and use a custom rate limiting library that utilises REDIS instead. Each of the inbuilt Middleware have a defined name, that you can pass to the  [`Add-PodeMiddleware`](../../../Functions/Core/Add-PodeMiddleware) function via the `-Name` parameter:

* Access Control    - `__pode_mw_access__`
* Rate Limiting     - `__pode_mw_rate_limit__`
* Public Content    - `__pode_mw_static_content__`
* Body Parsing      - `__pode_mw_body_parsing__`
* Query String      - `__pode_mw_query_parsing__`
* Cookie Parsing    - `__pode_mw_cookie_parsing__`

The following example uses rate limiting, and defines Middleware that will override the inbuilt rate limiting logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # assign rate limiting to localhost, and allow 8 request per 5 seconds
    Add-PodeLimitRule -Type IP -Values @('127.0.0.1', '[::1]') -Limit 8 -Seconds 5

    # create middleware to override the inbuilt rate limiting (to stop the limiting)
    Add-PodeMiddleware -Name '__pode_mw_rate_limit__' -ScriptBlock {
        return $true
    }

    # basic route
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # logic
    }
}
```
