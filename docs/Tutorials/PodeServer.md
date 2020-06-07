# Pode Server

!!! notice
    The Pode server type uses sockets to allow cross-platform support for HTTPS. This server type is also **experimental**.

The Pode server type, as specified above, is an experimental type that uses sockets to allow for cross-platform support of HTTPS (it does also support normal HTTP!).

To start using this server type, there isn't very must you need to do. All that's really required is to set the `-Type` on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer), and to supply a certificate on [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) for HTTPS (detailed below).

## Server Type

To start using the Pode server type, you just need to set the `-Type` on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer). The following example is a simple HTTP server that will use this server type:

```powershell
Start-PodeServer {

    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Kenobi = 'Hello, there' }
    }
}
```

## HTTPS

To enable your server to use HTTPS, as well as setting the `-Type` like above, you will also need to supply a certificate on [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint). By default, on SSL3 and TLS1.2 connections are allowed - you can change this via the configuration described below.

There are 3 ways to do this:

> The `-Certificate` and `-CertificateThumbprint` parameters are not supported.
> On *nix platforms, only the latter two options are supported.

1. Supplying just the `-CertificateFile`, such as a `.cer`.
2. Supplying both the `-CertificateFile` and `-CertificatePassword`, such as for `.pfx`.
3. Supply a `-RawCertificate` of type `X509Certificate`.

The following example is like above, but this time we'll supply some `.pfx` to enable HTTPS support:

```powershell
Start-PodeServer {

    Add-PodeEndpoint -Address * -Port 8090 -Protocol Https -CertificateFile './cert.pfx' -CertificatePassword 'Hunter2'

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Kenobi = 'Hello, there' }
    }
}
```

### Issues

For HTTPS, there are a few issues you may run into. To resolve them, you can use the below:

* On Windows, you may need to install the certificate into your Trusted Root on the Local Machine (mostly for self-signed certificates).
* You may be required to run the following, to force TLS1.2, before making web requests:

```powershell
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
```

* On *nix platforms, for self-signed certificates, you may need to use `-SkipCertificateCheck` on `Invoke-WebRequest` and `Invoke-RestMethod`

## Configuration

There are currently two settings you can define via your `server.psd1` configuration file. Both of these are done within the `Server` section.

### Receive Timeout

The default receive timeout is 100ms, but you can change this to any value above 0:

```powershell
@{
    Server = @{
        ReceiveTimeout = 500
    }
}
```

### SSL Protocols

The default allowed SSL protocols are SSL3 and TLS1.2, but you can change these to any of: SSL2, SSL3, TLS, TLS11, TLS12, TLS13:

```powershell
@{
    Server = @{
        Ssl= @{
            Protocols = @('TLS', 'TLS11', 'TLS12')
        }
    }
}
```

## Any Problems?

As quite obviously stated, this is experimental. If there are any issues please feel free to [raise them here](https://github.com/Badgerati/Pode/issues).
