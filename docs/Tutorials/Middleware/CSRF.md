# CSRF

Pode has inbuilt support for CSRF middleware validation and tokens on web requests, where the secret to generate/validate the token can be stored in either sessions or signed cookies. When configured, the middleware will check for, and validate, a CSRF token the on a web request for valid routes - with support to ignore specific HTTP methods. If a route fails CSRF validation, then Pode will return a 403 status code.

## Usage

To setup and configure using CSRF in Pode, you can use the [`csrf`](../../../Functions/Middleware/Csrf) function. This function allows you to generate CSRF tokens, as well as two methods of returning valid middleware that can be supplied to the [`middleware`](../../../Functions/Core/Middleware) function - or be used on `routes`.

The make-up of the `csrf` function is as follows:

```powershell
csrf <action> [-ignoreMethods @()] [-secret <string>] [-cookie]

# or with aliases:
csrf <action> [-i @()] [-s <string>] [-c]
```

The valid actions for the function are `middleware`, `check`, `setup` and `token`; each of which are described below.

The `-IgnoreMethods` array can either be empty, to run validation on every route, or can be formed of the following HTTP methods: DELETE, GET, HEAD, MERGE, OPTIONS, PATCH, POST, PUT, TRACE, STATIC.

The `-Secret` is used for signing the cookie that might be used, and is only required when `-Cookie` is also supplied.

## Actions

### Middleware

Using the `middleware` action on the [`csrf`](../../../Functions/Middleware/Csrf) function allows you to configure how CSRF will work in Pode, as well as returning a valid `scriptblock` that can be used with the [`middleware`](../../../Functions/Core/Middleware) function. You can also configure HTTP methods that CSRF should ignore, and not run validation, as well as whether or not CSRF should store the secret in sessions or using cookies.

The below will setup default CSRF middleware, which will use sessions (so session middleware is required), and will ignore the default HTTP methods of GET, HEAD, OPTIONS, TRACE, STATIC:

```powershell
middleware (session @{ 'secret' = 'vegeta' })
middleware (csrf middleware)
```

Now, you can use the `csrf` function with the `check` and `token` actions.

### Setup

Similar to the `middleware` action, the `setup` action on the [`csrf`](../../../Functions/Middleware/Csrf) function also allows you to configure how CSRF will work in Pode. You can configure HTTP methods that CSRF should ignore, and not run validation, as well as whether or not CSRF should store the secret in sessions or using cookies.

Below, we'll setup CSRF to work on cookies, and only ignore GET routes:

```powershell
csrf setup -i @('GET') -c -s 'secret-key'
```

Now, you can use the `csrf` function with the `check` and `token` actions.

### Check

The `check` action is similar to the `middleware` action, but is mostly designed so you can use it on `routes`. By default the CSRF middleware will ignore GET routes, however the `check` middleware skips this method validation - meaning you could use it on a GET route and it will require a valid CSRF token.

Unlike the `middleware` action however, you cannot configure HTTP methods to ignore or whether to to sessions/cookies. Therefore, in order to use this action you are required to use the `setup` action first (or the `middleware` action).

The below will run CSRF validation on the GET route, even though the setup is configured to ignore GET routes:

```powershell
server {
    csrf setup

    route get '/messages' (csrf check) {
        # logic
    }
}
```

### Tokens

The [`csrf`](../../../Functions/Middleware/Csrf) function allows you to generate tokens using the `token` action. It will randomly generate a token that you can use in your webpages, such as in hidden form inputs or meta elements for AJAX requests. The token itself is formed using a secure random secret key, and a random salt.

To generate the token, you can use the following command - but only after you've used either the `setup` or `middleware` actions to configure CSRF:

```powershell
server {
    middleware (csrf middleware)

    route get '/' {
        Write-PodeViewResponse -Path 'login' -Data @{ 'token' = (csrf token) }
    }
}
```

This will return a token as a `string` value. When you set this token in a hidden form input, the name of the input *must* be `pode.csrf`. The same applies to when sending the token via AJAX requests - in the query string, payload or header, the token should be named as `pode.csrf`.

## Example

The following example will configure CSRF as default middleware, and supply a token for the `<form>` in the index page. The POST route will require the token to be supplied, otherwise a 403 status code will be returned.

*server.ps1*
```powershell
server {
    listen localhost:8080 http
    Set-PodeViewEngine -Type Pode

    # setup session and csrf middleware
    middleware (session @{ 'secret' = 'schwifty' })
    middleware (csrf middleware)

    # this route will work, as GET methods are ignored by CSRF by default
    route get '/' {
        $token = (csrf token)
        Write-PodeViewResponse -Path 'index' -Data @{ 'csrfToken' = $token } -FlashMessages
    }

    # POST route for form which will require the csrf token from above
    route post '/token' {
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
