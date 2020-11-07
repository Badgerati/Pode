# OAuth2

The OAuth2 authentication lets you setup authentication with other services that support OAuth2.

To use this scheme, you'll need to supply an Authorise/Token URL, as well as setup a app registration to acquire a Client ID and Secret.

!!! note
    When using OAuth2 and a specific login route, you don't need to set the `-Login` switch. This is due to the redirecting of OAuth2.

## Setup

Before using the OAuth2 authentication in Pode, you first need to register a new app within your service of choice. This registration will supply you with the required Client ID and Secret.

To setup and start using OAuth2 Authentication in Pode you use `New-PodeAuthScheme -OAuth2`, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function.

## Grant Types

Pode supports the grant types of `authorization_code` and `password`. By default OAuth2 will use the `authorization_code` grant type, which will require an `-AuthoriseUrl` and `-RedirectUrl`.

If you want to use the `password` grant type, and have users enter their credentials via a form or Basic authentication, then you'll need to supply an `-InnerScheme` type to `New-PodeAuthScheme -OAuth2`.

These types are described below.

### Authorisation Code

This is the default grant type, and requires an `-AuthoriseUrl` to be supplied. A `-RedirectUrl` is also required, but if not supplied an default one will be setup internally.

You will need to supply the service's Authorise and Token URLs to `New-PodeAuthScheme` as below:

```powershell
Start-PodeServer {
    $scheme = New-PodeAuthScheme `
        -OAuth2 `
        -ClientID '<clientId>' `
        -ClientSecret '<clientSecret>' `
        -AuthoriseUrl 'https://some-service.com/oauth2/authorize' `
        -TokenUrl 'https://some-service.com/oauth2/token'

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

If you don't specify a `-RedirectUrl`, then an internal default one is created as `/oauth2/callback` on the first endpoint.

When a user accesses your site unauthenticated, they will be redirected to the service to login, and then redirected back to your site. Pode will supply to your `Add-PodeAuth` the user object (if available), and the access/refresh tokens.

You can optional specify a `-UserUrl` endpoint, if the service supports it, and Pode will use this to acquire user details. If one is not supplied, the `$user` object supplied to `Add-PodeAuth`'s ScriptBlock will be an basic hashtable:

```powershell
@{
    Provider = 'OAuth2'
}
```

If you define a Login route, you don't need to set the `-Login` switch, due to the redirecting of OAuth2. A login route can be a simple route with no view defined:

```powershell
Add-PodeRoute -Method Get -Path '/login' -Authentication Login
```

### Password

!!! important
    This flow will not work if 2FA is setup on accounts. In most cases, for some providers, you also need to explicitly enable this grant type.

Using this grant type allows you to support authentication in flows where redirecting is impossible - such as REST APIs using Basic authentication.

To use this grant type, you need to define another Scheme - such as Basic or Form - and then supply that Scheme to the `-InnerScheme` parameter of `New-PodeAuthScheme -OAuth2`. Pode will automatically switch to the password grant type.

```powershell
Start-PodeServer {
    $form = New-PodeAuthScheme -Form

    $scheme = New-PodeAuthScheme `
        -OAuth2 `
        -ClientID '<clientId>' `
        -ClientSecret '<clientSecret>' `
        -TokenUrl 'https://some-service.com/oauth2/token' `
        -InnerScheme $form

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

When using the password grant, an `-AuthoriseUrl` and `-RedirectUrl` are not required.

If you define a Login route, you define it in the usual way using the `-Login` switch, as OAuth2 won't be redirecting to the service to authenticate the user:

```powershell
Add-PodeRoute -Method Get -Path '/login' -Authentication Login -Login -ScriptBlock {
    Write-PodeViewResponse -Path 'login' -FlashMessages
}

Add-PodeRoute -Method Post -Path '/login' -Authentication Login -Login
```

## Middleware

Once configured you can start using the OAuth2 Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Oauth2 Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Login'
}
```

Whereas the following example will use Oauth2 Authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/about' -Authentication 'Login' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following is an example of OAuth2 authentication usin the `authorization_code` grant type. This will setup and configure authentication, redirect a user to some service for validation, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
    Set-PodeViewEngine -Type Pode

    # setup authentication to validate a user
    $scheme = New-PodeAuthScheme `
        -OAuth2 `
        -ClientID '<clientId>' `
        -ClientSecret '<clientSecret>' `
        -AuthoriseUrl 'https://some-service.com/oauth2/authorize' `
        -TokenUrl 'https://some-service.com/oauth2/token'

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)

        # check if the user is valid

        return @{ User = $user }
    }

    # home page:
    # redirects to login page if not authenticated
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        Write-PodeViewResponse -Path 'home' -Data @{ Username = $WebEvent.Auth.User.name }
    }

    # login - this will just redirect to the service
    # NOTE: you do not need the -Login switch
    Add-PodeRoute -Method Get -Path '/login' -Authentication Login

    # logout
    Add-PodeRoute -Method Post -Path '/logout' -Authentication Login -Logout
}
```
