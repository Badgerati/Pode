<#
.SYNOPSIS
    PowerShell script to set up a Pode server with various pages and error logging.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and provides several routes
    to display process and service information, as well as static views.

.PARAMETER Port
    The port number on which the server will listen. Default is 8081.

.EXAMPLE
    To run the sample: ./Web-SimplePages.ps1

    Invoke-RestMethod -Uri http://localhost:8081/Processes/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/Services/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/Index/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/File/ -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-SimplePages.ps1
    
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

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodePage -Name Processes -ScriptBlock { Get-Process }
    Add-PodePage -Name Services -ScriptBlock { Get-Service }
    Add-PodePage -Name Index -View 'simple'
    Add-PodePage -Name File -FilePath '.\views\simple.pode' -Data @{ 'numbers' = @(1, 2, 3); }

}