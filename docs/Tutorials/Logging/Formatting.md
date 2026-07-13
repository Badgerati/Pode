# Formatting

You can customise the formatting and serialisation of your Log Types, by supplying the parameters as described below.

Within the scope of a Log Type, ie the "Transform Phase", the steps are as follows:

```mermaid
graph LR
    Selection("`Selection`")

    Serialisation("`Serialisation`")

    Formatting("`Formatting`")

    Selection --> Serialisation
    Serialisation --> Formatting
```

| Step          | Description                                                                             | Related Parameters                             |
| ------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Selection     | Required data from the original log item is selected, and returned (ie, as a hashtable) | `-ScriptBlock`                                 |
| Serialisation | The resultant data, if required, is serialised (ie, as JSON, custom, etc.)              | `-SerialiseFormat` and `-SerialiseScriptBlock` |
| Formatting    | The resultant, or serialised, data is converted into some log format (ie, syslog)       | `-LogFormat` and `-LogScriptBlock`             |

## Serialisation

Log Types support the following serialisation methods, which can be supplied using the `-SerialiseFormat` parameter:

* None
* Custom
* Json
* Xml
* Yaml

The default for inbuilt Log Types like Error/Request is None, while the default for custom Log Types is None.

### None

When None is specified, no serialisation method is applied and the data returned by the Log Type's `-ScriptBlock` is passed straight to formatting.

### Custom

When Custom is specified then a `-SerialiseScriptBlock` is required to be supplied as well.

!!! note
    For inbuilt Log Types, like Error/Request, "Custom" is the default. Here a `-SerialiseScriptBlock` is optional as inbuilt logic will be used if not supplied.

When serialisation occurs, this scriptblock will be invoked. Supplied to this scriptblock are the following parameters:

1. The resultant data returned from the Log Type's main `-ScriptBlock`
2. The [Log Event](../Objects#log-event) object
3. Items supplied to `-ArgumentList`, splatted as individual parameters

For example, the inbuilt Request Log Type's serialise scriptblock looks as follows; it will serialise the data into Combined Log Format:

```powershell
$scriptblock = {
    param($data)

    $reqLine = "$($data.Request.Method) $($data.Request.Resource) $($data.Request.Protocol)"
    $date = $data.Date.ToString('dd/MMM/yyyy:HH:mm:ss zzz')

    return "$($data.Request.Host) $($data.Request.Identifier) $($data.Request.User) [$($date)] `"$($reqLine)`" $($data.Response.Status.Code) $($data.Response.Size) `"$($data.Request.Referrer)`" `"$($data.Request.UserAgent)`""
}
```

ie:
```plain
10.10.0.3 - - [14/Jun/2018:20:23:52 +01:00] "GET /api/users HTTP/1.1" 200 9001 "-" "<user-agent>"
```

### Others

The other standard serialisation options: JSON; XML; and YAML, will all serialise the resultant data returned from the Log Type's main `-ScriptBlock`.

For example, if you supply `-SerialiseFormat Json` to [`Enable-PodeLogRequestType`](../../../../Functions/Logging/Enable-PodeLogRequestType), then instead of Combined Log Format (the default) you'll get:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -SerialiseFormat Json
```

```json
{
    "Host": "10.10.0.3",
    "Identifier": null,
    "User": null,
    "Date": "14/Jun/2018:20:23:52 +01:00",
    "Method": "GET",
    "Resource": "/api/users",
    "Protocol": "HTTP/1.1",
    "StatusCode": 200,
    "Size": 9001,
    "Referrer": "",
    "UserAgent": "<user-agent>"
}
```

#### XML

When serialising custom Log Types into XML the default root element is `<root>`, this can be customised via `-XmlRootName`.

### Global

You can configure a global serialisation format to use via [`Set-PodeLogDefaultSerialiseFormat`](../../../Functions/Logging/Set-PodeLogDefaultSerialiseFormat). If you **don't** supply `-SerialiseFormat` then the global default will be used instead.

By default there is no global default; not supplying `-SerialiseFormat` will default to the Log Type's local default value - format inbuilt type this is Custom, and for custom types this is None.

## Log Format

Log Types support the following formats, which can be supplied using the `-LogFormat` parameter:

* None (default)
* Custom
* Syslog

This occurs after serialisation, so the "message" will typically be the resultant data from the Log Type, and post any serialisation. For example, allowing you to have a syslog formatted message, where the message part is JSON.

### None

When None is specified, then no formatting is performed on the log item. Whatever resultant data was returned from the Log Type's `-ScriptBlock`, and optionally supplied to any serialisation, will remain as is.

### Custom

When Custom is specified then a `-LogScriptBlock` is required to be supplied as well.

When log formatting occurs, after serialisation, this scriptblock will be invoked. Supplied to this scriptblock are the following parameters:

1. The resultant data returned from the Log Type's main `-ScriptBlock`, and after any serialisation
2. The [Log Event](../Objects#log-event) object
3. Items supplied to `-ArgumentList`, splatted as individual parameters

For example, a simple pipe-delimited format of `<LEVEL>|<DATETIME>|<MESSAGE>:

```powershell
$scriptblock = {
    param($data, $logEvent)
    return "$($logEvent.Level)|$($logEvent.Timestamp)|$($data)
}
```

### Syslog

When Syslog is specified, then the resultant data - after serialisation - is set as the "message" component of a syslog formatted string ([more details](https://www.manageengine.com/products/eventlog/logging-guide/syslog/syslog-basics-logging.html)). Supported are the following formats:

* RFC5424 (default)
* RFC3164

By default, this will be RFC5424 format with a facility value of 16 (local0). These values can be customised, and tags included, by creating a `SyslogInfo` object via [`New-PodeLogSyslogInfo`](../../../../Functions/Logging/New-PodeLogSyslogInfo); the result of which can then be supplied to a Log Type's `-SyslogInfo` parameter.

For example if you specify `-LogFormat Syslog` on [`Enable-PodeLogRequestType`](../../../../Functions/Logging/Enable-PodeLogRequestType), with no `-SyslogInfo` object, then the result syslog message sent to a Log Method would be RFC5424 format:

```powershell
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -LogFormat Syslog
```

```plain
<134>1 2018-06-14T20:23:52.000+01:00 APP-VM-1 Pode 6132 - - 10.10.0.3 - - [14/Jun/2018:20:23:52 +01:00] "GET /api/users HTTP/1.1" 200 9001 "-" "<user-agent>"
```

!!! note
    The application name used, if not specified in a SyslogInfo object, will be the [Server's App Name](../../../../Basic#app-name).

To change the format to RFC3164:

```powershell
$syslogInfo = New-PodeLogSyslogInfo -Format RFC3164
New-PodeLogTerminalMethod | Enable-PodeLogRequestType -LogFormat Syslog -SyslogInfo $syslogInfo
```

### Global

You can configure a global log format to use via [`Set-PodeLogDefaultFormat`](../../../Functions/Logging/Set-PodeLogDefaultFormat). If you **don't** supply `-LogFormat` then the global default will be used instead.

By default there is no global default; not supplying `-LogFormat` will default to the Log Type's local default value - usually None.

The same can also be done for syslog formatting using [`Set-PodeLogDefaultSyslogFormat`](../../../Functions/Logging/Set-PodeLogDefaultSyslogFormat). Similar to above this will apply when either no `-SyslogInfo` is supplied, or no `-Format` is supplied to [`New-PodeLogSyslogInfo`](../../../Functions/Logging/New-PodeLogSyslogInfo).
