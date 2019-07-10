# Status

## Description

The `status` function allows you to specify a status code, an optional description, and an optional exception that can be displayed on the error page - if the displaying of the error page is allowed.

If the status code supplied is 400+ then Pode will attempt to generate an error page, which you can override using custom [`error pages`](../../../Tutorials/Routes/ErrorPages), or disable by suppling the `-NoErrorPage` switch. If you supplied an exception to `status`, then the details of the exception can be used to populate the error pages with debugging info if enabled.

!!! tip
    You can also generate an error page of a specific content type, by supplying a valid mime-type to the `-ContentType` parameter. By default an HTML error page is used, but you could generate a JSON one. Further error page content type rules can be [found here](../../../Tutorials/Routes/ErrorPages).

## Examples

### Example 1

The following example sets the status code of the response to be 404:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/missing' {
        status 404
    }
}
```

### Example 2

The following example sets the status code and description of the response to be 500:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/error' {
        status 500 'Oh no! Something went wrong!'
    }
}
```

### Example 3

The following example will catch an exception, and set the status code to 500; the exception will also be used so it can be generated on any [error pages](../../../Tutorials/Routes/ErrorPages):

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/error' {
        try {
            # logic that fails
        }
        catch {
            status 500 -e $_
        }
    }
}
```

### Example 4

The following example will generate an error page using JSON:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/error' {
        try {
            # logic that fails
        }
        catch {
            status 500 -ctype 'application/json'
        }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Code | int | true | The status code to set on the web response | 0 |
| Description | string | false | The status description to set on the response | empty |
| Exception | exception | false | An exception that can be used to populate further details on the error page | null |
| ContentType | string | false | A specific content type to use and try and generate an error page using | empty |
| NoErrorPage | switch | false | If supplied, an error page will not be generated | false |