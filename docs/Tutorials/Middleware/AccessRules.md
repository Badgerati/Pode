# Access Rules

Access rules in Pode are inbuilt Middleware that allow you to specify allow/deny rules for IP addresses and subnet masks. This means you can deny certain IPs from accessing the server, and vice-versa by allowing them.

## Usage

To setup access rules in Pode you use the `Add-PodeAccessRule` function.

You can either put a rule in for a specific IP address/subnet mask, or for every address (using `all`). You can also supply an array of addresses/subnets as well, rather than one at a time.

!!! info
    If a requests hits your server from an address that you've denied access, then a `403` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

The following example will allow access for requests from localhost:

```powershell
Start-PodeServer {
    Add-PodeAccessRule -Access Allow -Type IP -Values 127.0.0.1
}
```

Whereas the following example will deny access to requests from a subnet:

```powershell
Start-PodeServer {
    Add-PodeAccessRule -Access Deny -Type IP -Values 10.10.0.0/24
}
```

To allow access to requests from multiple addresses in one line, the following example will work:

```powershell
Start-PodeServer {
    Add-PodeAccessRule -Access Allow -Type IP -Values @('192.168.1.1', '192.168.1.2')
}
```

Finally, to allow or deny access to requests from every address you can use the `all` keyword:

```powershell
Start-PodeServer {
    Add-PodeAccessRule -Access Deny -Type IP -Values 'all'
}
```

## Overriding

Since access rules are an inbuilt Middleware in Pode, then when you setup rules the point at which the rules are checked on the request lifecycle is fixed (see [here](../Overview/#order-of-running)).

This means you can override the inbuilt access rule logic with your own custom logic, using the `Add-PodeMiddleware` function. To override the access rule logic you can pass `__pode_mw_access__` to the `-Name` parameter of the `Add-PodeMiddleware` function.

The following example uses access rules, and defines Middleware that will override the inbuilt access logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # assign access rule to deny localhost
    Add-PodeAccessRule -Access Deny -Type IP -Values @('127.0.0.1', '[::1]')

    # create middleware to override the inbuilt access rule logic.
    # this will ignore the 'deny' part, and just allow the request
    Add-PodeMiddleware -Name '__pode_mw_access__' -ScriptBlock {
        return $true
    }

    # basic route
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # logic
    }
}
```
