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

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Http
    $filePath = '.\Logging.ps1'
    New-PodeLoggingMethod -File -Name 'watchdog' -MaxDays 4 | Enable-PodeErrorLogging
    
    Enable-PodeWatchdog -FilePath $filePath   -FileMonitoring

    Get-PodeWatchdogInfo -type Status -Raw

    Add-PodeRoute -PassThru -Method Get -Path '/listeners'   -ScriptBlock {
     #   Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogInfo -type Listeners -Raw)
    }

    Add-PodeRoute -PassThru -Method Get -Path '/requests'  -ScriptBlock {
  #      Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogInfo -type Requests -Raw)
    }

    Add-PodeRoute -PassThru -Method Get -Path '/status'  -ScriptBlock {
   #     Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogInfo -type Status -Raw)
    }


 <#   # Monitor the process if needed
    if ($process) {
        Write-Output "Process started with ID: $($process.Id)"

        # Ask user if they want to close the process
        $userInput = Read-Host -Prompt 'Do you want to close the process before waiting for it to complete? (y/n)'

        if ($userInput -eq 'y') {
            # Stop the Pode watchdog process if the user chooses 'y'
            Stop-PodeWatchdog
        }
        Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
        Write-Output "Process has exited with code: $($process.ExitCode)"
    }
    else {
        Write-Error 'Failed to start the PowerShell process with the scriptblock.'
    }#>
}