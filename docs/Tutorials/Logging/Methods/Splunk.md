# Splunk

The Splunk Log Method allows you to send logs to your Splunk server - self-hosted or cloud. This Log Method uses the general [`New-PodeLogApiMethod`](../../../../Functions/Logging/New-PodeLogApiMethod) under-the-hood.

## Creation

To create a new Splunk Log Method use [`New-PodeLogSplunkMethod`](../../../../Functions/Logging/New-PodeLogSplunkMethod), and supply the `-BaseUrl` for the server you wish to send logs to, and your HTTP Endpoint Collection's `-Token` for authentication.

The `-BaseUrl` should be like `http://localhost:8088`, Pode will append the `/services/collector` for you.

If you wish to ignore any certificate checks, you may supply `-SkipCertificateCheck`.

### Source Type

The default source type sent by Pode is empty, allowing Splunk to automatically select the best fit. However, if you wish to supply an explicit source type you can do so via the `-SourceType` parameter.

### Source

The default source for your logs sent by Pode is the [Server's App Name](../../../../Basic#app-name). If you wish to supply an explicit source different from the server's, then you can do so via the `-Source` parameter.

### Index

The default index supplied by Pode is empty, which usually equates to the main index in Splunk. However, if you wish to supply an explicit index you can do so via the `-Index` parameter.

## Examples

### Send Request Logs

The following example will send Request logs to your Splunk server.

```powershell
$method = New-PodeLogSplunkMethod -BaseUrl 'http://localhost:8088' -Token '<token>'
$method | Enable-PodeLogRequestType
```

### Send Error Logs

The following example will send non-serialised and non-formatted Error logs to your Splunk server (ie, a raw hashtable which will be "serialised" as JSON when sending to the Splunk API).

```powershell
$method = New-PodeLogSplunkMethod -BaseUrl 'http://localhost:8088' -Token '<token>'
$method | Enable-PodeLogErrorType -SerialiseFormat None
```
