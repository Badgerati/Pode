# Certificates

Pode has the ability to generate and bind self-signed certificates (for dev/testing), as well as the ability to bind existing certificates for HTTPS.

There are 6 ways to setup HTTPS on [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint):

1. Supplying just the `-Certificate`, such as a `.cer`.
2. Supplying both the `-Certificate` and `-CertificatePassword`, such as for `.pfx`.
3. Supplying a `-CertificateThumbprint` for a certificate installed at `Cert:\CurrentUser\My` on Windows.
4. Supplying a `-CertificateName` for a certificate installed at `Cert:\CurrentUser\My` on Windows.
5. Supplying `-X509Certificate` of type `X509Certificate`.
6. Supplying the `-SelfSigned` switch, to generate a quick self-signed `X509Certificate`.

Note: for 3. and 4. you can change the certificate store used by supplying `-CertificateStoreName` and/or `-CertificateStoreLocation`.

## Usage

### File

To bind a certificate file, you use the `-Certificate` parameter, along with the `-CertificatePassword` parameter for `.pfx` certificates. The following example supplies some `.pfx` to enable HTTPS support:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Https -Certificate './cert.pfx' -CertificatePassword 'Hunter2'
}
```

### Thumbprint

On Windows only, you can use a certificate that is installed at `Cert:\CurrentUser\My` using its thumbprint:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Https -CertificateThumbprint '2A623A8DC46ED42A13B27DD045BFC91FDDAEB957'
}
```

Note: You can change the certificate store used by supplying `-CertificateStoreName` and/or `-CertificateStoreLocation`.

### Name

On Windows only, you can use a certificate that is installed at `Cert:\CurrentUser\My` using its subject name:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Https -CertificateName '*.example.com'
}
```

Note: You can change the certificate store used by supplying `-CertificateStoreName` and/or `-CertificateStoreLocation`.

### X509

The following will instead create an X509Certificate, and pass that to the endpoint instead:

```powershell
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new('./certs/example.cer')
Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -X509Certificate $cert
```

### Self-Signed

If you are developing/testing a site on HTTPS then Pode can generate and bind quick self-signed certificates. To do this you can pass the `-SelfSigned` switch:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -SelfSigned
}
```

## SSL Protocols

The default allowed SSL protocols are SSL3 and TLS1.2, but you can change these to any of: SSL2, SSL3, TLS, TLS11, TLS12, TLS13. This is specified in your `server.psd1` configuration file:

```powershell
@{
    Server = @{
        Ssl= @{
            Protocols = @('TLS', 'TLS11', 'TLS12')
        }
    }
}
```
