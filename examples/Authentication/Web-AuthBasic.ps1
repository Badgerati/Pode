<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with sessionless Basic authentication for REST APIs.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port, enables sessionless Basic authentication,
    and provides an endpoint to get user information.

.EXAMPLE
    To run the sample: ./Web-AuthBasic.ps1

    This example shows how to use sessionless authentication, which will mostly be for
    REST APIs. The example used here is Basic authentication.

    Calling the '[POST] http://localhost:8081/users' endpoint, with an Authorization
    header of 'Basic bW9ydHk6cGlja2xl' will display the uesrs. Anything else and
    you'll get a 401 status code back.

    Success:
    Invoke-RestMethod -Uri http://localhost:8081/users -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }

    Failure:
    Invoke-RestMethod -Uri http://localhost:8081/users -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cmljaw==' }

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Authentication/Web-AuthBasic.ps1

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

    # request logging
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic -Realm 'Pode Example Page' | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    Username = 'morty'
                    ID       = 'M0R7Y302'
                    Name     = 'Morty'
                    Type     = 'Human'
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }


    # POST request to get current user (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Post -Path '/users' -Authentication 'Validate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            User = (Get-PodeAuthUser)
        }
    }

}