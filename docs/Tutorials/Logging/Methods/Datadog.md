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
