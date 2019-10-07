# Certificates

!!! warning
    Binding existing, and generating self-signed certificates is only supported on *Windows*.
    For cross-platform HTTPS support [see here](../PodeServer).

Pode has the ability to generate and bind self-signed certificates (for dev/testing), as well as the ability to bind existing - already installed - certificates for HTTPS on Windows, using the default Server type. If Pode detects that the `IP:Port` or `Hostname:Port` binding already has a certificate bound, then Pode will re-use that certificate and will not create a new self-signed certificate, or bind a new certificate.

## Self-Signed

If you are developing/testing a site on HTTPS then Pode can generate and bind quick self-signed certificates. To do this you can pass the `-SelfSigned` swicth to the  [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) functions:

```powershell
Start-PodeServer {
    # for an IP:
    Add-PodeEndpoint -Address * -Port 8443 -Protocol HTTPS -SelfSigned

    # for a hostname:
    Add-PodeEndpoint -Address foo.bar.com -Port 8443 -Protocol HTTPS -SelfSigned
}
```

## Pre-Installed

To bind an already installed signed certificate, the certificate *must* be installed to `Cert:/LocalMachine/My`. Then you can pass the certificate name/domain to `-Certificate` parameter; an example for `*.example.com` is as follows:

```powershell
Start-PodeServer {
    # for an IP:
    Add-PodeEndpoint -Address * -Port 8443 -Protocol HTTPS -Certificate '*.example.com'

    # for a hostname
    Add-PodeEndpoint -Address foo.example.com -Port 8443 -Protocol HTTPS -Certificate '*.example.com'
}
```

!!! tip
    You could also supply the certificate's thumbprint instead, to the `-CertificateThumbprint` parameter.

## Clean-Up

If you want to use a new certificate on a binding that already has one, then you'll have to clean-up the binding first. Calling either:

* `netsh http delete sslcert ipport=<ip>:<port>`
* `netsh http delete sslcert hostnameport=<hostname>:<port>`

will remove the binding.
