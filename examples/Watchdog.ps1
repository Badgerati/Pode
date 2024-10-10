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

    Enable-PodeWatchdog -FilePath $filePath   -FileMonitoring -FileExclude "*.log"

    # Get-PodeWatchdogInfo -type Status

    Add-PodeRoute -PassThru -Method Get -Path '/listeners'   -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogInfo -type Listeners  )
    }

    Add-PodeRoute -PassThru -Method Get -Path '/requests'  -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogInfo -type Requests  )
    }

    Add-PodeRoute -PassThru -Method Get -Path '/status'  -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogInfo -type Status  )
    }

    Add-PodeRoute -PassThru -Method Get -Path '/signals'  -ScriptBlock {
        Write-PodeJsonResponse -StatusCode 200 -Value (Get-PodeWatchdogInfo -type Signals  )
    }


    Add-PodeRoute -PassThru -Method Post -Path '/restart'  -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchState -state Restart) }
    }

    Add-PodeRoute -PassThru -Method Post -Path '/stop'  -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchState -State Stop) }
    }

    Add-PodeRoute -PassThru -Method Post -Path '/start'   -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchState -State Start) }
    }


    Add-PodeRoute -PassThru -Method Post -Path '/kill'  -ScriptBlock {

        Write-PodeJsonResponse -StatusCode 200 -Value @{success = (Set-PodeWatchState -State Kill) }
    }

    # End of Routes
}