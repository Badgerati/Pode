# From v1.X to v2.X

This is a brief guide on migrating from Pode v1.X to Pode v2.X.

In Pode v2.X the Server got the biggest overhaul with the dropping of HttpListener.

## Server

If you were previously specifying `-Type Pode` on your [`Start-PodeServer`](../../../Functions/Core/Start-PodeServer), then you no longer need to - all servers now default to using Pode new .NET Core socket listener.

### Endpoints

With the dropping of HttpListener, the `-Certificate` parameter is now the old `-CertificateFile` parameter. The `-RawCertificate` parameter has been ranamed, and it now called `-X509Certificate`.

The `-CertificateThumbprint` parameter remains the same, and only works on Windows.
The `-Certificate` parameter is now the `-CertificateName` parameter, and also only works on Windows.

### Configuration

Settings that use to be under `Server > Pode` are now just under `Server`. For example, SSL protocols have moved from:

```powershell
@{
    Server = @{
        Pode=  @{
            Ssl= @{
                Protocols = @('TLS', 'TLS11', 'TLS12')
            }
        }
    }
}
```

to:

```powershell
@{
    Server = @{
        Ssl= @{
            Protocols = @('TLS', 'TLS11', 'TLS12')
        }
    }
}
```
