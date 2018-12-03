# Listen

## Description

The `listen` function allows you to specify the IP/Host, Port and Protocol that your `Server` will listen on. If the protocol is `https` then you can also specify a certificate to bind, even having Pode create a self-signed certificate for you.

## Examples

### Example 1

The following example will listen on every IP over port 8080 for HTTP requests:

```powershell
Server {
    listen *:8080 http
}
```

!!! info
    This will setup a web server and will require a `route` to be configured

### Example 2

The following example will listen on localhost over port 25 for SMTP requests:

```powershell
Server {
    listen 127.0.0.1:25 smtp
}
```

!!! info
    This will setup an SMTP server and will require a `handler` to be configured

### Example 3

The following example will listen on a specific IP address over port 8443 for HTTPS requests; it will also inform Pode to create and bind a self-signed certificate to the IP:Port:

```powershell
Server {
    listen 10.10.1.4:8443 https -cert self
}
```

### Example 4

The following example will listen on a specific host name over port 8080 for HTTP requests:

```powershell
Server {
    listen foo.com:8080 http
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| IPPort | string | true | The IP/Host:Port combination that the server should listen on | null |
| Type | string | true | The type of server: HTTP, HTTPS, SMTP, TCP | null |
| Cert | string | false | The certificate to bind to the IP:Port. If the certificate is `self` then Pode will create a self-signed certificate. If the certificate is `*.example.com` then it must be installed to `Cert:/LocalMachine/My` | null |
