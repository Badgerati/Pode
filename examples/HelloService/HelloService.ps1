<#
.SYNOPSIS
    PowerShell script to register, start, stop, query, and unregister a Pode service, with a basic server setup.

.DESCRIPTION
    This script manages a Pode service named 'Hello Service' with commands to register, start, stop, query,
    and unregister the service. Additionally, it sets up a Pode server that listens on port 8080 and includes
    a simple GET route that responds with 'Hello, Service!'.

    The script checks if the Pode module exists locally and imports it; otherwise, it imports Pode from the system.

    To test the Pode server's HTTP endpoint:
        Invoke-RestMethod -Uri http://localhost:8080/ -Method Get
        # Response: 'Hello, Service!'

.PARAMETER Register
    Registers the 'Hello Service' with Pode.

.PARAMETER Password
    A secure password for the service account (Windows only). If omitted, the service account will be 'NT AUTHORITY\SYSTEM'.

.PARAMETER Unregister
    Unregisters the 'Hello Service' from Pode. Use with the -Force switch to forcefully unregister the service.

.PARAMETER Force
    Used with the -Unregister parameter to forcefully unregister the service.

.PARAMETER Start
    Starts the 'Hello Service'.

.PARAMETER Stop
    Stops the 'Hello Service'.

.PARAMETER Query
    Queries the status of the 'Hello Service'.

.PARAMETER Suspend
    Suspend the 'Hello Service'.

.PARAMETER Resume
    Resume the 'Hello Service'.

.PARAMETER Restart
    Restart the 'Hello Service'.

.EXAMPLE
    Register the service:
        ./HelloService.ps1 -Register

.EXAMPLE
    Start the service:
        ./HelloService.ps1 -Start

.EXAMPLE
    Query the service:
        ./HelloService.ps1 -Query

.EXAMPLE
    Stop the service:
        ./HelloService.ps1 -Stop

.EXAMPLE
    Unregister the service:
        ./HelloService.ps1 -Unregister -Force

.LINK
      https://github.com/Badgerati/Pode/blob/develop/examples/HelloService/HelloService.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

[CmdletBinding(DefaultParameterSetName = 'Inbuilt')]
param(
    [Parameter(  ParameterSetName = 'Inbuilt')]
    [int]
    $Port = 8080,

    [Parameter(Mandatory = $true, ParameterSetName = 'Register')]
    [switch]
    $Register,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register', ValueFromPipeline = $true )]
    [securestring]
    $Password,

    [Parameter(Mandatory = $true, ParameterSetName = 'Unregister')]
    [switch]
    $Unregister,

    [Parameter(  ParameterSetName = 'Unregister')]
    [switch]
    $Force,

    [Parameter(  ParameterSetName = 'Start')]
    [switch]
    $Start,

    [Parameter(  ParameterSetName = 'Stop')]
    [switch]
    $Stop,

    [Parameter(  ParameterSetName = 'Query')]
    [switch]
    $Query,

    [Parameter(  ParameterSetName = 'Suspend')]
    [switch]
    $Suspend,

    [Parameter(  ParameterSetName = 'Resume')]
    [switch]
    $Resume,

    [Parameter(  ParameterSetName = 'Restart')]
    [switch]
    $Restart

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


if ( $Register.IsPresent) {
    Register-PodeService -Name 'Hello Service' -ParameterString "-Port $Port" -Password $Password -Agent
    exit
}
if ( $Unregister.IsPresent) {
    Unregister-PodeService -Name 'Hello Service' -Force:$Force
    exit
}
if ($Start.IsPresent) {
    Start-PodeService -Name 'Hello Service'
    exit
}

if ($Stop.IsPresent) {
    Stop-PodeService -Name 'Hello Service'
    exit
}

if ($Suspend.IsPresent) {
    Suspend-PodeService -Name 'Hello Service'
    exit
}

if ($Resume.IsPresent) {
    Resume-PodeService -Name 'Hello Service'
    exit
}

if ($Query.IsPresent) {
    Get-PodeService -Name 'Hello Service'
    exit
}

if ($Restart.IsPresent) {
    Restart-PodeService -Name 'Hello Service'
    exit
}

# Start the Pode server
Start-PodeServer {
    New-PodeLoggingMethod -File -Name 'errors' -MaxDays 4 -Path './logs' | Enable-PodeErrorLogging -Levels Informational

    # Add an HTTP endpoint listening on localhost at port 8080
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http

    # Add a route for GET requests to the root path '/'
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # Send a text response with 'Hello, world!'
        Write-PodeTextResponse -Value 'Hello, Service!'
    }
}
