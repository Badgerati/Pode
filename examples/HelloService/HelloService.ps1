<#
.SYNOPSIS
    PowerShell script to set up a Pode server with a simple GET endpoint.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8080. It includes a single route for GET requests
    to the root path ('/') that returns a simple text response.

.EXAMPLE
    To run the sample: ./HelloWorld/HelloWorld.ps1

    # HTML responses 'Hello, world!
    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/HelloWorld/HelloWorld.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

param(
    [switch]
    $Register,
    [switch]
    $Unregister,
    [switch]
    $Start,
    [switch]
    $Stop,
    [switch]
    $Query
)
try {
    # Get the path of the script being executed
    $ScriptPath = (Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
    # Get the parent directory of the script's path
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Check if the Pode module file exists in the specified path
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        # If the Pode module file exists, import it
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        # If the Pode module file does not exist, import the Pode module from the system
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch {
    # If there is any error during the module import, throw the error
    throw
}


if ($Register.IsPresent) {
    Register-PodeService -Name 'HelloService2' -Start
    exit
}
if ($Unregister.IsPresent) {
    Unregister-PodeService -Name 'HelloService2'
    exit
}
if ($Start.IsPresent) {
    Start-PodeService -Name 'HelloService2'
    exit
}

if ($Stop.IsPresent) {
    Stop-PodeService -Name 'HelloService2'
    exit
}

if ($Query.IsPresent) {
    Get-PodeService -Name 'HelloService2'
    exit
}
# Alternatively, you can directly import the Pode module from the system
# Import-Module Pode

# Start the Pode server
Start-PodeServer {
    # Add an HTTP endpoint listening on localhost at port 8080
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Add a route for GET requests to the root path '/'
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # Send a text response with 'Hello, world!'
        Write-PodeTextResponse -Value 'Hello, Service!'
    }
}
