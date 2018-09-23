# Html

## Description

The `html` function reads in an HTML file and then writes to content the web response. You can also supply raw HTML data as the value to write.

## Examples

### Example 1

The following example will write raw HTML data to a web response within a `route`:

```powershell
Server {
    listen *:8080 http

    route get '/info' {
        html '<html><head><title>Example</title></head><body>Hello, world!</body></html>'
    }
}
```

### Example 2

The following example will read in a file, and write the contents as HTML to a web response within a `route`:

```powershell
Server {
    listen *:8080 http

    route get '/data' {
        html -file './files/data.html'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Value | string | true | The value should be a string, of either a path or raw HTML. It will be attached to the web response | null |
| File | switch | false | If passed, the above value should be a string that's a path to an HTML file | false |
