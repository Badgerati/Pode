$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

Start-PodeServer {

    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http

    $cron = New-PodeCron -Every Minute -Interval 2
    Add-PodeSchedule -Name 'example' -Cron $cron -ScriptBlock {
        'Hi there!' | Out-Default
    }

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 1 }
    }

}