# Rate Rules

Rate limiting in Pode is inbuilt Middleware, that allows you to specify a maximum number of requests within a defined duration, built using [Limit Components](../Components). For example, you could rate limit a specific IP to 10 requests per minute.

When rate limiting a subnet you can choose to either individually limit each IP address in a subnet, or you can group all IPs in a subnet together under a single limit.

## Usage

To create rate rules in Pode you use the [`Add-PodeLimitRateRule`](../../../../../Functions/Limit/Add-PodeLimitRateRule) function, together with a series of [Limit Components](../Components).

This page will give some quick examples of Rate Rules, for more information on the components themselves go to the components page. However, in general you can use the components to build rate rules to limit requests from IPs, subnets, to specific Routes/Endpoints, etc.

!!! info
    If request hits the limit within the defined duration, then a `429` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

The following example will limit requests from localhost to 5 requests per second:

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 5 -Duration 1000 -Component @(
    New-PodeLimitIPComponent -Value '127.0.0.1'
)
```

Whereas the following example will rate limit requests from a subnet. By default each IP address within the subnet are limited to 5 requests per second:

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 5 -Duration 1000 -Component @(
    New-PodeLimitIPComponent -Value '10.10.0.0/24'
)
```

To treat all IP addresses within by a subnet as one, using a shared limit, you can supply the `-Group` switch:

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 5 -Duration 1000 -Component @(
    New-PodeLimitIPComponent -Value '10.10.0.0/24' -Group
)
```

Conversely, you could even limit requests from a subnet to a specific group of Routes - say limiting requests to 10 per minute, to the Routes under `/api/*`:

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 10 -Duration 60000 -Component @(
    New-PodeLimitIPComponent -Value '10.10.0.0/24' -Group
    New-PodeLimitRouteComponent -Value '/api/*' -Group
)
```

You can also limit requests to just a specific Route:

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 1 -Duration 60000 -Component @(
    New-PodeLimitRouteComponent -Value '/download'
)
```

Or, limit requests by HTTP header. The following will limit each header value individually, or you can use `-Group` to treat the header as one value regardless of what is passed.

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 500 -Duration 60000 -Component @(
    New-PodeLimitHeaderComponent -Name 'X-API-KEY'
)
```

## Priority

By default, all rate rules are created with a minimum priority - meaning the rules will be executed in the order they are created.

If you want to have more control over this, you can customise the priority via the `-Priority` parameter. The higher the value, the higher the priority. If two or more rules have the same priority, then they are run in creation order.

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 500 -Duration 60000 -Priority 100 -Component @(
    New-PodeLimitHeaderComponent -Name 'X-API-KEY'
)
```

## Functions

Other helper functions for rate rules are:

* [`Update-PodeLimitRateRule`](../../../../../Functions/Limit/Update-PodeLimitRateRule)
* [`Remove-PodeLimitRateRule`](../../../../../Functions/Limit/Remove-PodeLimitRateRule)
* [`Test-PodeLimitRateRule`](../../../../../Functions/Limit/Test-PodeLimitRateRule)
* [`Get-PodeLimitRateRule`](../../../../../Functions/Limit/Get-PodeLimitRateRule)

## Overriding

Since rate limiting is an inbuilt Middleware, then when you setup rules the point at which the limit is checked on the request lifecycle is fixed (see [here](../../Overview/#order-of-running)).

This means you can override the inbuilt rate limiting logic, with your own custom logic, using the [`Add-PodeMiddleware`](../../../../../Functions/Middleware/Add-PodeMiddleware) function. To override the rate limiting logic you can pass `__pode_mw_rate_limit__` to the `-Name` parameter of the [`Add-PodeMiddleware`](../../../../../Functions/Middleware/Add-PodeMiddleware) function.

The following example uses rate limiting, and defines Middleware that will override the inbuilt limiting logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # assign limiting to localhost
    Add-PodeLimitRateRule -Name 'example' -Limit 10 -Duration 2000 -Component @(
        New-PodeLimitIPComponent -Value @('127.0.0.1', '[::1]')
    )

    # create middleware to override the inbuilt rate limiting logic.
    # this will ignore the limiting part, and just allow the request
    Add-PodeMiddleware -Name '__pode_mw_rate_limit__' -ScriptBlock {
        return $true
    }

    # basic route
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # logic
    }
}
```
