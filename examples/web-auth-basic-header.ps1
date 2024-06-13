try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

<#
This example shows how to use session authentication on REST APIs using Headers.
The example used here is Basic authentication.

Login:
$session = (Invoke-WebRequest -Uri http://localhost:8081/login -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }).Headers['pode.sid']

Users:
Invoke-RestMethod -Uri http://localhost:8081/users -Method Post -Headers @{ 'pode.sid' = "$session" }

Logout:
Invoke-WebRequest -Uri http://localhost:8081/logout -Method Post -Headers @{ 'pode.sid' = "$session" }
#>

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # enable error logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend -UseHeaders -Strict

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # POST request to login
    Add-PodeRoute -Method Post -Path '/login' -Authentication 'Login'

    # POST request to logout
    Add-PodeRoute -Method Post -Path '/logout' -Authentication 'Login' -Logout

    # POST request to get list of users - the "pode.sid" header is expected
    Add-PodeRoute -Method Post -Path '/users' -Authentication 'Login' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Deep Thought'
                    Age = 42
                },
                @{
                    Name = 'Leeroy Jenkins'
                    Age = 1337
                }
            )
        }
    }

}