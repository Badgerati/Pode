try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
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

Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    $cron = New-PodeCron -Every Minute -Interval 2
    Add-PodeSchedule -Name 'example' -Cron $cron -ScriptBlock {
        'Hi there!' | Out-Default
    }

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 1 }
    }

}