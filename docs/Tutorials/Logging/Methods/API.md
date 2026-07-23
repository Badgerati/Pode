# API

The API Log Method allows you to send logs to custom API servers - self-hosted or cloud.

## Creation

To create a new API Log Method use [`New-PodeLogApiMethod`](../../../../Functions/Logging/New-PodeLogApiMethod), and supply the `-Url` of the API to call, along with a `-BodyScriptBlock` for generating the appropriate string payload to send to the API. The parameters passed to the scriptblock will be a list of [Log Items](../../Objects#log-item), and any arguments supplied via `-BodyArguments`.

If you wish to ignore any certificate checks, you may supply `-SkipCertificateCheck`.

By default Pode will send the payload uncompressed, if you require for it to be GZip compressed supply `-Compress` - this will automatically GZip compress the payloads returned from `-BodyScriptBlock`, and also add the `Content-Encoding` HTTP header.

Typically most APIs require some form of authentication, usually via the `Authorization` HTTP header. You can add this header via the `-Headers` parameter, as a hashtable key.

```powershell
$headers = @{
    Authorization = "Bearer $($your_token)"
}

New-PodeLogApiMethod -Url '<url>' -Headers $headers -Compress -BodyScriptBlock {
    param($logItems)

    $events = @(foreach $logItem in $logItems) {
        @{
            message   = $logItem.Data
            level     = $logItem.Event.Level
            timestamp = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
    }

    return $events | ConvertTo-Json -Compress -Depth 10
}
```

### Content Type

The default content type sent by Pode is `application/json`, if you wish to supply a different content type you can do so via the `-ContentType` parameter.

### Method

The default HTTP method used by Pode for calling the API is `POST`, if you wish to supply a different method you can do so via the `-Method` parameter.

The `-Method` parameter accepts `POST`, `GET`, `PUT`, and `PATCH`.

### Dynamic Headers

The simplest way to supply headers to be added onto API requests is via `-Headers`:

```powershell
New-PodeLogApiMethod ... -Headers @{
    Authorization = "Bearer $($your_token)"
}
```

However, at times you might need to generate headers dynamically - such as headers that require the current datetime, or headers that have to be signed using the generated body. To do so you can supply a scriptblock to `-HeadersScriptBlock`, which will be passed the generated body and any arguments from `-HeadersArguments`. This scriptblock should return a valid hashtable - or `$null`.

```powershell
New-PodeLogApiMethod ... -HeadersScriptBlock {
    param($body)

    return @{
        Timestamp = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
}
```

## Override

You can use [`New-PodeLogApiOverride`](../../../../Functions/Logging/New-PodeLogApiOverride) to override certain properties of an API Log Method, when calling either [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog) or [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

You can specify a hashtable of custom properties via `-Data`, as well as specify `-Ignore`, which allows you to specify that certain log items will not be logged via the API.

If you don't specify an `-Id` then the override will apply to all API Log Methods configured for a Log Type.

```powershell
# supply custom override properties for an API Log Method
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogApiOverride -Data @{
        Key1 = 'Value1'
        Key2 = 'Value2'
    }
)

# if you have an error log method configured with API and terminal logging,
# the below will only log the error to the terminal and ignore logging via API
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogApiOverride -Ignore
)
```

Within your `-BodyScriptBlock` for your API Log Method, you can retrieve the override data for a Log Event using [`Get-PodeLogOverride`](../../../../Functions/Logging/Get-PodeLogOverride):

```powershell
# setup the method
$headers = @{
    Authorization = "Bearer $($your_token)"
}

New-PodeLogApiMethod -Url '<url>' -Headers $headers -Compress -BodyScriptBlock {
    param($logItems)

    $events = @(foreach $logItem in $logItems) {
        # get override data
        $override = Get-PodeLogOverride -LogEvent $logItem.Event

        # define the event item, using a service override if available
        @{
            message   = $logItem.Data
            level     = $logItem.Event.Level
            timestamp = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            service   = Protect-PodeValue -Value $override.Data.Service -Default 'Website'
        }
    }

    return $events | ConvertTo-Json -Compress -Depth 10
} | Enable-PodeLogErrorType

# log to it
try {
    # ...
}
catch {
    $_ | Write-PodeErrorLog -Override @(
        New-PodeLogApiOverride -Data @{ Service = 'Portal' }
    )
}
```

## Examples

### Send Request Logs

The following example will send Request logs to an API endpoint, using a bearer authentication token. The body will be sent as JSON, and will be GZip compressed.

```powershell
$headers = @{
    Authorization = "Bearer $($your_token)"
}

New-PodeLogApiMethod -Url 'http://api.example.com/logs' -Headers $headers -Compress -BodyScriptBlock {
    param($logItems)

    $events = @(foreach $logItem in $logItems) {
        @{
            message = $logItem.Data
            level   = $logItem.Event.Level
            timestamp = $item.Event.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
    }

    return $events | ConvertTo-Json -Compress -Depth 10
}
```
