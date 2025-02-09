# Access Rules

Access rules in Pode are inbuilt Middleware that allow you to specify allow/deny rules for requests, built using [Limit Components](../Components). For example, you could deny certain IPs from accessing the server, and vice-versa by allowing them.

## Usage

To create access rules in Pode you use the [`Add-PodeLimitAccessRule`](../../../../../Functions/Limit/Add-PodeLimitAccessRule) function, together with a series of [Limit Components](../Components).

This page will give some quick examples of Access Rules, for more information on the components themselves go to the components page. However, in general you can use the components to build access rules to allow/deny IPs, subnets, access to specific Routes/Endpoints, etc.

!!! info
    If a requests hits your server from an address that you've denied access, then a `403` response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

The following example will allow access for requests from localhost:

```powershell
Add-PodeLimitAccessRule -Name 'example' -Action Allow -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1'
)
```

Whereas the following example will deny access for requests from a subnet:

```powershell
Add-PodeLimitAccessRule -Name 'example' -Action Deny -Component @(
    New-PodeLimitIPComponent -IP '10.10.0.0/24'
)
```

You can also only allow localhost access to a `/downloads` route:

```powershell
Add-PodeLimitAccessRule -Name 'example' -Action Allow -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1'
    New-PodeLimitRouteComponent -Path '/downloads'
)
```

Or, deny all requests from a subnet, and send back a custom status code:

```powershell
Add-PodeLimitAccessRule -Name 'example' -Action Deny -StatusCode 401 -Component @(
    New-PodeLimitIPComponent -IP '192.0.1.0/16'
)
```

As a last resort you can even deny all requests from any IP:

```powershell
Add-PodeLimitAccessRule -Name 'example' -Action Deny -Component @(
    New-PodeLimitIPComponent
)
```

## Priority

By default, all access rules are created with a minimum priority - meaning the rules will be executed in the order they are created.

If you want to have more control over this, you can customise the priority via the `-Priority` parameter. The higher the value, the higher the priority. If two or more rules have the same priority, then they are run in creation order.

```powershell
Add-PodeLimitAccessRule -Name 'example' -Action Deny -Priority 100 -Component @(
    New-PodeLimitIPComponent -IP '192.0.1.0/16'
)
```

## Functions

Other helper functions for access rules are:

* [`Update-PodeLimitAccessRule`](../../../../../Functions/Limit/Update-PodeLimitAccessRule)
* [`Remove-PodeLimitAccessRule`](../../../../../Functions/Limit/Remove-PodeLimitAccessRule)
* [`Test-PodeLimitAccessRule`](../../../../../Functions/Limit/Test-PodeLimitAccessRule)
* [`Get-PodeLimitAccessRule`](../../../../../Functions/Limit/Get-PodeLimitAccessRule)

## Overriding

Since access rules are an inbuilt Middleware in Pode, then when you create any rules the point at which the rules are checked on the request lifecycle is fixed (see [here](../../Overview/#order-of-running)).

This means you can override the inbuilt access rule logic with your own custom logic, using the [`Add-PodeMiddleware`](../../../../../Functions/Middleware/Add-PodeMiddleware) function. To override the access rule logic you can pass `__pode_mw_access__` to the `-Name` parameter of the [`Add-PodeMiddleware`](../../../../../Functions/Middleware/Add-PodeMiddleware) function.

The following example uses access rules, and defines Middleware that will override the inbuilt access logic:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # assign access rule to deny localhost
    Add-PodeLimitAccessRule -Name 'example' -Action Deny -Component @(
        New-PodeLimitIPComponent -IP @('127.0.0.1', '[::1]')
    )

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
