
# Syslog

Pode supports logging items to a Syslog server using the inbuilt Syslog logging method. This method allows you to define various parameters such as the Syslog server address, port, transport protocol, and more. The logging method will convert any item to a string and send it to the configured Syslog server.

By default, Pode will use UDP as the transport protocol and RFC5424 as the Syslog protocol. You can customize these settings based on your Syslog server requirements.

## Examples

### Basic

The following example will setup the Syslog logging method for logging requests:

```powershell
New-PodeLoggingMethod -Syslog -Server '192.168.1.1' | Enable-PodeRequestLogging
```

### Custom Port

The following example will configure Syslog logging to use a custom port. The default port is 514, but you can specify a different port if needed:

```powershell
New-PodeLoggingMethod -Syslog -Server '192.168.1.1' -Port 1514 | Enable-PodeRequestLogging
```

### Secure Connection with TLS

The following example will configure Syslog logging to use TLS for a secure connection. You can also specify the TLS protocol version to use:

```powershell
New-PodeLoggingMethod -Syslog -Server '192.168.1.1' -Transport 'TLS' -TlsProtocol 'TLS1.2' | Enable-PodeRequestLogging
```

### Custom Syslog Protocol

The following example will configure Syslog logging to use a different Syslog protocol. The default protocol is RFC5424, but you can specify RFC3164 if needed:

```powershell
New-PodeLoggingMethod -Syslog -Server '192.168.1.1' -SyslogProtocol 'RFC3164' | Enable-PodeRequestLogging
```

### Skip Certificate Validation

The following example will configure Syslog logging to skip certificate validation for TLS connections. This is useful for testing purposes but not recommended for production environments:

```powershell
New-PodeLoggingMethod -Syslog -Server '192.168.1.1' -Transport 'TLS' -SkipCertificateCheck | Enable-PodeRequestLogging
```

### Custom Encoding

The following example will configure Syslog logging to use a different encoding for the Syslog messages. The default encoding is UTF8:

```powershell
New-PodeLoggingMethod -Syslog -Server '192.168.1.1' -Encoding 'ASCII' | Enable-PodeRequestLogging
```