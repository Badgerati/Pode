# File

## Description

The `file` function writes the contents of a file to the web response. For dynamic files that have the same extension as the view engine, you can also supply data that can be passed to them. You can also set whether or not to inform the browser to cache the file.

The content type for the response, by default, is determined by the file's extension. However, you can also pass a content type to set on the response - overriding the default behaviour.

## Examples

### Example 1

The following example will write an XML file to the response stream:

```powershell
Server {
    listen *:8080 http

    route get '/data' {
        file './path/file.xml'
    }
}
```

### Example 2

The following example will write a dynamic text file to the response stream, supplying data needed to generate the file:

```powershell
Server {
    listen *:8080 http

    route get '/data' {
        file './path/file.txt.pode' -d @{ 'date' = [datetime]::UtcNow }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Path | string | true | A path to a file to write to the current web response | null |
| Data | hashtable | false | A hashtable of dynamic data that will be supplied to `.pode`, and other third-party template engine, files | `@{}` |
| ContentType | string | false | The content type of the file (ie: `application/json`) | null |
| Cache | switch | false | If passed, Pode will set caching headers to tell a browser to cache the file | false |
