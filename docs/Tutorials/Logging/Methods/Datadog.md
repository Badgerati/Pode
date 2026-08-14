# Datadog

The Datadog Log Method allows you to send logs to Datadog. This Log Method uses the general [`New-PodeLogApiMethod`](../../../../Functions/Logging/New-PodeLogApiMethod) under-the-hood.

## Creation

To create a new Datadog Log Method use [`New-PodeLogDatadogMethod`](../../../../Functions/Logging/New-PodeLogDatadogMethod), and supply the `-BaseUrl` for the server you wish to send logs to, and your `-ApiKey` for authentication.

The `-BaseUrl` should be like `https://http-intake.logs.datadoghq.eu`, Pode will append the `/api/v2/logs` for you.

If you wish to ignore any certificate checks, you may supply `-SkipCertificateCheck`.

### Service

The default service for your logs sent by Pode is the [Server's App Name](../../../../Basic#app-name). If you wish to supply an explicit service different from the server's, then you can do so via the `-Service` parameter.

### Source

The default source type sent by Pode is empty, if you wish to supply a source you can do so via the `-Source` parameter.

### Tags

The default tags supplied by Pode is empty, if you wish to supply any tags you can do so via the `-Tags` parameter as a hashtable.

## Override

You can use [`New-PodeLogDatadogOverride`](../../../../Functions/Logging/New-PodeLogDatadogOverride) to override certain properties of the Datadog Log Method, when calling either [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog) or [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

You can override the `-Source`, `-Service`, and `-Tags`, as well as specify `-Ignore`, which allows you to specify that certain log items will not be logged to Datadog.

If you don't specify an `-Id` then the override will apply to all Datadog Log Methods configured for a Log Type.

```powershell
# override the Service when logging to Datadog
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogDatadogOverride -Service 'custom_service'
)

# if you have an error log method configured with datadog and terminal logging,
# the below will only log the error to the terminal and ignore logging to datadog
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogDatadogOverride -Ignore
)
```

For Tags, you can specify a `-TagsAction` to define how the override tags are used. The default is `Merge`, which will combine the two sets of tags together, with the override's taking precedence during conflicts. The other option is `Replace`, which will use the override's tags completely in place of the Log Method's.

```powershell
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogDatadogOverride -Tags @{
        Key1 = 'Value1'
        Key2 = 'Value2'
    }
)
```

## Examples

### Send Request Logs

The following example will send Request logs to Datadog.

```powershell
$method = New-PodeLogDatadogMethod -BaseUrl 'https://http-intake.logs.datadoghq.eu' -ApiKey '<key>'
$method | Enable-PodeLogRequestType
```

### Send Error Logs

The following example will send JSON serialised Error logs to Datadog.

```powershell
$method = New-PodeLogDatadogMethod -BaseUrl 'https://http-intake.logs.datadoghq.eu' -ApiKey '<key>'
$method | Enable-PodeLogErrorType -SerialiseFormat Json
```
