# Error Pages and Status Codes

During web requests, Pode has some default status codes that can be returned throughout a request's lifecycle:

* `200` on success
* `400` when the query string or payload are invalid
* `403` when access to the server is unauthorised
* `404` if the route can't be found
* `429` if the rate limit is reached
* `500` for a complete failure

Status codes that are 400+ will be rendered as an error page, unless the `-NoErrorPage` switch is passed to the `Set-PodeResponseStatus` function. Pode itself has inbuilt error pages (HTML, JSON, and XML), but you can override these pages using custom error pages ([described below](#error-pages)).

If the error page being generated is dynamic, then the following `$data` is supplied and can be used the same as in views:

* The HTTP status code
* A description for the status
* The URL that threw the error
* The content-type of the error page being generated

They're also supplied details of any exception passed to the `Set-PodeResponseStatus` function, which can be rendered [if enabled](#exceptions) via the `pode.json` configuration file.

## Status Codes

The `Set-PodeResponseStatus` function allows you to set your own status code on the response, as well as a custom description. If the status code was triggered by an exception being thrown, then you can also supply this so it can be rendered on any [error pages](#error-pages).

The following example will set the status code of the response to be `418`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/teapot' {
        Set-PodeResponseStatus -Code 418
    }
}
```

Where as this example will set the status code to `500` with a custom description, and the exception that caused the error:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/eek' {
        try {
            # logic
        }
        catch {
            Set-PodeResponseStatus -Code 500 -Description 'oh no! something went wrong!' -Exception $_
        }
    }
}
```

## Error Pages

When a response is returned with a status code of 400+, then Pode will attempt to render these as styled error pages. By default, Pode has inbuilt error pages that will be used (these show the status code, description, the URL, and if enabled the exception message/stacktrace).

The inbuilt error pages are of types HTML, JSON, and XML. By default Pode will always attempt to use the HTML error pages however, if you set, say [strict content typing](#strict-typing), then Pode will also attempt to use the JSON/XML error pages if the request's content type header is set appropriately.

### Custom

In Pode you can use custom error pages, so you can stylise your own rather than using the inbuilt ones that come with Pode.

To use your own custom error pages you have to place them within an `/errors` directory, at the root of your server (similar to `/views` and `/public`).

These pages should be called the name of a status code, the content type of the page, and an optional view engine extension:

```plain
<code>.<type>[.<engine>]    # ie: 400.html, or 404.json.pode
```

Or, you can use a default error page which will be used for any status codes that doesn't have a specific page define:

```plain
default.<type>[.<engine>]   # ie: default.html, or default.json.pode
```

An example file structure for `/errors` is as follows:

```plain
/errors
    default.html
    404.html
    404.json
    500.html.pode
```

By default Pode will always generate error pages as HTML, unless you enable strict content typing or routes patterns ([detailed later](#content-types)).

!!! important
    To use error pages with a view engine (such as `.pode`), you need to set the [`view engine`](../../../Functions/Core/Engine) in your server.

#### Dynamic Data

If you're using a dynamic view engine to render the error pages, then like [`views`](../../ViewEngines/Pode), there will be a `$data` variable that you can use within the error page file. The `$data` variable will have the following structure:

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
    'ContentType' = [string];
}
```

!!! note
    If you've disabled the showing of exceptions, then the `Exception` property will be `$null`.

### Exceptions

Above you'll see that the exception supplied to `status` will also be supplied to any dynamic error pages. By default this is disabled, but you can enable the viewing of exceptions on the error page by using the `pode.json` configuration file:

```json
{
    "web": {
        "errorPages": {
            "showExceptions": true
        }
    }
}
```

Once set to `true`, any available exception details for status codes will be available to error pages - a useful setting to have in a [`pode.dev.json`](../../Configuration#environments) file.

### Content Types

Using the `pode.json` configuration file, you can define which file content types to attempt when generating error pages for routes. You can either:

* Define a [default](#default) content type that will apply to every route, or
* Enable [strict](#strict-typing) content typing to use a route/request's content type, or
* Define [patterns](#route-patterns) to match multiple route paths to set content types on mass

#### Default

To define a default content type for everything, you can use the following configuration. With this, any error thrown in any route will attempt to render an HTML error page:

```json
{
    "web": {
        "errorPages": {
            "default": "text/html"
        }
    }
}
```

#### Route Patterns

You can define patterns to match multiple route paths, and any route that matches, when an error page is being generated, will attempt to generate an error page for the content type set.

For example, the following configuration in your `pode.json` file would bind all `/api` routes to `application/json` error pages, and then all `/status` routes to `text/xml` error pages:

```json
{
    "web": {
        "errorPages": {
            "routes": {
                "/api/*": "application/json",
                "/status/*": "text/xml"
            }
        }
    }
}
```

#### Strict Typing

You can enable strict content typing in the `pode.json` file. When enabled, Pode will attempt to generate an error page that matches the route/request's content type.

For example: if the request's `Content-Type` header is set to `application/json` (or you're using [route content types](../ContentTypes)), and you have strict content typing enabled, then Pode will attempt to use a JSON error page.

To enable strict content typing, you can use the following:

```json
{
    "web": {
        "errorPages": {
            "strictContentTyping": true
        }
    }
}
```

### Type Precedence

The content type that will used, when attempting to generate an error page, will be determined by the following order:

1. A content type is supplied directly to the `status` function (via `-ContentType`).
2. An error page content type is supplied directly to the `route` function (via `-ErrorType`).
3. The route matches a pattern defined in the configuration file.
4. Strict content typing is enabled in the configuration file.
5. A default error page content type is defined in the configuration file.
6. use the default of HTML.

### File Precedence

The error page file that will used will be determined by the following order. This order will be done for each step that matches in the above [type precedence](#type-precedence):

1. `<code>.<type>`              - ie: `404.json`
2. `<code>.<type>.<engine>`     - ie: `404.json.pode`
3. `<code>.<engine>`            - ie: `404.pode`
4. `default.<type>`             - ie: `default.json`
5. `default.<type>.<engine>`    - ie: `default.json.pode`
6. `default.<engine>`           - ie: `default.pode`
7. Inbuilt pages

## Example Page

The following is a simple `default.html.pode` dynamic error page example, which will render the status code and description - and if available, the exception message and stacktrace:

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