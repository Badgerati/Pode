# Components

When building limit rules - such as Access or Rate - you build them using various "components". The following inbuilt components currently exist:

* IP
* Route
* Endpoint
* Method
* Header

You can use these components on their own, or combine them to make more advanced limit rule configurations. For example, limit requests from a subnet to a specific group of Routes - say limiting requests to 10 per minute, to the Routes under `/api/*`:

```powershell
Add-PodeLimitRateRule -Name 'example' -Limit 10 -Duration 60000 -Component @(
    New-PodeLimitIPComponent -Value '10.10.0.0/24' -Group
    New-PodeLimitRouteComponent -Value '/api/*' -Group
)
```

## IP

An IP Component can be created via [`New-PodeLimitIPComponent`](../../../../../Functions/Limit/New-PodeLimitIPComponent). You can specify none, one, or more IP or subnet addresses - if none are supplied, then the component will match every IP.

```powershell
# match every IP - and treat them individually
New-PodeLimitIPComponent

# match every IP - but treat them as 1 entity
New-PodeLimitIPComponent -Group

# match specific IP address(es)
New-PodeLimitIPComponent -IP '10.0.0.92', '192.0.1.131'

# match all IPs in a subnet - and treat them individually
New-PodeLimitIPComponent -IP '10.0.1.0/16'

# match all IPs in a subnet - but treat them as 1 entity
New-PodeLimitIPComponent -IP '10.0.1.0/16' -Group
```

## Route

A Route Component can be created via [`New-PodeLimitRouteComponent`](../../../../../Functions/Limit/New-PodeLimitRouteComponent). You can specify none, one, or more Route paths - if none are supplied, then the component will match every Route path. You can also use wildcard/regex to match multiple Routes.

```powershell
# match every Route - and treat them individually
New-PodeLimitRouteComponent

# match every Route - but treat them as 1 entity
New-PodeLimitRouteComponent -Group

# match specific Route path(s)
New-PodeLimitRouteComponent -Path '/download', '/api/users'

# match all Routes via a wildcard - and treat them individually
New-PodeLimitRouteComponent -Path '/api/*'

# match all Routes via a wildcard - but treat them as 1 entity
New-PodeLimitRouteComponent -Path '/api/*' -Group
```

## Endpoint

An Endpoint Component can be created via [`New-PodeLimitEndpointComponent`](../../../../../Functions/Limit/New-PodeLimitEndpointComponent). You can specify none, one, or more Endpoint names - if none are supplied, then the component will match every Endpoint.

```powershell
# match every Endpoint - and treat them individually
New-PodeLimitEndpointComponent

# match specific Endpoint(s)
New-PodeLimitEndpointComponent -Name 'api', 'admin'
```

## Method

A Method Component can be created via [`New-PodeLimitMethodComponent`](../../../../../Functions/Limit/New-PodeLimitMethodComponent). You can specify none, one, or more HTTP methods - if none are supplied, then the component will match every method.

```powershell
# match every Method - and treat them individually
New-PodeLimitMethodComponent

# match specific Method(s)
New-PodeLimitMethodComponent -Method 'Get', 'Post'
```

## Header

A Header Component can be created via [`New-PodeLimitHeaderComponent`](../../../../../Functions/Limit/New-PodeLimitHeaderComponent). You can specify one or more Headers, and you can also specify specific values for the Headers to match on as well.

```powershell
# match a specific Header - and treat different values individually
New-PodeLimitHeaderComponent -Name 'X-API-KEY'

# match a specific Header - but ignore the value, and treat them as 1 entity
New-PodeLimitHeaderComponent -Name 'X-API-KEY' -Group

# match a specific Header, with a specific value
New-PodeLimitHeaderComponent -Name 'X-API-KEY' -Value '1c1aad92-194e-433a-bf0a-385434dcac13'
```
