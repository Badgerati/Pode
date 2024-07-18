<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with session persistent authentication using Windows Local users.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with session persistent authentication.
    It demonstrates a login system using form authentication against Windows Local users.

.EXAMPLE
    To run the sample: ./Web-AuthFormLocal.ps1

    This examples shows how to use session persistant authentication using Windows Local users.
    The example used here is Form authentication, sent from the <form> in HTML.

    Navigating to 'http://localhost:8081' in your browser will redirect you to the '/login' page.
    You can log in using the details for a domain user. After logging in, you will see a greeting and a view counter.
    Clicking 'Logout' will purge the session and take you back to the login page.

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-AuthFormLocal.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set the view engine
    Set-PodeViewEngine -Type Pode

    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # setup form auth against windows local users (<form> in HTML)
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'Login' -Groups @() -Users @() -FailureUrl '/login' -SuccessUrl '/'


    # home page:
    # redirects to login page if not authenticated
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        $WebEvent.Session.Data.Views++

        Write-PodeViewResponse -Path 'auth-home' -Data @{
            Username = $WebEvent.Auth.User.Name
            Views = $WebEvent.Session.Data.Views
        }
    }


    # login page:
    # the login flag set below checks if there is already an authenticated session cookie. If there is, then
    # the user is redirected to the home page. If there is no session then the login page will load without
    # checking user authetication (to prevent a 401 status)
    Add-PodeRoute -Method Get -Path '/login' -Authentication Login -Login -ScriptBlock {
        Write-PodeViewResponse -Path 'auth-login' -FlashMessages
    }


    # login check:
    # this is the endpoint the <form>'s action will invoke. If the user validates then they are set against
    # the session as authenticated, and redirect to the home page. If they fail, then the login page reloads
    Add-PodeRoute -Method Post -Path '/login' -Authentication Login -Login


    # logout check:
    # when the logout button is click, this endpoint is invoked. The logout flag set below informs this call
    # to purge the currently authenticated session, and then redirect back to the login page
    Add-PodeRoute -Method Post -Path '/logout' -Authentication Login -Logout
}