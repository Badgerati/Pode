$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 9090 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    $scheme = New-PodeAuthScheme -Name 'Negotiate' -Custom -ScriptBlock {
        $k = [Kerberos.NET.Crypto.KerberosKey]::new('<password>')
        $v = [Kerberos.NET.KerberosValidator]::new($k)

        $header = Get-PodeHeader -Name 'Authorization'
        if ($null -eq $header) {
            return @{
                Message = 'No Authorization header found'
                Code = 401
            }
        }

        $a = [Kerberos.NET.KerberosAuthenticator]::new($v)
        $i = $a.Authenticate($header)
        $i | out-default

        return @([System.Security.Claims.ClaimsPrincipal]::new($i.Wait()))
    }

    $scheme | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($identity)
        $identity | out-default
        return @{ User = $identity }
    }

    Add-PodeRoute -Method Get -Path '/' -Authentication Login -ScriptBlock {
        Write-PodeJsonResponse -Value @{ result = 'hello' }
    }
}