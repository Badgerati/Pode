<#
.SYNOPSIS
    PowerShell script to set up a Pode server with various endpoints and error logging.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and provides both HTTP and WebSocket
    endpoints. It demonstrates how to set up WebSockets in Pode, using a manual upgrade path, and logs
    errors and other request details to the terminal. Connections to the WebSocket are also locked behind
    a form-based authentication.

    WebSocket authentication is only supported when using manual upgrade paths.

.PARAMETER Port
    The port number on which the server will listen. Default is 8091.

.EXAMPLE
    To run the sample: ./Web-SignalAuthForm.ps1

    Invoke-RestMethod -Uri http://localhost:8091/ -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-SignalAuthForm.ps1

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

# create a server, and start listening
Start-PodeServer -Threads 3 {

    # listen
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Ws -NoAutoUpgradeWebSockets

    # log errors to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels Error

    # register a connect event
    Register-PodeSignalEvent -Name 'Msg', 'Local' -Type Connect -EventName 'SignalConnected' -ScriptBlock {
        "Connected: $($TriggeredEvent.Connection.Name) ($($TriggeredEvent.Connection.ClientId))" | Out-Default
    }

    # register a disconnect event
    Register-PodeSignalEvent -Name 'Msg', 'Local' -Type Disconnect -EventName 'SignalDisconnected' -ScriptBlock {
        "Disconnected: $($TriggeredEvent.Connection.Name) ($($TriggeredEvent.Connection.ClientId))" | Out-Default
    }

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # setup form auth (<form> in HTML)
    New-PodeAuthScheme -Form | Add-PodeAuth -Name 'Login' -FailureUrl '/login' -SuccessUrl '/' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID   = 'M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        if ($username -eq 'rick' -and $password -eq 'sanchez') {
            return @{
                User = @{
                    ID   = 'R1CKY42'
                    Name = 'Rick'
                    Type = 'Genius'
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # register a login event, and broadcast to websocket clients
    Register-PodeAuthEvent -Name 'Login' -Type Login -EventName 'AuthLogin' -ScriptBlock {
        "User logged in: $($TriggeredEvent.User.Name)" | Out-Default
    }

    # register a logout event, and broadcast to websocket clients
    Register-PodeAuthEvent -Name 'Login' -Type Logout -EventName 'AuthLogout' -ScriptBlock {
        "User logged out: $($TriggeredEvent.User.Name)" | Out-Default
        Send-PodeSignal -Name 'Msg' -Value @{ message = "User '$($TriggeredEvent.User.Name)' has logged out." }
    }

    # home page:
    # redirects to login page if not authenticated
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        Write-PodeViewResponse -Path 'websockets' -Data @{
            IsSecure = $true
        }
    }

    # login page:
    # the login flag set below checks if there is already an authenticated session cookie. If there is, then
    # the user is redirected to the home page. If there is no session then the login page will load without
    # checking user authentication (to prevent a 401 status)
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

    # GET request for websocket upgrade, requires authentication initially so the connection
    # can be upgraded
    Add-PodeRoute -Method Get -Path '/msg' -Authentication Login -ScriptBlock {
        ConvertTo-PodeSignalConnection -Name 'Msg'
        Send-PodeSignal -Name 'Msg' -Value @{ message = "User '$($WebEvent.Auth.User.Name)' has logged in." }
    }

    # GET request for websocket upgrade, with authentication, but the upgrade is local
    # and will be closed at the end of the request
    Add-PodeRoute -Method Get -Path '/local' -Authentication Login -ScriptBlock {
        ConvertTo-PodeSignalConnection -Name 'Local' -Scope Local
        Send-PodeSignal -Name 'Local' -Value @{ message = 'This is a local signal connection' }
        Start-Sleep -Seconds 3
        Send-PodeSignal -Name 'Local' -Value @{ message = 'Another local signal message' }
    }

    # SIGNAL route, to return current date
    Add-PodeSignalRoute -Path '/msg' -ScriptBlock {
        $msg = $SignalEvent.Data.Message

        if ($msg -ieq '[date]') {
            $msg = [datetime]::Now.ToString()
        }

        Send-PodeSignal -Value @{ message = $msg }
    }
}