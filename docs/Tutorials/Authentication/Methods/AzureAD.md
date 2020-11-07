# Azure AD

The Azure AD authentication is just a wrapper around the inbuilt [OAuth2](../OAuth2) authentication.

Both the `authorization_code` and `password` grant types are supported. The `password` type is only supported on Work/School accounts, and on accounts with MFA disabled.

!!! note
    When using Azure AD and a specific login route, you don't need to set the `-Login` switch. This is due to the redirecting of OAuth2.

## Setup

Before using Azure AD authentication in Pode, you first need to register a new app within Azure:

* In the Azure Portal, open up the Azure Active Directory
* Then select "App Registrations" in the menu, followed by "New Registration" at the top
* Enter a name for the app, followed by the redirect URL
    * the default is redirect is `<host>/oauth2/callback` (such as `http://localhost:8080/oauth2/callback`)
* Click create
    * Make a note of the "Client ID" and "Tenant"
* Then select "Certificates & Secrets"
* Click "New Client Secret"
    * Make a note of the generate secret

With the Client and Tenant ID, plus the Client Secret, you can now setup Azure AD authentication in Pode.

### Authorisation Code

To setup and start using Azure AD Authentication in Pode you use `New-PodeAuthAzureADScheme`, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function:

```powershell
Start-PodeServer {
    $scheme = New-PodeAuthAzureADScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>' -Tenant '<tenant>'

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

If you don't specify a `-RedirectUrl`, then an internal default one is created as `/oauth2/callback` on the first endpoint.

When a user accesses your site unauthenticated, they will be to Azure to login, and then redirected back to your site.

### Password

To setup Azure AD authentcation, but using your own Form login, then you can use the `-InnerScheme` parameter on `New-PodeAuthAzureADScheme`:

```powershell
Start-PodeServer {
    $form  = New-PodeAuthScheme -Form

    $scheme = New-PodeAuthAzureADScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>' -Tenant '<tenant>' -InnerScheme $form

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

## Middleware

Once configured you can start using Azure AD Authentication to validate incoming Requests. You can either configure the validation to happen on every Route as global Middleware, or as custom Route Middleware.

The following will use Azure AD Authentication to validate every request on every Route:

```powershell
Start-PodeServer {
    Add-PodeAuthMiddleware -Name 'GlobalAuthValidation' -Authentication 'Login'
}
```

Whereas the following example will use Azure AD Authentication to only validate requests on specific a Route:

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Get -Path '/about' -Authentication 'Login' -ScriptBlock {
        # logic
    }
}
```

## Full Example

The following full example of Azure AD authentication. This will setup and configure authentication, redirect a user to Azure for validation, and then validate on a specific Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
    Set-PodeViewEngine -Type Pode

    # setup authentication to validate a user
    $scheme = New-PodeAuthAzureADScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>' -Tenant '<tenant>'

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

    # login - this will just redirect to azure
    # NOTE: you do not need the -Login switch
    Add-PodeRoute -Method Get -Path '/login' -Authentication Login

    # logout
    Add-PodeRoute -Method Post -Path '/logout' -Authentication Login -Logout
}
```
