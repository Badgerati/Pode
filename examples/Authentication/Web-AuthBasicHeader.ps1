<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with session-based Basic authentication for REST APIs.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port, enables session-based authentication
    using headers, and provides login and logout functionality. Authenticated users can access a REST API endpoint
    to retrieve user information.

.PARAMETER Location
    The location where the API key is expected. Valid values are 'Header', 'Query', and 'Cookie'. Default is 'Header'.

.EXAMPLE
    To run the sample: ./Web-AuthBasicHeader.ps1

    This example shows how to use session authentication on REST APIs using Headers.
    The example used here is Basic authentication.

    Login:
    Invoke-RestMethod -Uri http://localhost:8081/login -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' } -ResponseHeadersVariable headers -SkipHttpErrorCheck
    $session = $headers['pode.sid']

    Users:
    Invoke-RestMethod -Uri http://localhost:8081/users -Method Post -Headers @{ 'pode.sid' = "$session" }

    Logout:
    Invoke-WebRequest -Uri http://localhost:8081/logout -Method Post -Headers @{ 'pode.sid' = "$session" }

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Authentication/Web-AuthBasicHeader.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
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
    Add-PodeRoute -Method Post -Path '/login' -Authentication 'Login'  -ErrorContentType 'application/json'

    # POST request to logout
    Add-PodeRoute -Method Post -Path '/logout' -Authentication 'Login' -Logout  -ErrorContentType 'application/json'

    # POST request to get list of users - the "pode.sid" header is expected
    Add-PodeRoute -Method Post -Path '/users' -Authentication 'Login'  -ErrorContentType 'application/json' -ScriptBlock {
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