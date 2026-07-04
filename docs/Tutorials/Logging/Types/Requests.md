# Requests

Pode has an inbuilt Request logging Type, which will parse and transform web requests for use with any supplied logging Method.

!!! note
    This log type currently only supports web requests.

## Enabling

To enable the Request logging Type use [`Enable-PodeRequestLogType`](../../../../Functions/Logging/Enable-PodeRequestLogType), and supply one or more logging Methods - such as the [Terminal](../../Methods/Terminal) Method.

!!! important
    The `Enable-PodeRequestLogging` function is now deprecated, please use [`Enable-PodeRequestLogType`](../../../../Functions/Logging/Enable-PodeRequestLogType) instead. The former is aliased to the latter for now.

## Custom Logic

By default, if you supply no `-ScriptBlock`, Pode will use inbuilt data selection logic on request log items. However, if you do supply a custom `-ScriptBlock` then you can select/return your own data.

This custom scriptblock will be supplied the Log Event, and any arguments supplied to `-ArgumentList`, as parameters. The `$logEvent` will be an `IPodeLogEvent` object, and the raw request data can be found under the `Data` property - including Timestamp, log Level, Metadata, and the log type's Name.

```powershell
Enable-PodeRequestLogType -ScriptBlock {
    param($logEvent)
    return @{
        Method = $logEvent.Data.Request.Method
    }
}
```

!!! note
    The `$logEvent.Data` will be the same raw data as found in below in [Raw Request](#raw-request).

## Formatting

More information on formatting can be [found here](../Formatting).

The Request logging Type will transform a supplied raw web request into a [Combined Log Format](https://httpd.apache.org/docs/1.3/logs.html#combined) string. This string is then supplied to the logging Method's scriptblock. If you're using a Custom logging method and want the raw log item instead, you can supply `-Raw` to [`Enable-PodeRequestLogType`](../../../../Functions/Logging/Enable-PodeRequestLogType).

## Examples

### Log to Terminal

The following example enables Request logging type, and will output all items to the Terminal:

```powershell
New-PodeLogTerminalMethod | Enable-PodeRequestLogType
```

### Log as JSON

The following example enables Request logging type, and will output all items to the Terminal as JSON:

```powershell
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -SerialiseFormat Json
```

### Log as Syslog

The following example enables Request logging type, and will output all items to the Terminal in Syslog format:

```powershell
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -LogFormat Syslog
```

### Log to Multiple

The following example will also enable Request logging type, but will output all items to the Terminal and to a File:

```powershell
$methods = @(
    New-PodeLogTerminalMethod
    New-PodeLogFileMethod -Name 'requests'
)

$methods | Enable-PodeRequestLogType
```

### Using Raw Item

The following example uses a Custom logging Method, and sets the Request logging Type to supply the raw log item to the Custom method's scriptblock instead of a transformed one. The Custom Method simply logs the Host and StatusCode to the terminal (but could be to something like an S3 bucket):

```powershell
$method = New-PodeLogCustomMethod -ScriptBlock {
    param($item)
    "$($item.Host) - $($item.Response.StatusCode)" | Out-Default
}

$method | Enable-PodeRequestLogType -Raw
```

### Username

If you're not using any Authentication then the "user" field in the log will always be "-". However, if you're using Authentication, and it passes, then the Username of the user accessing the Route will attempt to be retrieved from `$WebEvent.Auth.User`. The property within the authenticated user object by default is `Username`, but you can customise this using `-UsernameProperty`.

For example, if the username was actually user "ID":

```powershell
Enable-PodeRequestLogType -UsernameProperty 'ID'
```

Or if the "Username" property is instead a sub-property of another "Meta" property:

```powershell
Enable-PodeRequestLogType -UsernameProperty 'Meta.Username'
```

## Raw Request

The raw log item that the Request log Type will supply to any Custom logging Method will be the following hashtable - this is also the data that will be supplied to any custom `-ScriptBlock`:

```powershell
@{
    Host            = '10.10.0.3'
    RfcUserIdentity = $null
    User            = $null
    Date            = '14/Jun/2018:20:23:52 +01:00'
    UtcDate         = [datetime]
    Request = @{
        Method   = 'GET'
        Hostname = '127.0.0.1:8090'
        Scheme   = 'http'
        Resource = '/api/users'
        Query    = 'limit=100'
        Protocol = "HTTP/1.1"
        Referrer = '-'
        Agent    = '<user-agent>'
    }
    Response = @{
        StatusCode        = '200'
        StatusDescription = 'OK'
        Size              = '9001'
    }
}
```

## Serialise Data

If you supply your own custom `-SerialiseScriptBlock`, the following hashtable will be supplied - unless you also supply your own custom `-ScriptBlock`:

```powershell
[ordered]@{
    Host        = "10.10.0.3",
    Identifier  = $null,
    User        = $null,
    Date        = "14/Jun/2018:20:23:52 +01:00",
    Method      = "GET",
    Resource    = "/api/users",
    Protocol    = "HTTP/1.1",
    StatusCode  = 200,
    Size        = 9001,
    Referrer    = "",
    UserAgent   = "<user-agent>"
}
```
