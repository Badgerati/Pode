# Error Pages and Status Codes

During web requests, Pode has some default status codes that can be returned:

* `200` on success
* `400` when the query string or payload are invalid
* `403` when access to the server is unauthorised
* `404` if the route can't be found
* `429` if the rate limit is reached
* `500` for a complete failure

When viewed through a browser, status codes that are 400+ will be rendered as an error page. Pode itself has an inbuilt error page, but you can override this page using custom error pages ([described below](#error-pages)). These pages are supplied the status code, description and URL that triggered the error. They're also supplied details of any exception supplied to the `status` function, which can be rendered [if enabled](#exceptions) via the `pode.json` configuration file.

## Status Codes

The [`status`](../../../Functions/Response/Status) function allows you to set your own status code on the response, as well as a custom description. If the status code was triggered by an exception occurring, then you can also supply this to `status` so it can be rendered on the [error page](#error-pages).

The make-up of the `status` function is as follows:

```powershell
status <int> [-description <string>] [-exception <exception>]

# or shorthand
status <int> [-d <string>] [-e <exception>]
```

The following example will set the status code of the response to be `418`:

```powershell
Server {
    listen *:8080 http

    route get '/teapot' {
        status 418
    }
}
```

Where as this example will return a `500` with a custom description, and the exception that caused the error:

```powershell
Server {
    listen *:8080 http

    route get '/eek' {
        try {
            # logic
        }
        catch {
            status 500 -d 'oh no! something went wrong!' -e $_
        }
    }
}
```

## Error Pages

When a response is returned with a status code of 400+, then Pode will render these as styled error pages. By default, Pode has an inbuilt error page that will be used (this shows the status code, description, the URL and if enabled the exception message/stacktrace).

### Custom

However, Pode also supports custom error pages, so you can stylise your own!

To use your own custom error pages you place the pages within an `/errors` directory at the root of your server (similar to `/views` and `/public`). These pages should be called the name of the status code, plus a relevant extension: `<code>.<ext>`. Or, you can use `default.<ext>` as a catch-all for all status codes:

```plain
/errors
    default.html
    404.html
    500.html
```

!!! Important
    The extension used will determine the view engine that will be used to render the error pages, such as `html` or `pode`.

If you're using a dynamic view engine to render the error pages, then like `views`, there will be a `$data` variable that you can use within the view file. The `$data` variable will have the following structure:

```powershell
@{
    'Url' = [string];
    'Status' = @{
        'Code' = [int];
        'Description' = [string];
    };
    'Exception' = @{
        'Message' = [string];
        'StackTrace' = [string];
        'Line' = [string];
        'Category' = [string];
    };
}
```

!!! Note
    If you've disabled the showing of exceptions, then the `Exception` value will be `$null`

### Exceptions

Above you'll see that the exception supplied to `status` will also be supplied to any dynamic error pages. By default, this is disabled, but you can enable the viewing of exceptions on the error page by using the `pode.json` configuration file:

```json
{
    "web": {
        "errorPages": {
            "showExceptions": true
        }
    }
}
```

Once set to `true`, any available exception details for status codes will be available to error pages.

### Example

The following is a simple example `default.pode` dynamic error page, which will render the status code and description - and if available, the exception message and stacktrace:

```html
<html>
    <head>
        <title>$($data.status.code) Error</title>
    </head>
    <body>
        <h1>$($data.status.code) Error</h1>
        <p>Description: $($data.status.description)</p>

        $(if ($data.exception) {
            "<pre>
                $($data.exception.message)
                $($data.exception.stacktrace)
            </pre>"
        })
    </body>
</html>
```