if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

Server -Port 8086 {
    # can be hit by sending a POST request to "localhost:8086/api/test"
    Add-PodeRoute 'post' '/api/test' {
        param($res, $req, $data)
        Write-Host $data
        Write-JsonResponse @{ 'hello' = 'world'; } $res
    }

    # can be hit by sending a GET request to "localhost:8086/api/test"
    Add-PodeRoute 'get' '/api/test' {
        param($res, $req, $data)
        Write-Host $data
        Write-JsonResponse @{ 'hello' = 'world'; } $res
    }

    # starts the server listening on port 8086
    Start-PodeServer
}