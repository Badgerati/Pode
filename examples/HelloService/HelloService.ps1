<#
.SYNOPSIS
    PowerShell script to register, manage, and set up a Pode service named '$ServiceName'.

.DESCRIPTION
    This script provides commands to register, start, stop, query, suspend, resume, restart, and unregister a Pode service named '$ServiceName'.
    It also sets up a Pode server that listens on the specified port (default 8080) and includes a basic GET route that responds with 'Hello, Service!'.

    The script checks if the Pode module exists locally and imports it; otherwise, it imports Pode from the system.

    To test the Pode server's HTTP endpoint:
        Invoke-RestMethod -Uri http://localhost:8080/ -Method Get
        # Response: 'Hello, Service!'

.PARAMETER ServiceName
    Name of the service to register (Default 'Hello Service').

.PARAMETER Register
    Registers the $ServiceName with Pode.

.PARAMETER Password
    A secure password for the service account (Windows only). If omitted, the service account will be 'NT AUTHORITY\SYSTEM'.

    .PARAMETER Daemon
    Defines the service as an Daemon instead of a Agent.(macOS only)

.PARAMETER Unregister
    Unregisters the $ServiceName from Pode. Use with the -Force switch to forcefully unregister the service.

.PARAMETER Force
    Used with the -Unregister parameter to forcefully unregister the service.

.PARAMETER Start
    Starts the $ServiceName.

.PARAMETER Stop
    Stops the $ServiceName.

.PARAMETER Query
    Queries the status of the $ServiceName.

.PARAMETER Suspend
    Suspends the $ServiceName.

.PARAMETER Resume
    Resumes the $ServiceName.

.PARAMETER Restart
    Restarts the $ServiceName.

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

    [Parameter(  ParameterSetName = 'Inbuilt')]
    [string]
    $ServiceName = 'Hello Service',

    [Parameter(Mandatory = $true, ParameterSetName = 'Register')]
    [switch]
    $Register,

    [Parameter(Mandatory = $false, ParameterSetName = 'Register', ValueFromPipeline = $true )]
    [securestring]
    $Password,

    [Parameter(ParameterSetName = 'Register')]
    [switch]
    $Daemon,

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
    Register-PodeService -Name $ServiceName -ParameterString "-Port $Port" -Password $Password -Agent:!$Daemon
    exit
}
if ( $Unregister.IsPresent) {
    Unregister-PodeService -Name $ServiceName -Force:$Force
    exit
}
if ($Start.IsPresent) {
    Start-PodeService -Name $ServiceName
    exit
}

if ($Stop.IsPresent) {
    Stop-PodeService -Name $ServiceName
    exit
}

if ($Suspend.IsPresent) {
    Suspend-PodeService -Name $ServiceName
    exit
}

if ($Resume.IsPresent) {
    Resume-PodeService -Name $ServiceName
    exit
}

if ($Query.IsPresent) {
    Get-PodeService -Name $ServiceName
    exit
}

if ($Restart.IsPresent) {
    Restart-PodeService -Name $ServiceName
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
