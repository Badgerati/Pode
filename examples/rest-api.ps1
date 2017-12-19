if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8086
Server -Port 8086 {

    # can be hit by sending a POST request to "localhost:8086/api/test"
    Add-PodeRoute 'post' '/api/test' {
        param($session)
        Write-Host $session.Data
        Write-JsonResponse @{ 'hello' = 'world'; }
    }

    # can be hit by sending a GET request to "localhost:8086/api/test"
    Add-PodeRoute 'get' '/api/test' {
        param($session)
        Write-Host $session.Data
        Write-JsonResponse @{ 'hello' = 'world'; }
    }

}