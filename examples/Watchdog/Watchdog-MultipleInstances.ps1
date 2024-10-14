<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with multiple Pode Watchdog instances for process monitoring.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8082 and configures two Pode Watchdog instances to monitor the same script.
    It configures logging for the Watchdog service and monitors the provided script file, excluding `.log` files for both instances.
    The script dynamically loads the Pode module and enables multiple instances of the Pode Watchdog service for monitoring.

.EXAMPLE
    To run the sample: ./Watchdog-MultipleInstances.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Waatchdog/Watchdog-MultipleInstances.ps1

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

    # Set up logging for the Watchdog service with a 4-day retention period
    New-PodeLoggingMethod -File -Name 'watchdog' -MaxDays 4 | Enable-PodeErrorLogging

    # Enable the first Pode Watchdog instance to monitor the script file, excluding .log files
    Enable-PodeWatchdog -FilePath $filePath -FileMonitoring -Parameters @{Port = 8080 }  -FileExclude '*.log' -Name 'watch01'

    # Enable the second Pode Watchdog instance to monitor the script file, excluding .log files
    Enable-PodeWatchdog -FilePath $filePath -FileMonitoring -Parameters @{Port = 8081 } -FileExclude '*.log' -Name 'watch02'
}
