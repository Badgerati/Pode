<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with a Pode Watchdog for process monitoring.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8082 and monitors a script using the Pode Watchdog service.
    It configures logging for the Watchdog service and monitors the provided script file, excluding `.log` files.
    The script dynamically loads the Pode module and sets up basic process monitoring using the Pode Watchdog.

.EXAMPLE
    To run the sample: ./Watchdog-Sample.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Waatchdog/Watchdog-SingleInstance.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>


try {
    # Determine paths for the Pode module
    $watchdogPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $podePath = Split-Path -Parent -Path (Split-Path -Parent -Path $watchdogPath)

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
    # Define a simple HTTP endpoint on localhost:8082
    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Http

    # Path to the monitored script
    $filePath = "$($watchdogPath)/monitored.ps1"

    # Enable the Pode Watchdog to monitor the script file, excluding .log files
    Enable-PodeWatchdog -FilePath $filePath -FileMonitoring -FileExclude '*.log' -Name 'watch01'

}
