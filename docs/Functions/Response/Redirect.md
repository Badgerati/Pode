# Redirect

## Description

The `redirect` function allows you to specify a URL to which the enduser should be redirected. You can either specify a raw or relative URL, or alter the current request URI's endpoint/port/protocol - such as redirecting from HTTP to HTTPS.

## Examples

### Example 1

The following example will redirect the enduser to the relative `/login` URL on the same endpoint:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route get '/logout' {
        redirect -url '/login'
    }
}
```

### Example 2

The following example will redirect the enduser to `https://google.com`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route get '/google' {
        redirect -url 'https://google.com'
    }
}
```

### Example 3

Assuming the current request URI is `http://localhost:8080`, then the following example will redirect the enduser to `http://localhost:8090`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route get '/' {
        redirect -port 8090
    }
}
```

### Example 4

Assuming the current request URI is `http://localhost:8080`, then the following example will redirect the enduser to `https://localhost:8080`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route get '/' {
        redirect -protocol https
    }
}
```

### Example 5

The following example will redirect every method and route to https:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route * * {
        redirect -protocol https
    }
}
```

### Example 6

The following example will redirect every method and route from the `127.0.0.2` endpoint to the localhost one - the port and protocol will remain untouched:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address 127.0.0.1:8080 -Protocol HTTP
    Add-PodeEndpoint -Address 127.0.0.2:8080 -Protocol HTTP

    route * * -endpoint 127.0.0.2 {
        redirect -endpoint 127.0.0.1
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Url | string | false | The raw, or relative, URL to which the enduser should be redirected | empty |
| Port | int | false | If no URL is supplied, then the redirect will be based on the current request URI's port. This parameter will override the current port of the request URI | 0 |
| Protocol | string | false | If no URL is supplied, then the redirect will be based on the current request URI's protocol. This parameter will override the current protocol of the request URI (Values: Empty, HTTP, HTTPS)  | empty |
| Endpoint | string | false | If no URL is supplied, then the redirect will be based on the current request URI's endpoint. This parameter will override the current endpoint of the request URI | empty |
| Moved | switch | false | If flagged, the redirect will be done as a `301 Moved` status, rather than a `302 Redirect` | false |
