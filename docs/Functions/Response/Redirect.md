# Redirect

## Description

The `redirect` function allows you to specify a URL to which to redirect the enduser. You can either specify a raw or relative URL, or alter the current request URI's endpoint/port/protocol - such as redirecting from HTTP to HTTPS.

## Examples

### Example 1

The following example will redirect the enduser to `https://google.com`:

```powershell
Server {
    listen *:8080 http

    route get '/google' {
        redirect -url 'https://google.com'
    }
}
```

### Example 2

Assuming the current request URI is `http://localhost:8080`, then the following example will redirect the enduser to `http://localhost:8090`:

```powershell
Server {
    listen *:8080 http

    route get '/' {
        redirect -port 8090
    }
}
```

### Example 3

Assuming the current request URI is `http://localhost:8080`, then the following example will redirect the enduser to `https://localhost:8080`:

```powershell
Server {
    listen *:8080 http

    route get '/' {
        redirect -protocol https
    }
}
```

### Example 4

The following example will redirect every method and route to https:

```powershell
Server {
    listen *:8080 http

    route * * {
        redirect -protocol https
    }
}
```

### Example 5

The following example will redirect every method and route from the `127.0.0.2` endpoint to the localhost one - the port and protocol will remain untouched:

```powershell
Server {
    listen 127.0.0.1:8080 http
    listen 127.0.0.2:8080 http

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
