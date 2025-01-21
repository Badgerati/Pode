<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with a view engine and file monitoring.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081, uses Pode's view engine for rendering
    web pages, and configures the server to monitor file changes and restart automatically.

.EXAMPLE
    To run the sample: ./File-Monitoring.ps1

    Invoke-RestMethod -Uri http://localhost:8081 -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/File-Monitoring.ps1

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


Start-PodeServer {
    Add-PodeEndpoint -Address 'localhost' -Protocol 'Http' -Port '80'
    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'   -DisableMinimalDefinitions -NoDefaultResponses
    Add-PodeOAInfo -Title 'test custom auth error' -Version 1.0.0
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'
    Add-PodeOAServerEndpoint -url '/api/v3' -Description 'default endpoint'
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'APIKey' -Sessionless -ScriptBlock {
        param($key)
        write-podehost $key
        write-podehost $WebEvent -Explode
        if ($key -eq 'test_user') {
            return @{ success=$true; User = 'test_user' }
        }
        return @{ success=$false; User = $key }
    }



    Add-PodeRoute -PassThru -Method 'Get' -Path '/api/v3/' -Authentication 'APIKey' -NoValidation  -ScriptBlock {
        $auth = Invoke-PodeAuth -Name 'APIKey'

        write-podehost $auth -Explode
        if ($auth.Success) {
            Write-PodeJsonResponse -Value @{
                Username = $auth.User
            }

        }
        else {
            Write-PodeJsonResponse -Value @{ message = 'Unauthorized' ; user = $auth.User } -StatusCode 401
        }

    } | Set-PodeOARouteInfo -Summary 'Who am I'   -Tags 'auth' -OperationId 'whoami'
}