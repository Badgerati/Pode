$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 9090 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    $scheme = New-PodeAuthScheme -Name 'Negotiate' -Custom -ScriptBlock {
        $kf = [Kerberos.NET.Crypto.KeyTable]::new([System.IO.File]::ReadAllBytes("C:\temp\podekerb.keytab"))
        # $k = [Kerberos.NET.Crypto.KerberosKey]::new('<password>')
        # $v = [Kerberos.NET.KerberosValidator]::new($k)

        $header = Get-PodeHeader -Name 'Authorization'
        if ($null -eq $header) {
            return @{
                Message = 'No Authorization header found'
                Code = 401
                Headers = @{
                    'WWW-Authenticate' = 'Negotiate'
                }
            }
        }

        $ticketBytes = [System.Convert]::FromBase64String($header.Split(" ")[1])

        $a = [Kerberos.NET.KerberosAuthenticator]::new($kf)
        $v = [Kerberos.NET.KerberosValidator]::new($kf)

        $v.ValidateAfterDecrypt = 64
        $decrypted = $v.Validate($ticketBytes)

        # $a = [Kerberos.NET.KerberosAuthenticator]::new($v)
        $i = $a.Authenticate($header)
        # $i | out-default
        $i.Wait() | Out-Null

        $principal = [System.Security.Claims.ClaimsPrincipal]::new($i.Result)
        return @($principal)

        # return @([System.Security.Claims.ClaimsPrincipal]::new($i.Wait()))
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