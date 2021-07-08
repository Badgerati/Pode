$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    New-PodeLockable -Name 'TestLock'

    Add-PodeRoute -Method Get -Path '/custom-route1' -ScriptBlock {
        Get-PodeLockable -Name 'TestLock' | Lock-PodeObject -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/custom-route2' -ScriptBlock {
        Get-PodeLockable -Name 'TestLock' | Lock-PodeObject -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/global-route1' -ScriptBlock {
        Lock-PodeObject -Object $WebEvent.Lockable -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/global-route2' -ScriptBlock {
        Get-PodeLockable -Name 'TestLock' | Lock-PodeObject -CheckGlobal -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

}