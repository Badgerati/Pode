# From v1.X to v2.X

This is a brief guide on migrating from Pode v1.X to Pode v2.X.

In Pode v2.X the Server got the biggest overhaul with the dropping of HttpListener.

## Server

If you were previously specifying `-Type Pode` on your [`Start-PodeServer`], then you no longer need to - all servers now default to using Pode new .NET Core socket listener.

### Endpoints

With the dropping of HttpListener, the old `-Certificate` is now the old `-CertificateFile` parameter. The `-RawCertificate` is now `-X509Certificate`.

`-CertificateThumbprint` has also been removed.
