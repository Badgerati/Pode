# Formatting

You can customise the formatting and serialisation of your log types, by supplying the parameters as described below.

Within the scope of a log type, ie the "Transform Phase", the steps are as follows:

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
| Formatting    | The resultant, or serialised, data is converted into some log format (ie, syslog)       | `-LogFormat`                                   |

## Serialisation

Log types support the following serialisation methods, which can be supplied using the `-SerialiseFormat` parameter:

* None
* Custom
* Json
* Xml
* Yaml

The default for inbuilt log types like Error/Request is None, while the default for custom log types is None.

### None

When None is specified, no serialisation method is applied and the data returned by the log type's `-ScriptBlock` is passed straight to formatting.

### Custom

When Custom is specified then a `-SerialiseScriptBlock` is required to be supplied as well.

!!! note
    For inbuilt log types, like Error/Request, "Custom" is the default. Here a `-SerialiseScriptBlock` is optional as inbuilt logic will be used if not supplied.

When serialisation occurs, this scriptblock will be invoked. Supplied to this scriptblock are the following parameters:

* The resultant data returned from the log type's main `-ScriptBlock`
* Items supplied to `-ArgumentList`, splatted as individual parameters

For example, the inbuilt Request log type's serialise scriptblock looks as follows; it will serialise the data into Combined Log Format:

```powershell
$scriptblock = {
    param($data)
    $reqLine = "$($data.Method) $($data.Resource) $($data.Protocol)"
    return "$($data.Host) $($data.Identifier) $($data.User) [$($data.Date)] `"$($reqLine)`" $($data.StatusCode) $($data.Size) `"$($data.Referrer)`" `"$($data.UserAgent)`""
}
```

ie:
```plain
10.10.0.3 - - [14/Jun/2018:20:23:52 +01:00] "GET /api/users HTTP/1.1" 200 9001 "-" "<user-agent>"
```

### Others

The other standard serialisation options: JSON; XML; and YAML, will all serialise the resultant data returned from the log type's main `-ScriptBlock` into that type.

For example, if you supply `-SerialiseFormat Json` to [`Enable-PodeRequestLogType`](../../../../Functions/Logging/Enable-PodeRequestLogType), then instead of Combined Log Format (the default) you'll get:

```powershell
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -SerialiseFormat Json
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

When serialising custom log types into XML the default root element is `<root>`, this can be customised via `-XmlRootName`.

## Log Format

Log types support the following formats, which can be supplied using the `-LogFormat` parameter:

* None (default)
* Syslog

### None

When None is specified, then no formatting is performed on the log item. Whatever resultant data was returned from the log type's `-ScriptBlock`, and optionally supplied to any serialisation, will remain as is.

### Syslog

When Syslog is specified, then the resultant data - after serialisation - is set as the "message" component of a syslog formatted string ([more details](https://www.manageengine.com/products/eventlog/logging-guide/syslog/syslog-basics-logging.html)). Supported are the following formats:

* RFC5424 (default)
* RFC3164

By default, this will be RFC5424 format with a facility value of 16 (local0). These values can be customised, and tags included, by creating a `SyslogInfo` object via [`New-PodeLogSyslogInfo`](../../../../Functions/Logging/New-PodeLogSyslogInfo); the result of which can then be supplied to a log type's `-SyslogInfo` parameter.

For example if you specify `-LogFormat Syslog` on [`Enable-PodeRequestLogType`](../../../../Functions/Logging/Enable-PodeRequestLogType), with no `-SyslogInfo` object, and the default Custom serialisation, then the result syslog message sent to a log method would be:

```powershell
New-PodeLogTerminalMethod | Enable-PodeRequestLogType -LogFormat Syslog
```

```plain
<134>1 2018-06-14T20:23:52.000+01:00 APP-VM-1 Pode 6132 - - 10.10.0.3 - - [14/Jun/2018:20:23:52 +01:00] "GET /api/users HTTP/1.1" 200 9001 "-" "<user-agent>"
```

!!! note
    The application name used, if not specified in a SyslogInfo object, will be the `-AppName` supplied to [`Start-PodeServer`](../../../../Functions/Core/Start-PodeServer) - or "Pode" by default.
