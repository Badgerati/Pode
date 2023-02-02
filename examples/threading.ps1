param(
    [Parameter()]
    [int]
    $Port = 8090
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
# Demostrates Lockables, Mutexes, and Semaphores
#>

Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address * -Port $Port -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging


    # custom locks
    New-PodeLockable -Name 'TestLock'

    Add-PodeRoute -Method Get -Path '/lock/custom/route1' -ScriptBlock {
        Lock-PodeObject -Name 'TestLock' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/lock/custom/route2' -ScriptBlock {
        Lock-PodeObject -Name 'TestLock' -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

    # global locks
    Add-PodeRoute -Method Get -Path '/lock/global/route1' -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/lock/global/route2' -ScriptBlock {
        Get-PodeLockable -Name 'TestLock' | Lock-PodeObject -CheckGlobal -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }


    # self mutex
    New-PodeMutex -Name 'SelfMutex'

    Add-PodeRoute -Method Get -Path '/mutex/self/route1' -ScriptBlock {
        Use-PodeMutex -Name 'SelfMutex' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/mutex/self/route2' -ScriptBlock {
        Use-PodeMutex -Name 'SelfMutex' -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

    # local mutex
    New-PodeMutex -Name 'LocalMutex' -Scope Local

    Add-PodeRoute -Method Get -Path '/mutex/local/route1' -ScriptBlock {
        Use-PodeMutex -Name 'LocalMutex' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/mutex/local/route2' -ScriptBlock {
        Use-PodeMutex -Name 'LocalMutex' -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

    # global mutex
    New-PodeMutex -Name 'GlobalMutex' -Scope Global

    Add-PodeRoute -Method Get -Path '/mutex/global/route1' -ScriptBlock {
        Use-PodeMutex -Name 'GlobalMutex' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/mutex/global/route2' -ScriptBlock {
        Use-PodeMutex -Name 'GlobalMutex' -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }


    # self semaphore
    New-PodeSemaphore -Name 'SelfSemaphore'

    Add-PodeRoute -Method Get -Path '/semaphore/self/route1' -ScriptBlock {
        Use-PodeSemaphore -Name 'SelfSemaphore' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/semaphore/self/route2' -ScriptBlock {
        Use-PodeSemaphore -Name 'SelfSemaphore' -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

    # local semaphore
    New-PodeSemaphore -Name 'LocalSemaphore' -Scope Local

    Add-PodeRoute -Method Get -Path '/semaphore/local/route1' -ScriptBlock {
        Use-PodeSemaphore -Name 'LocalSemaphore' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/semaphore/local/route2' -ScriptBlock {
        Use-PodeSemaphore -Name 'LocalSemaphore' -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

    # global semaphore
    New-PodeSemaphore -Name 'GlobalSemaphore' -Scope Global -Count 1

    Add-PodeRoute -Method Get -Path '/semaphore/global/route1' -ScriptBlock {
        Use-PodeSemaphore -Name 'GlobalSemaphore' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    Add-PodeRoute -Method Get -Path '/semaphore/global/route2' -ScriptBlock {
        Use-PodeSemaphore -Name 'GlobalSemaphore' -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }

}