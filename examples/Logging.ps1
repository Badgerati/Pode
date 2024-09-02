<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with configurable logging, view engine, and various routes.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081, configures a view engine, and allows for different
    types of request logging (terminal, file, custom). It includes routes for serving a web page, simulating a
    server error, and downloading a file.

.EXAMPLE
    To run the sample: ./Logging.ps1

    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/error -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/download -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Logging.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>


param(
    [ValidateSet('Terminal', 'File', 'mylog', 'Syslog', 'EventViewer', 'Custom')]
    [string[]]
    $LoggingType = @(  'file', 'Custom', 'Syslog'),

    [switch]
    $Raw
)

try {
    #Determine the script path and Pode module path
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
Start-PodeServer -browse {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    Set-PodeViewEngine -Type Pode
    $logging = @()

    if ( $LoggingType -icontains 'terminal') {
        $logging += New-PodeLoggingMethod -Terminal
    }

    if ( $LoggingType -icontains 'file') {
        $logging += New-PodeLoggingMethod -File -Name 'general' -MaxDays 4 -Format Simple -ISO8601
        $requestLogging = New-PodeLoggingMethod -File -Name 'requests' -MaxDays 4
    }

    if ( $LoggingType -icontains 'custom') {
        $logging += New-PodeLoggingMethod -Custom -ArgumentList 'arg1', 'arg2', 'arg3'  -ScriptBlock {
            param($item, $arg1 , $arg2, $arg3, $rawItem)
            $item | Out-File './examples/logs/customLegacy.log' -Append
            $arg1 , $arg2, $arg3 -join ',' | Out-File './examples/logs/customLegacy_argumentList.log' -Append
            $rawItem | Out-File './examples/logs/customLegacy_rawItem.log' -Append
        }

        $logging += New-PodeLoggingMethod -Custom -UseRunspace -CustomOptions @{ 'opt1' = 'something'; 'opt2' = 'else' } -ScriptBlock {
            $item | Out-File './examples/logs/customWithRunspace.log' -Append
            $options | Out-File './examples/logs/customWithRunspace_options.log' -Append
            $rawItem | Out-File './examples/logs/customWithRunspace_rawItem.log' -Append
        }
    }

    if ( $LoggingType -icontains 'eventviewer') {
        $logging += New-PodeLoggingMethod -EventViewer
    }

    if ( $LoggingType -icontains 'syslog') {
        $logging += New-PodeLoggingMethod -syslog  -Server 127.0.0.1  -Transport UDP -AsUTC -ISO8601 -FailureAction Report
    }

    if ($logging.Count -eq 0) {
        throw 'No logging selected'
    }
    if ( $requestLogging) {
        $requestLogging | Enable-PodeRequestLogging
    }

    $logging | Enable-PodeTraceLogging -Raw:$Raw
    $logging | Enable-PodeErrorLogging -Raw:$Raw -Levels *
    $logging | Enable-PodeGeneralLogging -Name 'mylog' -Raw:$Raw

    Write-PodeLog -Name 'mylog' -Message 'just started' -Level 'Info'
    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeLog -Name  'mylog' -Message 'My custom log' -Level 'Info'
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        Disable-PodeRequestLogging
        Set-PodeResponseStatus -Code 500
    }

    Add-PodeRoute -Method Get -Path '/exception' -ScriptBlock {
        try {
            throw 'something happened'
        }
        catch {
            $_ | Write-PodeErrorLog
        }
        Set-PodeResponseStatus -Code 500
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

}
