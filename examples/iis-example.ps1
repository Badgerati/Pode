# Doesn't look to be the right example

try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeTask -Name 'Test' -ScriptBlock {
        Start-Sleep -Seconds 10
        'a message is never late, it arrives exactly when it means to' | Out-Default
    }

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Message = 'Hello' }
        $WebEvent.Request | out-default
    }

    Add-PodeRoute -Method Get -Path '/run-task' -ScriptBlock {
        Invoke-PodeTask -Name 'Test' | Out-Null
        Write-PodeJsonResponse -Value @{ Result = 'jobs done' }
    }

}