<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with Basic authentication for REST APIs.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port, enables basic authentication
    for a REST API endpoint, and returns user information upon successful authentication. The authentication
    details are checked on a per-request basis without using session-based authentication.

.PARAMETER Location
    The location where the API key is expected. Valid values are 'Header', 'Query', and 'Cookie'. Default is 'Header'.

.EXAMPLE
    This example shows how to use sessionless authentication, which will mostly be for
    REST APIs. The example used here is Basic authentication.

    Calling the '[POST] http://localhost:8081/users' endpoint, with an Authorization
    header of 'Basic bW9ydHk6cGlja2xl' will display the uesrs. Anything else and
    you'll get a 401 status code back.

    Success:
    Invoke-RestMethod -Uri http://localhost:8081/users -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }

    Failure:
    Invoke-RestMethod -Uri http://localhost:8081/users -Headers @{ Authorization = 'Basic bW9ydHk6cmljaw==' }

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

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic -Realm 'Pode Example Page' | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
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

    # GET request to get list of users (since there's no session, authentication will always happen, but, we're allowing anon access)
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'Validate' -AllowAnon -ScriptBlock {
        if (Test-PodeAuthUser) {
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
        else {
            Write-PodeJsonResponse -Value @{
                Users = @(
                    @{
                        Name = 'John Smith'
                        Age = 21
                    }
                )
            }
        }
    }

}