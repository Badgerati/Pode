<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with basic authentication and dynamic route generation.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081. It includes basic authentication, error logging,
    and dynamic route generation for specified commands. Each route requires authentication.

.EXAMPLE
    To run the sample: ./Web-FuncsToRoutes.ps1

    Invoke-RestMethod -Uri http://localhost:8081/Get-ChildItem -Method Get -ContentType 'application/json' -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
    Invoke-RestMethod -Uri http://localhost:8081/Get-Host -Method Get -ContentType 'application/json' -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
    Invoke-RestMethod -Uri http://localhost:8081/Invoke-Expression -Method Post -ContentType 'application/json' -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-FuncsToRoutes.ps1

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

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
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

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # make routes for functions - with every route requires authentication
    ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Authentication Validate -Verbose

    # make routes for every exported command in Pester
    # ConvertTo-PodeRoute -Module Pester -Verbose

}
