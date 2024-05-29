$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    New-PodeAuthScheme -Negotiate -KeyTabPath 'C:\temp\podekerb.keytab' | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($identity)
        $identity | out-default
        return @{ User = $identity }
    }

    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        Write-PodeJsonResponse -Value @{ result = 'hello' }
    }
}