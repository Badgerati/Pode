$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http -AllowClientCertificate
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