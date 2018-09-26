# Limit

## Description

The `limit` function allows you to specify rate limiting rules on IP addresses or subnets to limit access to your routes. If an IP address hits your server and has exceeded the rate limit counter within the defined period, then a 429 response is returned and the connection immediately closed. For SMTP/TCP servers the connection is just closed with no response.

## Examples

### Example 1

The following example will limit the localhost to 5 requests per second:

```powershell
Server {
    limit ip 127.0.0.1 -limit 5 -seconds 1
}
```

!!! tip
    It's best to use `@('127.0.0.1', '[::1]')` for localhost instead of just `127.0.0.1`, as this will limit the IPv6 localhost address as well.

### Example 2

The following example will limit multiple IP addresses to 5 requests per 10 seconds:

```powershell
Server {
    limit ip @('192.168.1.1', '192.168.1.2') -l 5 -s 10
}
```

### Example 3

The following example will limit a subnet mask to 5 requests per second, per each individual IP address governed by that subnet mask:

```powershell
Server {
    limit ip '10.10.0.0/24' -l 5 -s 1
}
```

!!! info
    So here, the IP addresses `10.10.0.1` and `10.10.0.2` are under the subnet mask `10.10.0.0/24`; each IP address will each get 5 requests per second before hitting the limit. Therefore if the first IP made 3req/s and the second made 3req/s, then the each call will be allowed through.

### Example 4

The following example will limit a subnet mask to 5 requests per second, where all IP addresses governed by the subnet are treated as one:

```powershell
Server {
    limit ip -group '10.10.0.0/24' -l 5 -s 1
}
```

!!! info
    So here, the IP addresses `10.10.0.1` and `10.10.0.2` are under the subnet mask `10.10.0.0/24`; each IP address will get a single grouped 5 requests per second before hitting the limit. Therefore if the first IP made 3req/s and the second made 3req/s, then the final call from the second will get a `429` response.

### Example 5

The following example will limit requests from all IP addresses to 10 requests per minute:

```powershell
Server {
    limit ip all -l 10 -s 60
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Type | string | true | The type of what you wish to limit access (Values: IP) | empty |
| Value | object | true | The IP address or subnet mask to apply rate limiting | null |
| Limit | int | true | The amount of requests to allow within the given number of seconds, before a 429 status is returned | 0 |
| Seconds | int | true | The number of seconds to wait before resetting the rate limit counter | 0 |
| Group | switch | false | Only applies to subnet masks; if passed, all IP addresses governed by the mask will restricted by the same rate limit counter, rather than individually | false |

!!! info
    There are plans to expand `limit` to limit content types as well.