# Requests

Pode has an inbuilt Request Log Type, which will parse and transform web requests for use with any supplied Log Method.

!!! note
    This Log Type currently only supports web requests.

## Enabling

To enable the Request Log Type use [`Enable-PodeLogRequestType`](../../../../Functions/Logging/Enable-PodeLogRequestType), and supply one or more Log Methods - such as the [Terminal](../../Methods/Terminal) Method.

You can call [`Enable-PodeLogRequestType`](../../../../Functions/Logging/Enable-PodeLogRequestType) multiple times, supplying a different `-Name` for each, to enable multiple Request Log Types. When multiple are enabled, a Request will be sent to all enabled Request Log Types.

!!! note
    For backwards compatibility support: if you call `Enable-PodeLogRequestType` with no `-Name`, then a default name will be used. Subsequent `Enable-PodeLogRequestType` calls **must** supply a `-Name`.

!!! important
    The `Enable-PodeRequestLogging` function is now deprecated, please use [`Enable-PodeLogRequestType`](../../../../Functions/Logging/Enable-PodeLogRequestType) instead. The former is aliased to the latter for now.

## Custom Logic

By default, if you supply no `-ScriptBlock`, Pode will use inbuilt data selection logic on request log items. However, if you do supply a custom `-ScriptBlock` then you can select/return your own data.

This custom scriptblock will be supplied the [Log Event](../../Objects#log-event), and any arguments supplied to `-ArgumentList`, as parameters.

```powershell
Enable-PodeLogRequestType -ScriptBlock {
    param($logEvent)
    return @{
        Method = $logEvent.Data.Request.Method
    }
}
```

!!! note
    The `$logEvent.Data` will be the same raw data as found in below in [Raw Request](#raw-request).

## Formatting

More information on formatting can be [found here](../../Formatting).

The Request Log Type also has its own additional formatting options supplied via `-Format`, and will transform a supplied raw web request into one of the following formats:

* Combined (default)
* Common
* W3C

This formatted string is then supplied to the Log Methods. If you're using a Custom Log Method and want the raw unformatted log item instead, you can supply `-Raw` to [`Enable-PodeLogRequestType`](../../../../Functions/Logging/Enable-PodeLogRequestType).

### W3C

Unlike the Common and Combined log formats, with W3C you can customise the fields that are logged.

To do this you will need to build and supply a W3C Info object to the `-W3CInfo` parameter. This info object will let you define which inbuilt fields to log, as well as which request/response headers, and any process environment variables. To build the info object, you'll need to use [`New-PodeLogW3CInfo`](../../../../Functions/Logging/New-PodeLogW3CInfo), and supply `-Fields` using [`Add-PodeLogW3CField`](../../../../Functions/Logging/Add-PodeLogW3CField) or [`Add-PodeLogW3CCustomField`](../../../../Functions/Logging/Add-PodeLogW3CCustomField).

The inbuilt fields are:

| Field          | Description                                                 |
| -------------- | ----------------------------------------------------------- |
| date           | The date that the request occurred, as `yyyy-MM-dd`         |
| time           | The time that the request occurred, as `HH:mm:ss`           |
| c-ip           | The IP address of the client making the request             |
| cs-username    | The username of any authenticated user                      |
| s-ip           | The IP address of the endpoint the request was received on  |
| s-port         | The port of the endpoint the request was received on        |
| s-computername | The computer name of the server the request was received on |
| cs-method      | The HTTP method of the request                              |
| cs-uri-stem    | The URI stem of the request                                 |
| cs-uri-query   | The query string of the request                             |
| sc-status      | The HTTP status code of the response                        |
| time-taken     | The time taken to process the request, in milliseconds      |
| sc-bytes       | The number of bytes sent by the server                      |
| cs-bytes       | The number of bytes received from the client                |
| cs-version     | The HTTP version of the request                             |
| cs-host        | The host header of the request                              |

Any custom fields will be named as follows:

| Type        | Field Decorator |
| ----------- | --------------- |
| Request     | `cs(...)`       |
| Response    | `sc(...)`       |
| Environment | `x-...`         |

If nothing is supplied to `-W3CInfo` then default fields will be used instead, in the ordered displayed here:

* date
* time
* c-ip
* cs-method
* cs-uri-stem
* cs-uri-query
* cs-username
* sc-status
* time-taken
* cs(USer-Agent)
* cs(Referer)

For example, the following will log requests in W3C format to the terminal:

```powershell
$fields = New-PodeLogW3CInfo -Fields @(
    Add-PodeLogW3CField -Name 'date'
    Add-PodeLogW3CField -Name 'time'
    Add-PodeLogW3CField -Name 'c-ip'
    Add-PodeLogW3CField -Name 'cs-method'
    Add-PodeLogW3CField -Name 'cs-uri-stem'
    Add-PodeLogW3CField -Name 'cs-uri-query'
    Add-PodeLogW3CField -Name 'cs-username'
    Add-PodeLogW3CField -Name 'sc-status'
    Add-PodeLogW3CField -Name 'time-taken'
    Add-PodeLogW3CCustomField -Name 'User-Agent' -Type Request
    Add-PodeLogW3CCustomField -Name 'Referer' -Type Request
)

New-PodeLogTerminalMethod | Enable-PodeLogRequestType -Format W3C -W3CInfo $fields
```

Additionally, with this being W3C format, the first log item being written after server Start or Restart will also produce the following directive log headers:

```plain
#Software: Pode 2.14.0
#Version: 1.0
#Date: 2026-07-14 18:55:00
#Fields: date time c-ip cs-method cs-uri-stem cs-uri-query cs-username sc-status time-taken cs(USer-Agent) cs(Referer)
```

If you do not want these to appear, supply `-NoLogHeader` to `New-PodeLogW3CInfo`.

## Remote IP

When logging requests, Pode will log the client's remote IP as the IP of network connection. Meaning if you're running Pode behind a proxy, you'll get the proxy's IP and not the originating client's IP.

You can use the `-RemoteIPHeader` parameter to set one, or more, possible headers to check for the original client IP - typically `X-Forwarded-For` unless you're using a custom header. If the header is present on the request, that IP will be used; if no header is found then the default will be the raw network connection's IP.

If multiple request header names are supplied, they will be checked in the order they are supplied.

## Timestamps

By default all timestamps will use the hosting server's local time, if you require the timestamps to be explicitly UTC then supply `-AsUtc` to `Enable-PodeLogRequestType`.

## Examples

### Log to Terminal

The following example enables the Request Log Type, and will output all items to the Terminal:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType
```

### Log Multiple

The following example enables 2 Request Log Types, one with the inbuilt default name and one with a custom name:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -Name 'custom-req'
```

### Log Proxy IP

The following example enables the Request Log Type, and will fetch the client IP from `X-Forwarded-For`:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -RemoteIPHeader 'X-Forwarded-For'
```

### Log as JSON

The following example enables the Request Log Type, and will output all items to the Terminal as JSON:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -SerialiseFormat Json
```

### Log as Syslog

The following example enables the Request Log Type, and will output all items to the Terminal in Syslog format:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -LogFormat Syslog
```

### Log to Multiple

The following example will also enable the Request Log Type, but will output all items to the Terminal and to a File:

```powershell
$methods = @(
    New-PodeLogTerminalMethod
    New-PodeLogFileMethod -Name 'requests'
)

$methods | Enable-PodeLogRequestType
```

### Using Raw Item

The following example uses a Custom Log Method, and sets the Request Log Type to supply the raw log item to the Custom method's scriptblock instead of a transformed one. The Custom Method simply logs the Host and StatusCode to the terminal (but could be to something like an S3 bucket):

```powershell
$method = New-PodeLogCustomMethod -ScriptBlock {
    param($item)
    "$($item.Host) - $($item.Response.StatusCode)" | Out-Default
}

$method | Enable-PodeLogRequestType -Raw
```

### Username

If you're not using any Authentication then the "user" field in the log will always be "-". However, if you're using Authentication, and it passes, then the Username of the user accessing the Route will attempt to be retrieved from `$WebEvent.Auth.User`. The property within the authenticated user object by default is `Username`, but you can customise this using `-UsernameProperty`.

For example, if the username was actually user "ID":

```powershell
Enable-PodeLogRequestType -UsernameProperty 'ID'
```

Or if the "Username" property is instead a sub-property of another "Meta" property:

```powershell
Enable-PodeLogRequestType -UsernameProperty 'Meta.Username'
```

## Raw Request

The raw log item that the Request Log Type will supply to any Custom Log Method will be the following hashtable - this is also the data that will be supplied to any custom `-ScriptBlock`:

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
