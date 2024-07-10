<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with various lock mechanisms including custom locks, mutexes, and semaphores.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and demonstrates the usage of lockables, mutexes, and semaphores for thread synchronization.
    It includes routes that showcase the behavior of these synchronization mechanisms in different scopes (self, local, and global).
    The server provides multiple routes to test custom locks, mutexes, and semaphores by simulating delays and concurrent access.

.PARAMETER Port
    The port number on which the Pode server will listen. Default is 8081.

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [Parameter()]
    [int]
    $Port = 8081
)
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

# or just:
# Import-Module Pode

<#
# Demostrates Lockables, Mutexes, and Semaphores
#>

Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http
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