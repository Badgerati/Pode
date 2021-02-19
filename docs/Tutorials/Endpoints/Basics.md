# Basics

Endpoints in Pode are used to bind your server to specific IPs, Hostnames and ports, over specific protocols (such as HTTP or HTTPS). Endpoints can have unique names, so you can bind Routes to certain endpoints only.

## Usage

To add new endpoints to your server, you can use [`Add-PodeEndpoint`](../../../Functions/Core/Add-PodeEndpoint). A quick and simple example is the following, which will bind your server to `http://localhost:8080`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http
}
```

The `-Address` can be local or private IP address. The `-Port` is any valid port number, and the `-Protocol` defines which protocol the endpoint will use: HTTP, HTTPS, SMTP, TCP, WS and WSS.

You can also supply an optional unique `-Name` to your endpoint. This name will allow you to bind routes to certain endpoints; so if you have endpoint A and B, and you bind some route to endpoint A, then it won't be accessible over endpoint B.

## Hostnames

You can specify a `-Hostname` for an endpoint, in doing so you can only access routes via the specified hostname. Using a hostname will allow you to have multiple endpoints all using the same IP/Port, but with different hostnames.

The following will create an endpoint with hostname `example.pode.com`, bound to `127.0.0.1:8080`:

```powershell
Add-PodeEndpoint -Hostname example.pode.com -Port 8080 -Protocol Http
```

To bind a hostname to a specific IP you can use `-Address`:

```powershell
Add-PodeEndpoint -Address 127.0.0.2 -Hostname example.pode.com -Port 8080 -Protocol Http
```

or, lookup the hostnames IP from host file or DNS:

```powershell
Add-PodeEndpoint -Hostname example.pode.com -Port 8080 -Protocol Http -LookupHostname
```

Finally, you can bind multiple hostnames to one IP/Port:

```powershell
Add-PodeEndpoint -Address 127.0.0.3 -Hostname one.pode.com -Port 8080 -Protocol Http
Add-PodeEndpoint -Address 127.0.0.3 -Hostname two.pode.com -Port 8080 -Protocol Http
```

## Certificates

If you add an HTTPS or WSS endpoint, then you'll be required to also supply certificate details. To configure a certificate you can use one of the following parameters:

| Name | Description |
| ---- | ----------- |
| Certificate | The path to a `.pfx` or `.cer` certificate |
| CertificatePassword | The password for the above `.pfx` certificate |
| CertificateThumbprint | The thumbprint of a certificate to find (Windows only) |
| CertificateName | The subject name of a certificate to find (Windows only) |
| CertificateStoreName | The name of the certificate store (Default: My) (Windows only) |
| CertificateStoreLocation | The location of the certificate store (Default: CurrentUser) (Windows only) |
| X509Certificate | A raw X509Certificate object |
| SelfSigned | If supplied, Pode will automatically generate a self-signed certificate as an X509Certificate object |

The below example will create an endpoint using a `.pfx` certificate:

```powershell
Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -Certificate './certs/example.pfx' -CertificatePassword 'hunter2'
```

Whereas the following will instead create an X509Certificate, and pass that to the endpoint instead:

```powershell
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new('./certs/example.cer')
Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -X509Certificate $cert
```

The below example will create a local self-signed HTTPS endpoint:

```powershell
Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -SelfSigned
```

## Endpoint Names

You can give endpoints unique names by supplying the `-EndpointName` parameter. This name can then be passed to [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute) or [`Add-PodeStaticRoute`](../../../Functions/Routes/Add-PodeStaticRoute) to bind these routes to that endpoint only.

For example:

```powershell
Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -EndpointName Example

Add-PodeRoute -Method Get -Path '/about' -EndpointName Example -ScriptBlock {
    # ...
}
```

## Getting Endpoints

The [`Get-PodeEndpoint`](../../../Functions/Core/Get-PodeEndpoint) helper function will allow you to retrieve a list of endpoints configured within Pode. You can use it to retrieve all of the endpoints, or supply filters to retrieve specific endpoints.

To retrieve all of the endpoints, you can call the function will no parameters. To filter, here are some examples:

```powershell
# all endpoints using port 80
Get-PodeEndpoint -Port 80

# all endpoints using HTTP
Get-PodeEndpoint -Protocol Http

# retrieve specific named endpoints
Get-PodeEndpoint -Name Admin, User
```

## Endpoint Object

!!! warning
    Be careful if you choose to edit these objects, as they will affect the server.

The following is the structure of the Endpoint object internally, as well as the object that is returned from [`Get-PodeEndpoint`](../../../Functions/Core/Get-PodeEndpoint):

| Name | Type | Description |
| ---- | ---- | ----------- |
| Name | string | The name of the Endpoint, if a name was supplied |
| Description | string | A description of the Endpoint, usually used for OpenAPI |
| Address | IPAddress | The IP address that will be used for the Endpoint |
| RawAddress | string | The address/host and port of the Endpoint |
| Port | int | The port the Endpoint will use |
| IsIPAddress | bool | Whether or not the listener will bind using Hostname or IP address |
| Hostname | string | The hostname of the Endpoint |
| FriendlyName | string | A user friendly hostname to use when generating internal URLs |
| Url | string | The full base URL of the Endpoint |
| Ssl | bool | Whether or not this Endpoint support support SSL |
| Protocol | string | The protocol of the Endpoint |
| Certificate | hashtable | Details about the certificate that will be used for SSL Endpoints |
