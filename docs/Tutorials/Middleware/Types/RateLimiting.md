# Rate Limiting

Rate limiting in Pode is inbuilt Middleware, that allows you to specify a maximum number of requests, per second, for an IP, Route, or Endpoint.

When rate limiting a subnet you can choose to either individually limit each IP address in a subnet, or you can group all IPs in a subnet together under a single limit.

## Usage

To setup rate limiting in Pode you use the [`Add-PodeLimitRule`](../../../../Functions/Middleware/Add-PodeLimitRule) function.

### IP Address

You can either rate limit a specific IP address, a subnet mask, or every address using `all`. You can also supply an array of addresses/subnets as well, rather than one at a time.

!!! info
    If an IP address or subnet hits the limit within a second, then a `429` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

The following example will limit requests from localhost to 5 requests per second:

```powershell
Add-PodeLimitRule -Type IP -Values 127.0.0.1 -Limit 5 -Seconds 1
```

Whereas the following example will rate limit requests from a subnet. By default each IP address within the subnet are limited to 5 requests per second:

```powershell
Add-PodeLimitRule -Type IP -Values 10.10.0.0/24 -Limit 5 -Seconds 1
```

To treat all IP addresses within by a subnet as one, using a shared limit, you can supply the `-Group` switch:

```powershell
Add-PodeLimitRule -Type IP -Values 10.10.0.0/24 -Limit 5 -Seconds 1 -Group
```

To rate limit requests from multiple addresses in one line, the following example will work:

```powershell
Add-PodeLimitRule -Type IP -Values @('192.168.1.1', '192.168.1.2') -Limit 5 -Seconds 1
```

Finally, to rate limit requests from every address you can use the `all` keyword:

```powershell
Add-PodeLimitRule -Type IP -Values all -Limit 5 -Seconds 1
```

### Routes

To assign rate limiting to a specific route, you can pass its path to [`Add-PodeLimitRule`](../../../../Functions/Middleware/Add-PodeLimitRule). The following with limit the `/downloads` route to 5 requests every second:

```powershell
Add-PodeLimitRule -Type Route -Values '/downloads' -Limit 5 -Seconds 1
```

### Endpoints

To assign rate limiting to a specific endpoint, you can pass an endpoint's name to [`Add-PodeLimitRule`](../../../../Functions/Middleware/Add-PodeLimitRule). The following with limit the `User` endpoint to 5 requests every second:

```powershell
Add-PodeEndpoint -Address 127.0.0.2 -Port 8090 -Protocol Http -Name 'Admin'
Add-PodeEndpoint -Address 127.0.0.3 -Port 8090 -Protocol Http -Name 'User'

Add-PodeLimitRule -Type Endpoint -Values 'User' -Limit 5 -Seconds 1
```

## Overriding

Since rate limiting is an inbuilt Middleware, then when you setup rules via the [`Add-PodeLimitRule`](../../../../Functions/Middleware/Add-PodeLimitRule) function the point at which the limit is checked on the request lifecycle is fixed (see [here](../../Overview/#order-of-running)).

This means you can override the inbuilt rate limiting logic, with your own custom logic, using the [`Add-PodeMiddleware`](../../../../Functions/Core/Add-PodeMiddleware) function. To override the rate limiting logic you can pass `__pode_mw_rate_limit__` to the `-Name` parameter of the [`Add-PodeMiddleware`](../../../../Functions/Core/Add-PodeMiddleware) function.

The following example uses rate limiting, and defines Middleware that will override the inbuilt limiting logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # assign limiting to localhost
    Add-PodeLimitRule -Type IP -Values @('127.0.0.1', '[::1]') -Limit 10 -Seconds 2

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
