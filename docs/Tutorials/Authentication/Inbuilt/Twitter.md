# Twitter

The Twitter authentication is just a wrapper around the inbuilt [OAuth2](../OAuth2) authentication.

Only the `authorization_code` grant type is supported, and there's also support for PKCE, via `-UsePKCE` if sessions are enabled.

## Setup

Before using Twitter authentication in Pode, you first need to register a new app within Twitter:

* Make sure to have a Twitter Developer account, and open the Developer Portal
* Create a new, or select an existing app
* In the app's settings, select "Edit" on OAuth2 under "User authentication settings"
    * Enable "OAuth 2.0"
    * Set the Type of App to "Web App"
    * The default redirect is `<host>/oauth2/callback` (such as `http://localhost:8080/oauth2/callback`)
    * Enter some Website URL
    * Click "Save"
* Make a note of the Client ID and Secret presented

With the Client ID and Secret, you can now setup Twitter authentication in Pode.

### PKCE

If you're using PKCE, then the flow changes a little bit:

* Make sure to have a Twitter Developer account, and open the Developer Portal
* Create a new, or select an existing app
* In the app's settings, select "Edit" on OAuth2 under "User authentication settings"
    * Enable "OAuth 2.0"
    * Set the Type of App to "Single page App"
    * The default redirect is `<host>/oauth2/callback` (such as `http://localhost:8080/oauth2/callback`)
    * Enter some Website URL
    * Click "Save"
* Make a note of the Client ID presented

With just the Client ID you're good to go; PKCE doesn't require a Client Secret to work.

### Authorisation Code

To setup and start using Twitter authentication in Pode you use `New-PodeAuthTwitterScheme`, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function:

```powershell
Start-PodeServer {
    $scheme = New-PodeAuthTwitterScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>'

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken, $response)

        # check if the user is valid

        return @{ User = $user.data }
    }
}
```

If you don't specify a `-RedirectUrl`, then an internal default one is created as `/oauth2/callback` on the first endpoint.

When a user accesses your site unauthenticated, they will be to Twitter to login and approve your app, and then redirected back to your site.

## Middleware

Once configured you can start using Twitter Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Twitter Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Login'
}
```

Whereas the following example will use Twitter Authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/about' -Authentication 'Login' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Twitter authentication. This will setup and configure authentication, redirect a user to Twitter for validation and approval, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
    Set-PodeViewEngine -Type Pode

    # setup authentication to validate a user
    $scheme = New-PodeAuthTwitterScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>'

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken, $response)

        # check if the user is valid

        return @{ User = $user.data }
    }

    # home page:
    # redirects to login page if not authenticated
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        Write-PodeViewResponse -Path 'home' -Data @{ Username = $WebEvent.Auth.User.name }
    }

    # login - this will just redirect to twitter
    # NOTE: you do not need the -Login switch
    Add-PodeRoute -Method Get -Path '/login' -Authentication Login

    # logout
    Add-PodeRoute -Method Post -Path '/logout' -Authentication Login -Logout
}
```
