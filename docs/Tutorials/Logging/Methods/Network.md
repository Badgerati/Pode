# Network

The Network Log Method allows you to send logs over basic UDP, TCP, or TLS options.

## Creation

To create a new Network Log Method use [`New-PodeLogNetworkMethod`](../../../../Functions/Logging/New-PodeLogNetworkMethod), and supply the `-Server` IP/Hostname, some `-Transport` option, and some `-Port` number.

The default transport is UDP, and the default port is 514 (ie, syslog).

If you wish to ignore any certificate checks, in the case of TLS, you may supply `-SkipCertificateCheck`.

## Examples

### Send via UDP

The following example will send Request logs to some UDP endpoint.

```powershell
$method = New-PodeLogNetworkMethod -Server 'udp.example.com' -Port 8514
$method | Enable-PodeLogRequestType
```

### Send via TCP

The following example will send syslog formatted Error logs to some TCP endpoint.

```powershell
$method = New-PodeLogNetworkMethod -Server 'tcp.example.com' -Transport Tcp
$method | Enable-PodeLogErrorType -LogFormat Syslog
```

### Send via TLS

The following example will send JSON serialised Request logs to some TLS endpoint, and ignore any certificate checks.

```powershell
$method = New-PodeLogNetworkMethod `
    -Server 'tls.localhost.com' `
    -Transport Tls `
    -Port 8514 `
    -SkipCertificateCheck

$method | Enable-PodeLogRequestType -SerialiseFormat Json
```
