# Access Rules

Access rules in Pode are a legacy form of middleware, that allow you to specify allow/deny rules for IP addresses and subnet masks. This means you can deny certain IPs from accessing the server, and vice-versa by allowing them.

## Usage

To setup access rules in Pode you use the [`access`](../../../Functions/Middleware/Access) function, along with an action of either `allow` or `deny`.

The make-up of the `access` function is as follows:

```powershell
access <allow|deny> ip <address|subnet>
```

You can either put a rule in for a specify IP address, a subnet mask, or for every address (using `all`). You can also supply an array of addresses/subnets as well, rather than one at a time.

!!! info
    If a requests hits your server from an address that you've denied access, then a `403` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

The following example will allow access for requests from localhost:

```powershell
Start-PodeServer {
    access allow ip '127.0.0.1'
}
```

Whereas the following example will deny access to requests from a subnet:

```powershell
Start-PodeServer {
    access deny ip '10.10.0.0/24'
}
```

To allow access to requests from multiple addresses in one line, the following example will work:

```powershell
Start-PodeServer {
    access allow ip @('192.168.1.1', '192.168.1.2')
}
```

Finally, to allow or deny access to requests from every address you can use the `all` keyword:

```powershell
Start-PodeServer {
    access deny ip all
}
```

## Overriding

Since access rules are a legacy form of middleware in Pode, then when you setup rules via the `access` function the point at which the rules are checked on the request lifecycle is fixed (see [here](../Overview/#order-of-running)).

This also mean you can override the inbuilt access rule logic, with your own custom logic, using the [`middleware`](../../../Functions/Core/Middleware) function. To override the access rule logic you can pass `@access` to the `-Name` parameter of the `middleware` function.

The following example uses access rules, and defines `middleware` that will override the inbuilt access logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    # assign access rule to deny localhost
    access deny ip @('127.0.0.1', '[::1]')

    # create middleware to override the inbuilt access rule logic.
    # this will ignore the 'deny' part, and just allow the request
    middleware -name '@access' {
        return $true
    }

    # basic route
    route get '/' {
        # logic
    }
}
```