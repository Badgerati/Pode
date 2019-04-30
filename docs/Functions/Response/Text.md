# Text

## Description

The `text` function writes a `string`, or a `Byte[]`, to the web response. It also allows you to pass the content type to set on the response, and whether or not to inform the browser to cache the response.

## Examples

### Example 1

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
| ContentType | string | false | The content type of the value (ie: `application/json`) | null |
| Cache | switch | false | If passed, Pode will set caching headers to tell a browser to cache the response | false |
