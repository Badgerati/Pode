# Azure AD

The Azure AD authentication is just a wrapper around the inbuilt [OAuth2](../OAuth2) authentication.

Both the `authorization_code` and `password` grant types are supported. The `password` type is only supported on Work/School accounts, and on accounts with MFA disabled. There is also support for PKCE, via `-UsePKCE` if sessions are enabled.

## Setup

Before using Azure AD authentication in Pode, you first need to register a new app within Azure:

* In the Azure Portal, open up the Azure Active Directory
* Then select "App Registrations" in the menu, followed by "New Registration" at the top
* Enter a name for the app, followed by the redirect URL
    * Platform should be "Web"
    * The default redirect is `<host>/oauth2/callback` (such as `http://localhost:8080/oauth2/callback`)
* Click create
    * Make a note of the "Client ID" and "Tenant"
* Then select "Certificates & Secrets"
* Click "New Client Secret"
    * Make a note of the generate secret

With the Client and Tenant ID, plus the Client Secret, you can now setup Azure AD authentication in Pode.

### PKCE

If you're using PKCE, then the flow changes a little bit:

* In the Azure Portal, open up the Azure Active Directory
* Then select "App Registrations" in the menu, followed by "New Registration" at the top
* Enter a name for the app, followed by the redirect URL
    * Platform should be "Single-page application"
    * The default redirect is `<host>/oauth2/callback` (such as `http://localhost:8080/oauth2/callback`)
* Click create
    * Make a note of the "Client ID" and "Tenant"

With just the Client and Tenant ID you're good to go; PKCE doesn't require a Client Secret to work.

### Authorisation Code

To setup and start using Azure AD authentication in Pode you use `New-PodeAuthAzureADScheme`, and then pipe this into the [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth) function:

```powershell
Start-PodeServer {
    $scheme = New-PodeAuthAzureADScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>' -Tenant '<tenant>'

    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken, $response)

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
        param($user, $accessToken, $refreshToken, $response)

        # check if the user is valid

        return @{ User = $user }
    }
}
```

## Requests using Basic Authentication

To authenticate against Azure Active Directory with Applications that do not support Modern authentication (for example PowerShell Invoke-RestMethod), you will need to use Basic authentication.
This method only works if you're either using Password Hash Sync (PHS), Pass-through authentication (PTA) or both. If you're using claim based authentication against another IdP like Active Directory Federation Services (ADFS) then this will not work as the Azure AD does not know the users' credentials.

The client side may look like this:

```powershell
$res = Invoke-RestMethod -Url 'http://localhost:8080' -SessionVariable session
$res.Form[0].username = 'username'
$res.Form[0].password = 'password'
Invoke-RestMethod -Url 'http://localhost:8080' -WebSession $session -Body $res.Form[0]
```

The Pode side needs to be configured to allow basic authentication as well. This can be done side by side with Form based authentication using this example

```powershell
$form  = New-PodeAuthScheme -Form
$schemeForm = New-PodeAuthAzureADScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>' -Tenant '<tenant>' -InnerScheme $form

$basic = New-PodeAuthSceme -Basic
$schemeBasic = New-PodeAuthAzureADScheme -ClientID '<clientId>' -ClientSecret '<clientSecret>' -Tenant '<tenant>' -InnerScheme $basic

$authLogin = {
    param($user, $accessToken, $refreshToken, $response)
    # check user
}

$schemeForm | Add-PodeAuth -Name 'LoginForm' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock $authLogic
$schemeBasic | Add-PodeAuth -Name 'LoginBasic' -ScriptBlock $authLogic
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
        param($user, $accessToken, $refreshToken, $response)

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
