# Text

## Description

The `text` function writes a `string`, or a `Byte[]`, to the web response. It also allows you to pass the content type to set on the response, and whether or not to inform the browser to cache the response.

## Examples

### Example 1

The following example will write some plain text to the response stream:

```powershell
Server {
    listen *:8080 http

    route get '/message' {
        text 'I love you 3000'
    }
}
```

### Example 2

The following example will write a JSON value to the response stream:

```powershell
Server {
    listen *:8080 http

    route get '/user' {
        text '{"name": "rick"}' -ctype 'application/json'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Value | byte[]/string | true | The value to write to the current web response | null |
| ContentType | string | false | The content type of the value (ie: `application/json`) | text/plain |
| MaxAge | int | false | If caching, this is a value in seconds, that defines how long to cache the response | 3600 |
| Cache | switch | false | If passed, Pode will set caching headers to tell a browser to cache the response | false |
