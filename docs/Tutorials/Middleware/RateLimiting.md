# Rate Limiting

Rate limiting in Pode is a legacy form of middleware, that allows you to specify a maximum number of requests for an IP address or subnet masks over a period of seconds. When rate limiting a subnet you can choose to either individually limit each IP address in a subnet, or you can group all IPs in a subnet together under a single limit.

## Usage

To setup rate limiting in Pode you use the [`limit`](../../../Functions/Middleware/Limit) function, along with a maximum number of requests (the limit) and a defined period of seconds to limit.

The make-up of the `limit` function is as follows:

```powershell
limit ip <address|subnet> -limit <int> -seconds <int> [-group]

# or with aliases
limit ip <address|subnet> -l <int> -s <int> [-g]
```

You can either rate limit a specific IP address, a subnet mask, or for every address (using `all`). You can also supply an array of addresses/subnets as well, rather than one at a time.

!!! info
    If an IP address or subnet hits the limit within the given period of seconds, then a `429` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

The following example will limit requests from localhost to 5 requests per second:

```powershell
Start-PodeServer {
    limit ip '127.0.0.1' -l 5 -s 1
}
```

Whereas the following example will rate limit requests from a subnet. By default this will give each IP address governed by a subnet their own limit:

```powershell
Start-PodeServer {
    limit ip '10.10.0.0/24' -l 5 -s 1
}
```

To treat all IP addresses governed by a subnet using the same shared limit, you can supply the `-group` flag:

```powershell
Start-PodeServer {
    limit ip -g '10.10.0.0/24' -l 5 -s 1
}
```

To rate limit requests from multiple addresses in one line, the following example will work:

```powershell
Start-PodeServer {
    limit ip @('192.168.1.1', '192.168.1.2') -l 10 -s 2
}
```

Finally, to rate limit requests from every address you can use the `all` keyword:

```powershell
Start-PodeServer {
    limit ip all -l 60 -s 10
}
```

## Overriding

Since rate limiting is a legacy form of middleware in Pode, then when you setup rules via the `limit` function the point at which the limit is checked on the request lifecycle is fixed (see [here](../Overview/#order-of-running)).

This also mean you can override the inbuilt rate limiting logic, with your own custom logic, using the [`middleware`](../../../Functions/Core/Middleware) function. To override the rate limiting logic you can pass `@limit` to the `-Name` parameter of the `middleware` function.

The following example uses rate limiting, and defines `middleware` that will override the inbuilt limiting logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    # assign limiting to localhost
    limit ip @('127.0.0.1', '[::1]') -limit 10 -seconds 2

    # create middleware to override the inbuilt rate limiting logic.
    # this will ignore the limiting part, and just allow the request
    middleware -name '@limit' {
        return $true
    }

    # basic route
    route get '/' {
        # logic
    }
}
```