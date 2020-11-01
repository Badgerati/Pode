# Requests

Pode has inbuilt Request logging logic, that will parse and return a valid log item for whatever method of logging you supply.

## Enabling

To enable and use the Request logging you use the [`Enable-PodeRequestLogging`](../../../../Functions/Logging/Enable-PodeRequestLogging) function, supplying a logging method from [`New-PodeLoggingMethod`](../../../../Functions/Logging/New-PodeLoggingMethod).

The Request type logic will format a string using [Combined Log Format](https://httpd.apache.org/docs/1.3/logs.html#combined). This string is then supplied to the logging method's scriptblock. If you're using a Custom logging method and want the raw hashtable instead, you can supply `-Raw` to [`Enable-PodeRequestLogging`](../../../../Functions/Logging/Enable-PodeRequestLogging).

## Examples

### Log to Terminal

The following example simply enables Request logging, and will output all items to the terminal:

```powershell
New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
```

### Using Raw Item

The following example uses a Custom logging method, and sets Request logging to return and supply the raw hashtable to the Custom method's scriptblock. The Custom method simply logs the Host an StatusCode to the terminal (but could be to something like an S3 bucket):

```powershell
$method = New-PodeLoggingMethod -Custom -ScriptBlock {
    param($item)
    "$($item.Host) - $($item.Response.StatusCode)" | Out-Default
}

$method | Enable-PodeRequestLogging -Raw
```

## Raw Request

The raw Request hashtable that will be supplied to any Custom logging methods will look as follows:

```powershell
@{
    Host = '10.10.0.3'
    RfcUserIdentity = '-'
    User = '-'
    Date = '14/Jun/2018:20:23:52 +01:00'
    Request = @{
        Method = 'GET'
        Resource = '/api/users'
        Protocol = "HTTP/1.1"
        Referrer = '-'
        Agent = '<user-agent>'
    }
    Response = @{
        StatusCode = '200'
        StautsDescription = 'OK'
        Size = '9001'
    }
}
```
