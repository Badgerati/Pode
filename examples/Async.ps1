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

Start-PodeServer -Threads 1 {

    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    <#   Add-PodeRoute -Method Get -Path '/async1' -async  -ScriptBlock {
        param($WebEvent, $id)
        try {
            $PodeContext.AsyncRoutes.Results[$id].State = 'Running'

            Write-PodeHost $WebEvent.Parameters -Explode
            #  Write-PodeHost    $PodeContext.AsyncRoutes.Results -Explode
            Write-PodeHost      $PodeContext.AsyncRoutes.Results[$id] -Explode
            Start-Sleep 40
            return @{ InnerValue = 'hey look, a value!' }

        }
        catch {
            $PodeContext.AsyncRoutes.Results[$id].State = 'Failed'
            $_ | Write-PodeErrorLog
            $PodeContext.AsyncRoutes.Results[$id].Error = $_
            return
        }
        finally {
            if ( $PodeContext.AsyncRoutes.Results[$id].State -eq 'Running') {
                $PodeContext.AsyncRoutes.Results[$id].State = 'Completed'
            }
            $PodeContext.AsyncRoutes.Results[$id].CompletedTime = [datetime]::UtcNow
        }
    }#>

    Add-PodeRoute -Method Get -Path '/async1' -async  -ScriptBlock {
        #    Write-PodeHost $WebEvent.Parameters -Explode
        #  Write-PodeHost    $PodeContext.AsyncRoutes.Results -Explode
        #     Write-PodeHost      $PodeContext.AsyncRoutes.Results[$id] -Explode
        Start-Sleep 40
        return @{ InnerValue = 'hey look, a value!' }
    }


    Add-PodeRoute -Method Get -Path '/getasync'   -ScriptBlock {
        $id = $WebEvent.Query['id']
        #   write-podehost      $PodeContext.AsyncRoutes.Results[$id]  -Explode
        #    write-podehost      $PodeContext.AsyncRoutes.Results[$id].Runspace.Handler  -Explode
        $taskSummary = @{
            ID            = $PodeContext.AsyncRoutes.Results[$id].ID
            StartingTime  = $PodeContext.AsyncRoutes.Results[$id].StartingTime
            Result        = $null #$PodeContext.AsyncRoutes.Results[$id].result
            CompletedTime = $PodeContext.AsyncRoutes.Results[$id].CompletedTime
            Task          = $PodeContext.AsyncRoutes.Results[$id].Task
            State         = $PodeContext.AsyncRoutes.Results[$id].State

        }

        if ($PodeContext.AsyncRoutes.Results[$id].Runspace.Handler.IsCompleted) {
            $taskSummary.Result = $PodeContext.AsyncRoutes.Results[$id].result
            #  $taskSummary.Result = 'completed'
        }

        Write-PodeJsonResponse -StatusCode 200 -Value $taskSummary

    }


}