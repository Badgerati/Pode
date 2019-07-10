# Access

## Description

The `access` function allows you to specify rules to allow/deny IP addresses or subnets access to your routes. If an IP address hits your server that you've denied access, then a 403 response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

## Examples

### Example 1

The following example will allow access from the localhost:

```powershell
Start-PodeServer {
    access allow ip '127.0.0.1'
}
```

!!! tip
    It's best to use `@('127.0.0.1', '[::1]')` for localhost instead of just `127.0.0.1`, as this will allow the IPv6 localhost address as well.

### Example 2

The following example will allow access from multiple IP addresses:

```powershell
Start-PodeServer {
    access allow ip @('192.168.1.1', '192.168.1.2')
}
```

### Example 3

The following example will deny access from a subnet mask:

```powershell
Start-PodeServer {
    access deny ip '10.10.0.0/24'
}
```

### Example 4

The following example will deny access from all IP addresses:

```powershell
Start-PodeServer {
    access deny ip all
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Permission | string | true | The type of access for the IP address/subnet (Values: Allow, Deny) | empty |
| Type | string | true | The type of what you wish to restrict access (Values: IP) | empty |
| Value | object | true | The IP address or subnet mask to apply the access rule | null |

!!! info
    There are plans to expand `access` to restrict content types as well.