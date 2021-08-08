# Certificates

Pode has the ability to generate and bind self-signed certificates (for dev/testing), as well as the ability to bind existing certificates for HTTPS.

There are 8 ways to setup HTTPS on [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint):

1. Supplying just the `-Certificate`, which is the path to files such as a `.cer` or `.pem` file.
2. Supplying both the `-Certificate` and `-CertificatePassword`, which is the path to a `.pfx` file and its password.
3. Supplying both the `-Certificate` and `-CertificateKey`, which is the paths to certificate/key PEM file pairs.
4. Supplying all of `-Certificate`, `-CertificateKey`, and `-CertificatePassword`, which is the paths to certificate/key PEM file pairs and the password for an encrypted key.
5. Supplying a `-CertificateThumbprint` for a certificate installed at `Cert:\CurrentUser\My` on Windows.
6. Supplying a `-CertificateName` for a certificate installed at `Cert:\CurrentUser\My` on Windows.
7. Supplying `-X509Certificate` of type `X509Certificate`.
8. Supplying the `-SelfSigned` switch, to generate a quick self-signed `X509Certificate`.

Note: for 5. and 6. you can change the certificate store used by supplying `-CertificateStoreName` and/or `-CertificateStoreLocation`.

## Usage

### File

#### PFX

To bind a certificate PFX file, you use the `-Certificate` parameter, along with the `-CertificatePassword` parameter for the PFX certificate. The following example supplies the path to some `.pfx` to enable HTTPS support:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Https -Certificate './cert.pfx' -CertificatePassword 'Hunter2'
}
```

#### PEM

Pode has support for binding certificate/key PEM file pairs, on PowerShell 7+ this works out-of-the-box. However, for PowerShell 5/6 you are required to have OpenSSL installed.

To bind a certificate/key PEM file pairs generated via LetsEncrypt or OpenSSL, you supply their paths to the `-Certificate` and `-CertificateKey` parameters.

For example, if you generate the certificate/key using the following:
```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes
```

Then your endpoint would be created as:
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Https -Certificate './cert.pem' -CertificateKey './key.pem'
}
```

However, if you generate the certificate/key and encrypt the key with a passphrase:
```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365
```

Then the endpoint is created as follows:
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Https -Certificate './cert.pem' -CertificateKey './key.pem' -CertificatePassword '<passphrase>'
}
```

Depending on how you generated the certificate, especially if you used the above openssl, you might have to install the certificate to your local certificate store for it to be trusted. If you're using `Invoke-WebRequest` or `Invoke-RestMethod` on PowerShell 6+ you can supply the `-SkipCertificateCheck` switch.

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

You might get a warning in the browser about the certificate, and this is fine. If you're using `Invoke-WebRequest` or `Invoke-RestMethod` on PowerShell 6+ you can supply the `-SkipCertificateCheck` switch.

## SSL Protocols

The default allowed SSL protocols are SSL3 and TLS1.2 (or just TLS1.2 on MacOS), but you can change these to any of: SSL2, SSL3, TLS, TLS11, TLS12, TLS13. This is specified in your `server.psd1` configuration file:

```powershell
@{
    Server = @{
        Ssl= @{
            Protocols = @('TLS', 'TLS11', 'TLS12')
        }
    }
}
```
