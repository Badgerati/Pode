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
    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Http
    $filePath = "$($watchdogPath)/monitored.ps1"

    New-PodeLoggingMethod -File -Name 'watchdog' -MaxDays 4 | Enable-PodeErrorLogging

    Enable-PodeWatchdog -FilePath $filePath -FileMonitoring -FileExclude '*.log'  -Name 'watch01'

    # Get-PodeWatchdogProcessMetric -type Status

    Add-PodeRoute -PassThru -Method Get -Path '/monitor/listeners'   -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Listeners  )
    }

    Add-PodeRoute -PassThru -Method Get -Path '/monitor/requests'  -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Requests  )
    }

    Add-PodeRoute -PassThru -Method Get -Path '/monitor/status'  -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Status  )
    }

    Add-PodeRoute -PassThru -Method Get -Path '/monitor/signals'  -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01' -type Signals  )
    }

    Add-PodeRoute -PassThru -Method Get -Path '/monitor'  -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogProcessMetric -Name 'watch01'   )
    }


    Add-PodeRoute -PassThru -Method Post -Path '/cmd/restart'  -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchdogProcessState -Name 'watch01' -state Restart) }
    }

    Add-PodeRoute -PassThru -Method Post -Path '/cmd/reset'  -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchdogProcessState -Name 'watch01' -state Reset) }
    }
    Add-PodeRoute -PassThru -Method Post -Path '/cmd/stop'  -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Stop) }
    }

    Add-PodeRoute -PassThru -Method Post -Path '/cmd/start'   -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Start) }
    }


    Add-PodeRoute -PassThru -Method Post -Path '/cmd/halt'  -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchdogProcessState -Name 'watch01' -State Halt) }
    }

    Test-PodeWatchdog -Name  'watch01'

    # End of Routes
}