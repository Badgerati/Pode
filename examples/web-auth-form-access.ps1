$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
if (Test-Path -Path "$($path)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
}
else {
    Import-Module -Name 'Pode'
}

<#
This examples shows how to use session persistant authentication with access.
The example used here is Form authentication and RBAC access on pages, sent from the <form> in HTML.

Navigating to the 'http://localhost:8085' endpoint in your browser will auto-rediect you to the '/login'
page. Here, you can type the username (morty) and the password (pickle); clicking 'Login' will take you
back to the home page with a greeting and a view counter. Clicking 'Logout' will purge the session and
take you back to the login page.

- The Home and Login pages are accessible by all.
- The About page is only accessible by Developers (for morty it will load)
- The Register page is only accessible by QAs (for morty this will 403)
#>

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address localhost -Port 8085 -Protocol Http

    # set the view engine
    Set-PodeViewEngine -Type Pode

    # enable error logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # setup form auth (<form> in HTML)
    New-PodeAuthScheme -Form | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    Name = 'Morty'
                    Roles = @('Developer')
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # set RBAC access
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'Rbac' -Match One


    # home page:
    # redirects to login page if not authenticated
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        $session:Views++

        Write-PodeViewResponse -Path 'auth-home' -Data @{
            Username = $WebEvent.Auth.User.Name
            Views = $session:Views
            Expiry = Get-PodeSessionExpiry
        }
    }


    # about page:
    # only Developers can access this page
    Add-PodeRoute -Method Get -Path '/about' -Authentication Login -Access Rbac -Role Developer -ScriptBlock {
        Write-PodeViewResponse -Path 'auth-about'
    }


    # register page:
    # only QAs can access this page
    Add-PodeRoute -Method Get -Path '/register' -Authentication Login -Access Rbac -Role QA -ScriptBlock {
        Write-PodeViewResponse -Path 'auth-register'
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