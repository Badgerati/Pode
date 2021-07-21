$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
This examples shows how to use session persistant authentication using Azure AD and OAuth2, using a Form with no redirecting.

Navigating to the 'http://localhost:8085' endpoint in your browser will auto-rediect you to the /login form.
There, enter you Azure AD email/password, Pode with authenticate and then take you to the home page

Note: You'll need to register a new app in Azure, and note you clientId, secret, and tenant
      in the variables below.
#>

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http -Default
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set the view engine
    Set-PodeViewEngine -Type Pode

    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # setup form auth against Azure AD (the following are from registering an app in the portal)
    $clientId = '<client-id-from-portal>'
    $clientSecret = '<client-secret-from-portal>'
    $tenantId = '<tenant-from-portal>'

    $form = New-PodeAuthScheme -Form
    $scheme = New-PodeAuthAzureADScheme -Tenant $tenantId -ClientId $clientId -ClientSecret $clientSecret -InnerScheme $form
    $scheme | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)
        return @{ User = $user }
    }


    # home page:
    # redirects to login page if not authenticated
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        $WebEvent.Session.Data.Views++

        Write-PodeViewResponse -Path 'auth-home' -Data @{
            Username = $WebEvent.Auth.User.name
            Views = $WebEvent.Session.Data.Views
        }
    }


    # login - enter creds to authorise against Azure AD
    Add-PodeRoute -Method Get -Path '/login' -Authentication Login -Login -ScriptBlock {
        Write-PodeViewResponse -Path 'auth-login' -FlashMessages
    }

    Add-PodeRoute -Method Post -Path '/login' -Authentication Login -Login


    # logout check:
    # when the logout button is click, this endpoint is invoked. The logout flag set below informs this call
    # to purge the currently authenticated session, and then redirect back to the login page
    Add-PodeRoute -Method Post -Path '/logout' -Authentication Login -Logout
}