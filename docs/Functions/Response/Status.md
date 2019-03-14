# Status

## Description

The `status` function allows you to specify a status code, an optional description, and an optional exception that can be displayed on the error page.

If the status code supplied is 400+ then Pode will render an error page, which you can override using custom [`error pages`](../../../Tutorials/Routes/ErrorPages). If you supplied an exception to `status`, then the details of the exception can be used to populate the error pages with debugging info if enabled.

## Examples

### Example 1

The following example sets the status code of the response to be 404:

```powershell
Server {
    listen *:8080 http

    route get '/missing' {
        status 404
    }
}
```

### Example 2

The following example sets the status code and description of the response to be 500:

```powershell
Server {
    listen *:8080 http

    route get '/error' {
        status 500 'Oh no! Something went wrong!'
    }
}
```

### Example 3

The following example will catch an exception, and set the status code to 500; the exception will also be supplied so it can be rendered on any [error pages](../../../Tutorials/Routes/ErrorPages):

```powershell
Server {
    listen *:8080 http

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

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Code | int | true | The status code to set on the web response | 0 |
| Description | string | false | The status description to set on the response | empty |
| Exception | exception | false | An exception that can be used to populate further details on the error page | null |