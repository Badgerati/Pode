# Listen

## Description

The `listen` function allows you to specify the IP, Port and Protocol that your `Server` will listen on. If the protocol is `https` then you can also specify a certificate to bind, even having Pode create a self-signed certificate for you.

## Examples

1. The following example will listen on every IP over port 8080 for HTTP requests:

    > This will setup an web server and will require `route`s to be configured

    ```powershell
    Server {
        listen *:8080 http
    }
    ```

2. The following example will listen on localhost over port 25 for SMTP requests:

    > This will setup an SMTP server and will require a `handler` to be configured

    ```powershell
    Server {
        listen 127.0.0.1:25 smtp
    }
    ```

3. The following example will listen on a specific IP address over port 8443 for HTTPS requests; it will also inform Pode to create and bind a self-signed certifcate to the IP:Port:

    > This will setup an web server and will require `route`s to be configured

    ```powershell
    Server {
        listen 10.10.1.4:8443 https -cert self
    }
    ```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| IPPort | string | true | The IP:Port combination that the server should listen on | null |
| Type | string | true | The type of server: HTTP, HTTPS, SMTP, TCP | null |
| Cert | string | false | The certificate to bind to the IP:Port. If the certificate is `self` then Pode will create a self-signed certifcate. If the certifcate is `*.example.com` then it must be installed to `Cert:/LocalMachine/My` | null |
