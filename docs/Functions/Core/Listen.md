# Listen

## Description

The `listen` function allows you to specify the IP/Hostname, Port and Protocol for endpoints that your [`server`](../Server) will listen on. If the protocol is `https` then you can also specify a certificate name or thumbprint to bind against the IP/Hostname - even having Pode create a self-signed certificate for you.

The `listen` function will check for administrator privileges on Windows, unless the endpoint you're attempting to listen on is a localhost one.

!!! note
    You can specify multiple endpoints to listen on for HTTP/HTTPS however, you can only supply a single endpoint for SMTP/TCP.

## Examples

### Example 1

The following example will listen on every IP over port 8080 for HTTP requests:

```powershell
server {
    listen *:8080 http
}
```

### Example 2

The following example will listen on localhost over port 25 for SMTP requests (this will not require administrator privileges):

```powershell
server {
    listen 127.0.0.1:25 smtp
}
```

### Example 3

The following example will listen on a specific IP address over port 8443 for HTTPS requests; it will also inform Pode to create and bind a self-signed certificate to the IP:Port:

```powershell
server {
    listen 10.10.1.4:8443 https -cert self
}
```

### Example 4

The following example will listen on a specific host name over port 8080 for HTTP requests:

```powershell
server {
    listen pode.foo.com:8080 http
}
```

### Example 5

The following example will listen on a wildcard endpoint over port 8443 for HTTPS requests, binding a certificate to the endpoint using a thumbprint:

```powershell
server {
    listen *.foo.com:8443 https -cthumb '2A9467F7D3940243D6C07DE61E7FCCE292'
}
```

### Example 6

The following example will listen on multiple endpoints for HTTP (Note, you can specify a combination of HTTP/HTTPS endpoints):

```powershell
server {
    listen pode.foo.com:8080 http
    listen pode.bar.com:8080 http
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| IPPort | string | true | The IP/Hostname:Port combination for an endpoint that the server should listen on | null |
| Type | string | true | The protocol of the endpoint the server should use (Values: HTTP, HTTPS, SMTP, TCP) | null |
| Certificate | string | false | The certificate name to find and bind to an HTTPS endpoint. If the certificate name passed is `self` then Pode will create a self-signed certificate. If the certificate name is `*.example.com` then it must be installed to `Cert:/LocalMachine/My` | empty |
| Thumbprint | string | false | The certificate thumbprint to bind to an HTTPS endpoint. If both a certificate name and thumbprint are supplied, then the thumbprint takes priority | null |
| Name | string | false | A unique name for this endpoint, which can be used on the [`route`](../Route) and [`gui`](../Gui) functions | empty |
| Force | switch | false | If supplied, will force the `listen` function to not run the administrator check | false |
