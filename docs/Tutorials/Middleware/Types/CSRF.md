# CSRF

Pode has inbuilt support for CSRF validation using tokens on web requests. The secret used to generate/validate the tokens can be stored in either sessions or signed cookies. When configured, the middleware will check for, and validate, a CSRF token the on a web request for valid routes - with support to ignore specific HTTP methods. If a route fails CSRF validation, then Pode will return a 403 status code.

## Usage

In Pode you can either validate CSRF using global middleware, or you can assign local Route middleware for specifc routes instead. The tokens needed for validation can be generated in a route and returned in the response as a hidden input element, or other payload options.

By default Pode's CSRF middleware will validate on every route, except for GET, HEAD, OPTIONS, and TRACE routes. The random secret used to generate tokens can be stored using either sessions or cookies.

During the verification process, the middleware will attempt to extract the CSRF token from either of the query string, payload or header. In all scenarios the name of the of the token *should always* be `pode.csrf`.

## Middleware

To setup global CSRF middleware in Pode you can use the [`Enable-PodeCsrfMiddleware`](../../../../Functions/Middleware/Enable-PodeCsrfMiddleware) function. This will let you configure how CSRF works, as well as add the middleware to Pode for you.

You can use the `-IgnoreMethods` parameter to supply a custom array of HTTP methods that validation should skip. If you supply this an empty array (`-IgnoreMethods @()`) then CSRF will run on all routes - even GET, HEAD, OPTIONS, and TRACE.

The secret used to generate a token is, by default, stored using sessions (so you'll need session middleware enabled). You can use cookies by supplying the `-Cookie` switch and the `-Secret` parameter to sign the cookies (this secret is different to the internal random secret CSRF uses to make tokens).

The below code will setup default CSRF middleware, which will store the random secret using sessions (so session middleware is required), and will ignore the default HTTP methods of GET, HEAD, OPTIONS, TRACE:

```powershell
Enable-PodeSessionMiddleware -Duration 120
Enable-PodeCsrfMiddleware
```

Once enabled, you can then use the [`New-PodeCsrfToken`](../../../../Functions/Middleware/New-PodeCsrfToken) function to generate CSRF tokens (see [below](#tokens)).

## Routes

If you only wish to have CSRF checks on specific routes, then you can use the [`Get-PodeCsrfMiddleware`](../../../../Functions/Middleware/Get-PodeCsrfMiddleware) function. The function will return CSRF middleware that you can assign to the `-Middleware` on routes.

However, if you use this approach you will first need to initialise CSRF - so you can generate tokens, and specify where the random secrets are stored. To do this, you can use the [`Initialize-PodeCsrf`](../../../../Functions/Middleware/Initialize-PodeCsrf) function.

The below code will intialise CSRF to work using cookies. it will then create a route and pass the CSRF middleware to it explicitly:

```powershell
Start-PodeServer {
    Initialize-PodeCsrf -Secret 'to-your-witcher' -UseCookies

    Add-PodeRoute -Method Post -Path '/users' -Middleware (Get-PodeCsrfMiddleware) -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Users = @() }
    }
}
```

Once initialised, you can then use the [`New-PodeCsrfToken`](../../../../Functions/Middleware/New-PodeCsrfToken) function to generate CSRF tokens (see [below](#tokens)).

## Tokens

The [`New-PodeCsrfToken`](../../../../Functions/Middleware/New-PodeCsrfToken) function allows you to generate tokens. It will randomly generate a token that you can use in your web-pages, such as in hidden form inputs or meta elements for AJAX requests. The token itself is formed using a secure random secret key, and a random salt.

To generate the token, you could use the following example:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Duration 120
    Enable-PodeCsrfMiddleware

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'login' -Data @{ 'token' = (New-PodeCsrfToken) }
    }
}
```

This will return a token as a `string` value. When you set this token in a hidden form input, the name of the input *must* be `pode.csrf`. The same applies to when sending the token via AJAX requests - in the query string, payload or header, the token should be named as `pode.csrf`.

## Example

The following example will configure CSRF as global middleware, and supply a token for the `<form>` in the index page. The POST route will require the token to be supplied, otherwise a 403 status code will be returned.

*server.ps1*
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http
    Set-PodeViewEngine -Type Pode

    # setup session and csrf middleware
    Enable-PodeSessionMiddleware -Duration 120
    Enable-PodeCsrfMiddleware

    # this route will work, as GET methods are ignored by CSRF by default
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $token = (New-PodeCsrfToken)
        Write-PodeViewResponse -Path 'index' -Data @{ 'csrfToken' = $token } -FlashMessages
    }

    # POST route for form which will require the csrf token from above
    Add-PodeRoute -Method Post -Path '/token' -ScriptBlock {
        Add-PodeFlashMessage -Name 'message' -Message $WebEvent.Data['message']
        Move-PodeResponseUrl -Url '/'
    }
}
```

*views/index.pode*
```html
<html>
    <head>
        <title>CSRF Example Page</title>
    </head>
    <body>
        <h1>Example form using a CSRF token</h1>
        <p>Clicking submit will just reload the page with your message</p>

        <form action='/token' method='POST'>
            <!-- the hidden input for the CSRF token needs to have the name 'pode.csrf' -->
            <input type='hidden' name='pode.csrf' value='$($data.csrfToken)' />
            <input type='text' name='message' placeholder='Enter any random text' />
            <input type='submit' value='Submit' />
        </form>

        <!-- on the page reload, display your message -->
        $(if ($data.flash['message']) {
            "<p>$($data.flash['message'])</p>"
        })
    </body>
</html>
```
