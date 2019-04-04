# Certificates

!!! warning
    Binding existing, and generating self-signed certificates is only supported on *Windows*.

Pode has the ability to generate and bind self-signed certificates (for dev/testing), as well as the ability to bind existing - already installed - certificates for HTTPS. If Pode detects that the `IP:Port` or `Hostname:Port` binding already has a certificate bound, then Pode will re-use that certificate and will not create a new self-signed certificate, or bind a new certificate.

## Self-Signed

If you are developing/testing a site on HTTPS then Pode can generate and bind quick self-signed certificates. To do this you can pass the value `self` to the `-cert` parameter of the [`listen`](../../Functions/Core/Listen):

```powershell
Server {
    # for an IP:
    listen *:8443 https -cert self

    # for a hostname:
    listen foo.bar.com:8443 https -cert self
}
```

## Pre-Installed

To bind an already installed signed certificate, the certificate *must* be installed to `Cert:/LocalMachine/My`. Then you can pass the certificate name/domain to `-cert` parameter; an example for `*.example.com` is as follows:

```powershell
Server {
    # for an IP:
    listen *:8443 https -cert '*.example.com'

    # for a hostname
    listen foo.example.com:8443 https -cert '*.example.com'
}
```

## Clean-Up

If you want to use a new certificate on a binding that already has one, then you'll have to clean-up the binding first. Calling either:

* `netsh http delete sslcert ipport=<ip>:<port>`
* `netsh http delete sslcert hostnameport=<hostname>:<port>`

will remove the binding.