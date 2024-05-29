$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

<#
# Invoke-RestMethod -Uri 'http://pode.example.com:8080' -UseDefaultCredentials
#>

Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address localhost -Port 8080 -Host 'pode.example.com' -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    New-PodeAuthScheme -Negotiate -KeytabPath 'C:\temp\pode-user.keytab' | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($identity)
        $identity | out-default
        return @{ User = $identity }
    }

    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        Write-PodeJsonResponse -Value @{ result = 'hello' }
    }
}