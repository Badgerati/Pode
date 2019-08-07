# CSRF

Pode has inbuilt support for CSRF middleware validation and tokens on web requests, where the secret to generate/validate the token can be stored in either sessions or signed cookies. When configured, the middleware will check for, and validate, a CSRF token the on a web request for valid routes - with support to ignore specific HTTP methods. If a route fails CSRF validation, then Pode will return a 403 status code.

## Usage

To use CSRF in Pode, you can use the CSRF functions. These functions allow you to generate CSRF tokens, as well as two methods of returning valid middleware.

The `-IgnoreMethods` array can either be empty, to run validation on every route, or can be formed of the following HTTP methods: DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, TRACE.

The `-Secret` is used for signing the cookie that might be used, and is only required when `-Cookie` is also supplied.

## Functions

### Enable-PodeCsrfMiddleware

This function will configure how CSRF will work in Pode, as well as automatically create the Middleware. You can also configure HTTP methods that CSRF should ignore, and not run validation, as well as whether or not CSRF should store the secret in sessions or using cookies.

The below will setup default CSRF middleware, which will use sessions (so session middleware is required), and will ignore the default HTTP methods of GET, HEAD, OPTIONS, TRACE:

```powershell
Enable-PodeSessionMiddleware -Secret 'vegeta'
Enable-PodeCsrfMiddleware
```

### Initialize-PodeCsrf

Similar to the [`Enable-PodeCsrfMiddleware`](../../../../../Functions/Middleware/Enable-PodeCsrfMiddleware) function, this function configures how CSRF will work in Pode. You can configure HTTP methods that CSRF should ignore, and not run validation, as well as whether or not CSRF should store the secret in sessions or using cookies.

This function is to be used when you want to use the [`Get-PodeCsrfMiddleware`](../../../../../Functions/Middleware/Get-PodeCsrfMiddleware) function, for more dynamic control of CSRF verification.

Below, we'll setup CSRF to work on cookies, and only ignore GET routes:

```powershell
Initialize-PodeCsrf -IgnoreMethods @('Get') -Secret 'secret-key' -UseCookies
```

### Get-PodeCsrfMiddleware

The [`Get-PodeCsrfMiddleware`](../../../../../Functions/Middleware/Get-PodeCsrfMiddleware) function is similar to the [`Get-PodeCsrfMiddleware`](../../../../../Functions/Middleware/Get-PodeCsrfMiddleware) function, but is designed so you can use it on Routes so SRF verification can be used more dynamically. By default the CSRF middleware will ignore GET routes, however the [`Get-PodeCsrfMiddleware`](../../../../../Functions/Middleware/Get-PodeCsrfMiddleware) middleware skips this method validation - meaning you could use it on a GET route and it will require a valid CSRF token.

Unlike the [`Enable-PodeCsrfMiddleware`](../../../../../Functions/Middleware/Enable-PodeCsrfMiddleware) function however, you cannot configure HTTP methods to ignore or whether to use sessions/cookies. Therefore, in order to use this action you are required to use the [`Enable-PodeCsrfMiddleware`](../../../../../Functions/Middleware/Enable-PodeCsrfMiddleware) action first.

The below will run CSRF validation on the GET route, even though the setup is configured to ignore GET routes:

```powershell
Start-PodeServer {
    Initialize-PodeCsrf -IgnoreMethods @('Get')

    Add-PodeRoute -Method Get -Path '/messages' -Middleware (Get-PodeCsrfMiddleware) -ScriptBlock {
        # logic
    }
}
```

### New-PodeCsrfToken

The [`New-PodeCsrfToken`](../../../../../Functions/Middleware/New-PodeCsrfToken) function allows you to generate tokens. It will randomly generate a token that you can use in your web-pages, such as in hidden form inputs or meta elements for AJAX requests. The token itself is formed using a secure random secret key, and a random salt.

To generate the token, you can use the following example:

```powershell
Start-PodeServer {
    Enable-PodeSessionMiddleware -Secret 'vegeta'
    Enable-PodeCsrfMiddleware

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'login' -Data @{ 'token' = (New-PodeCsrfToken) }
    }
}
```

This will return a token as a `string` value. When you set this token in a hidden form input, the name of the input *must* be `pode.csrf`. The same applies to when sending the token via AJAX requests - in the query string, payload or header, the token should be named as `pode.csrf`.

## Example

The following example will configure CSRF as default middleware, and supply a token for the `<form>` in the index page. The POST route will require the token to be supplied, otherwise a 403 status code will be returned.

*server.ps1*
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost:8080 -Protocol Http
    Set-PodeViewEngine -Type Pode

    # setup session and csrf middleware
    Enable-PodeSessionMiddleware -Secret 'vegeta'
    Enable-PodeCsrfMiddleware

    # this route will work, as GET methods are ignored by CSRF by default
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $token = (New-PodeCsrfToken)
        Write-PodeViewResponse -Path 'index' -Data @{ 'csrfToken' = $token } -FlashMessages
    }

    # POST route for form which will require the csrf token from above
    Add-PodeRoute -Method Post -Path '/token' -ScriptBlock {
        param($e)
        Add-PodeFlashMessage -Name 'message' -Message $e.Data['message']
        Move-PodeResponseUrl -Url '/'
    }
}
```

*index.pode*
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
