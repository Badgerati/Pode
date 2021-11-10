# Requests

Pode keeps a count of the total number of Requests processed by the server. This count is kept both server-wide, and against each individual Route; the counts are also split into two: one for the total number of requests, and one for the total number of requests per status code. These counts are preserved through internal Pode server restarts.

The current count of active requests are also available.

## Server

The server wide counts contain the total number of requests in general, and per status code, regardless of the Route.

To retrieve these counts you can use the [`Get-PodeServerRequestMetric`](../../../Functions/Metrics/Get-PodeServerRequestMetric) function. This function lets you get the Total number of requests, all Status Code counts, and a count for a specific Status Code.

To get the total number of requests:

```powershell
$total = Get-PodeServerRequestMetric -Total
```

To get the total counts for all status codes:

```powershell
$codes = Get-PodeServerRequestMetric
```

And to get the total count for a specific status code:

```powershell
$code = Get-PodeServerRequestMetric -StatusCode 200
```

## Routes

The request counts for a specific Route can be retrieved via the [`Get-PodeRoute`](../../../Functions/Routes/Get-PodeRoute) function. The request metrics stored against a Route are identical to the server wide ones, but are the total counts specific to that Route.

To get the total number of requests for a Route:

```powershell
$total = (Get-PodeRoute -Method Get -Path '/about').Metrics.Requests.Total
```

To get the total counts for all status codes for a Route:

```powershell
$codes = (Get-PodeRoute -Method Get -Path '/about').Metrics.Requests.StatusCodes
```

And to get the total count for a specific status code for a Route:

```powershell
$code = (Get-PodeRoute -Method Get -Path '/about').Metrics.Requests.StatusCodes['200']
```

## Active

You can retrieve the current count of active requests by using [`Get-PodeServerActiveRequestMetric`](../../../Functions/Metrics/Get-PodeServerActiveRequestMetric). Active requests are ones that are queued internally, ready to be processed:

```powershell
$activeReqs = Get-PodeServerActiveRequestMetric
```
