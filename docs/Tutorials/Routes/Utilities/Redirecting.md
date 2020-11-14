# Redirecting

Sometimes you just want a Route to redirect the user else where, be it to another URL or to the same Route just a different port/protocol.

## Usage

When in a Route, to inform the client to redirect to a different endpoint you can use the [`Move-PodeResponseUrl`](../../../../Functions/Responses/Move-PodeResponseUrl) function.

Supplying `-Url` will redirect the user to that URL, or you can supply a relative path o the server for the user to be redirected to. The `-Port` and `-Protocol` can be used separately or together, but not with `-Url`. Using `-Port`/`-Protocol` will use the URI of the current web request to generate the redirect URL.

By default the redirecting will return a `302` response, but supplying `-Moved` will return a `301` response instead.

The following example will redirect the user to Google:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/redirect' -ScriptBlock {
        Move-PodeResponseUrl -Url 'https://google.com'
    }
}
```

The below example will redirect the user to the same host/server, but with a different protocol and port:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
    Add-PodeEndpoint -Address * -Port 8086 -Protocol HTTPS

    Add-PodeRoute -Method Get -Path '/redirect' -ScriptBlock {
        Move-PodeResponseUrl -Port 8086 -Protocol Https
    }
}
```

This final example will redirect every HTTP request, on every action and route, to HTTPS:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http -Name EndpointHttp
    Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -Name EndpointHttps

    Add-PodeRoute -Method * -Path * -EndpointName EndpointHttp -ScriptBlock {
        Move-PodeResponseUrl -Port 8443 -Protocol Https
    }
}
```
