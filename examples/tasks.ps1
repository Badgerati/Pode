$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer {

    Add-PodeEndpoint -Address * -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeTask -Name 'Test1' -ScriptBlock {
        'a string'
        4
        return @{ InnerValue = 'hey look, a value!' }
    }

    Add-PodeTask -Name 'Test2' -ScriptBlock {
        param($value)
        Start-Sleep -Seconds 10
        "a $($value) is never late, it arrives exactly when it means to" | Out-Default
    }

    # create a new timer via a route
    Add-PodeRoute -Method Get -Path '/api/task/sync' -ScriptBlock {
        $result = Invoke-PodeTask -Name 'Test1' -Wait
        Write-PodeJsonResponse -Value @{ Result = $result }
    }

    Add-PodeRoute -Method Get -Path '/api/task/sync2' -ScriptBlock {
        $task = Invoke-PodeTask -Name 'Test1'
        $result = ($task | Wait-PodeTask)
        Write-PodeJsonResponse -Value @{ Result = $result }
    }

    Add-PodeRoute -Method Get -Path '/api/task/async' -ScriptBlock {
        Invoke-PodeTask -Name 'Test2' -ArgumentList @{ value = 'wizard' } | Out-Null
        Write-PodeJsonResponse -Value @{ Result = 'jobs done' }
    }

}
