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

Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

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