<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with various routes with example localisation.

.DESCRIPTION
    A sample PowerShell script to set up a Pode server with various routes with example localisation.

.PARAMETER Port
    The port number on which the server will listen. Default is 8081.

.EXAMPLE
    To run the sample: ./Web-Pages.ps1

    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-PagesLocale.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [int]
    $Port = 8081
)

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
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http

    # log errors to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # enable localisation
    # Initialize-PodeLocale -HeaderName 'X-PODE-CULTURE'

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $datetime = [datetime]::Now
        $number = 13373.14
        Write-PodeTextResponse -Value "[$($datetime:datetime)]: $($locale:HelloWorld) > $($number:number)"
    }

    Add-PodeStaticRoute -Path '/browse' -Source (Get-PodeServerPath) -FileBrowser
}