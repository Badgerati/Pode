# Sessions

Pode has support for Sessions when using Authentication, by default if you call a Route with authentication and you already have a session on the request then you're "authenticated". If there's no session, then the authentication logic is invoked, and if the details are invalid you're redirected to a login screen.

If you have a need to use multiple authentication methods for login, and the user can chose the one they want, then on Routes there's no simple way of say which authentication is required. However, under the hood they all create a session object which can be used as a "shared" authentication method.

This sessions authenticator can be used to pass authentication if a valid session in on the request, or to automatically redirect to a login page if there is no valid session. Useful for if you're using multiple authentication methods the user can choose from.

## Usage

To add sessions authentication you can use [`Add-PodeAuthSession`](../../../../Functions/Authentication/Add-PodeAuthSession). The following example will validate a user's credentials on login using Form authentication, but the home page uses session authentication to just verify there's a valid session:

```powershell
Start-PodeServer {
    # endpoint and view engine
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http
    Set-PodeViewEngine -Type Pode

    # enable sessions
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # setup form auth for login
    New-PodeAuthScheme -Form | Add-PodeAuth -Name 'FormAuth' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{ User = @{ Name = 'Morty' } }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # setup session auth for routes and logout
    Add-PodeAuthSession -Name 'SessionAuth' -FailureUrl '/login'

    # home page: use session auth, and redirect to login if no valid session
    Add-PodeRoute -Method Get -Path '/' -Authentication SessionAuth -ScriptBlock {
        Write-PodeViewResponse -Path 'auth-home'
    }

    # login page: use form auth here to actually verify the user's credentials
    Add-PodeRoute -Method Get -Path '/login' -Authentication FormAuth -Login -ScriptBlock {
        Write-PodeViewResponse -Path 'auth-login' -FlashMessages
    }

    # login check: again, use form auth
    Add-PodeRoute -Method Post -Path '/login' -Authentication FormAuth -Login

    # logout - use session auth here to purge the session
    Add-PodeRoute -Method Post -Path '/logout' -Authentication SessionAuth -Logout
}
```

### User Object

If a valid session is found on the request, then the user object set at `$WebEvent.Auth.User` will take the form of which ever authentication method using for login.

The user object will simply be loaded from the session.
