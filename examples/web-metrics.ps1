$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/uptime' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Restarts = (Get-PodeServerRestartCount)
            Uptime = @{
                Session = (Get-PodeServerUptime)
                Total = (Get-PodeServerUptime -Total)
            }
        }
    }

}