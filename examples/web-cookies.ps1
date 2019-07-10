$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8090
Start-PodeServer -Threads 2 {

    # listen on localhost:8090
    Add-PodeEndpoint -Endpoint localhost:8090 -Protocol HTTP

    # set view engine to pode renderer
    Set-PodeViewEngine -Type HTML

    # set a global cookie secret
    Set-PodeCookieSecret -Value 'pi' -Global

    # GET request to set/extend a cookie for the date of the request
    route get '/' {
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
    route get '/remove' {
        Remove-PodeCookie -Name 'current-date'
    }

    # GET request to check to signage of the date cookie
    route get '/check' {
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