<#
.SYNOPSIS
    Script to manage multiple Pode services and set up a basic Pode server.

.DESCRIPTION
    This script registers, starts, stops, queries, and unregisters multiple Pode services based on the specified hashtable.
    Additionally, it sets up a Pode server that listens on a defined port and includes routes to handle incoming HTTP requests.

    The script checks if the Pode module exists in the local path and imports it; otherwise, it uses the system-wide Pode module.

.PARAMETER Register
    Registers all services specified in the hashtable.

.PARAMETER Unregister
    Unregisters all services specified in the hashtable. Use with -Force to force unregistration.

.PARAMETER Force
    Forces unregistration when used with the -Unregister parameter.

.PARAMETER Start
    Starts all services specified in the hashtable.

.PARAMETER Stop
    Stops all services specified in the hashtable.

.PARAMETER Query
    Queries the status of all services specified in the hashtable.

.PARAMETER Suspend
    Suspend the 'Hello Service'.

.PARAMETER Resume
    Resume the 'Hello Service'.

.PARAMETER Restart
    Restart the 'Hello Service'.

.EXAMPLE
    Register all services:
        ./HelloServices.ps1 -Register

.EXAMPLE
    Start all services:
        ./HelloServices.ps1 -Start

.EXAMPLE
    Query the status of all services:
        ./HelloServices.ps1 -Query

.EXAMPLE
    Stop all services:
        ./HelloServices.ps1 -Stop

.EXAMPLE
    Forcefully unregister all services:
        ./HelloServices.ps1 -Unregister -Force

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/HelloService/HelloServices.ps1

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
$services=@{
    'HelloService1'=8081
    'HelloService2'=8082
    'HelloService3'=8083
}

if ( $Register.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { Register-PodeService -Name $($_.Key) -ParameterString "-Port $($_.Value)" }
    exit
}
if ( $Unregister.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { try{Unregister-PodeService -Name $($_.Key) -Force:$Force }catch{Write-Error -Exception $_.Exception}}
    exit
}
if ($Start.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { Start-PodeService -Name $($_.Key) }
    exit
}

if ($Stop.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { Stop-PodeService -Name $($_.Key) }
    exit
}

if ($Query.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { Get-PodeService -Name $($_.Key) }
    exit
}

if ($Resume.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { Resume-PodeService -Name $($_.Key) }
    exit
}

if ($Query.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { Get-PodeService -Name $($_.Key) }
    exit
}

if ($Restart.IsPresent) {
    $services.GetEnumerator() | ForEach-Object { Restart-PodeService -Name $($_.Key) }
    exit
}

# Start the Pode server
Start-PodeServer {
    New-PodeLoggingMethod -File -Name "errors-$port" -MaxDays 4 -Path './logs' | Enable-PodeErrorLogging

    # Add an HTTP endpoint listening on localhost at port 8080
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http

    # Add a route for GET requests to the root path '/'
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # Send a text response with 'Hello, world!'
        Write-PodeTextResponse -Value 'Hello, Service!'
    }
}
