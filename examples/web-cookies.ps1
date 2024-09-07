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

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # set view engine to pode renderer
    Set-PodeViewEngine -Type HTML

    # set a global cookie secret
    Set-PodeCookieSecret -Value 'pi' -Global

    # GET request to set/extend a cookie for the date of the request
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $cookieName = 'current-date'

        if (Test-PodeCookie -Name $cookieName) {
            Update-PodeCookieExpiry -Name $cookieName -Duration 7200 | Out-Null
        }
        else {
            $s = Get-PodeCookieSecret -Global
            Set-PodeCookie -Name $cookieName -Value ([datetime]::UtcNow) -Duration 7200 -Secret $s | Out-Null
        }

        Write-PodeViewResponse -Path 'simple'
    }

    # GET request to remove the date cookie
    Add-PodeRoute -Method Get -Path '/remove' -ScriptBlock {
        Remove-PodeCookie -Name 'current-date'
    }

    # GET request to check to signage of the date cookie
    Add-PodeRoute -Method Get -Path '/check' -ScriptBlock {
        $cookieName = 'current-date'

        $s = Get-PodeCookieSecret -Global
        $c1 = Get-PodeCookie -Name $cookieName
        $c2 = Get-PodeCookie -Name $cookieName -Secret $s
        $ch = Test-PodeCookieSigned -Name $cookieName -Secret $s

        Write-PodeJsonResponse -Value @{
            'SignedValue' = $c1.Value;
            'UnsignedValue' = $c2.Value;
            'Valid' = $ch;
        }
    }

}