<#
.SYNOPSIS
    Example of using Negotiate authentication with Pode.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8080, logs errors to the terminal,
    and demonstrates the use of Negotiate authentication. The server provides a single route
    that requires Negotiate authentication to access.

.EXAMPLE
    To run the sample: ./Web-AuthNegotiate.ps1

    Invoke-RestMethod -Uri 'http://pode.example.com:8080' -UseDefaultCredentials

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Authentication/Web-AuthNegotiate.ps1

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

Start-PodeServer -Threads 2 {
    # listen on localhost:8080
    Add-PodeEndpoint -Address localhost -Port 8080 -Host 'pode.example.com' -Protocol Http

    # enable error logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # setup negotiate auth
    New-PodeAuthScheme -Negotiate -KeytabPath '.\pode-user.keytab' | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($claim)
        $claim | Out-Default
        $claim.Identity.Name | Out-Default
        return @{ User = $claim }
    }

    # example JSON route, requiring negotiate auth
    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        Write-PodeJsonResponse -Value @{ result = 'hello' }
    }
}