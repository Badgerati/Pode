# Csrf

## Description

The `csrf` function allows you to setup CSRF validation, create middleware/check actions, and generate a token for use in webpages. If a route fails CSRF validation then a 403 status is returned.

For the CSRF middleware, there are two different actions: `middleware` and `check`:

* The `middleware` action will return a valid `scriptblock` for use with the [`middleware`](../../Core/Middleware) function. This is the main middleware that will apply to all routes that aren't set to have their HTTP methods be ignored.

* The `check` action will also return a valid `scriptblock` for use with the [`middleware`](../../Core/Middleware) function. However, this middleware will run the validation for every route, regardless of the HTTP methods being ignored. This action is mostly designed if you are ignoring all `GET` methods, but want validation on one of them. (To use the `check` action you need to first use the `setup` action - unless you've already run the `middleware` action).

To generate a new token, you can use the `token` action. This returns a token that you can use in your webpages - such as hidden inputs on forms, or in meta tags.

To configure CSRF middleware - to use cookies, or ignore methods - you can either directly use the `setup` action, or use the `middleware` action.

!!! important
    When setting the CSRF token in a hidden form input, the input *must* have a name of `pode.csrf`. The same applies to when sending the token via AJAX requests - in the query string, payload or header, the token should be named as `pode.csrf`.

## Examples

### Example 1

The following example will setup CSRF middleware, along with session middleware. The GET route will generate a token for the `view`, which will be validated on the POST route:

```powershell
server {
    middleware (session @{ 'secret' = 'vegeta' })
    middleware (csrf middleware)

    route get '/' {
        view 'index' @{ 'token' = (csrf token) }
    }

    route post '/login' {
        # the csrf token is required to use this route
    }
}
```

### Example 2

The following example will setup CSRF middleware to use cookies, with a secret key for signing, instead of using sessions. Similar to the above example: the GET route will generate a token for the `view`, which will be validated on the POST route:

```powershell
server {
    middleware (csrf middleware -c -s 'goku')

    route get '/' {
        view 'index' @{ 'token' = (csrf token) }
    }

    route post '/login' {
        # the csrf token is required to use this route
    }
}
```

### Example 3

The following example will setup CSRF, and then do explicit checks on certain routes - regardless of what HTTP methods CSRF is setup to ignore. Here, the first GET route will render, but the other GET and POST routes will need to pass CSRF validation:

```powershell
server {
    csrf setup -c -s 'broly'

    route get '/' {
        view 'index' @{ 'token' = (csrf token) }
    }

    route get '/messages' (csrf check) {
        # the csrf token is required to use this route
    }

    route post '/login' (csrf check) {
        # the csrf token is required to use this route
    }
}
```

### Example 4

The following example will setup CSRF middleware to only ignore routes on GET requests:

```powershell
server {
    middleware (csrf middleware -i @('GET'))
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Action | string | true | The action to perform (Values: Check, Middleware, Setup, Token) | null |
| IgnoreMethods | string[] | false | An array of methods that CSRF validation should ignore (unless explicitly using the `check` action) | GET, HEAD, OPTIONS, TRACE, STATIC |
| Secret | string | false | Only for cookies, allows you to specify a secret key to sign the cookie. If not supplied, a global cookie secret needs to be configured | null |
| Cookie | switch | false | If true, CSRF will use cookies instead of sessions | false |

## Returns

* The `middleware` and `check` action returns a valid middleware `scriptblock` value.

* The `token` action returns a secure random CSRF token as a `string` value.