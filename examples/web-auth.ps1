if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server {

    # listen on localhost:8085
    listen *:8085 http

    # set view engine to pode renderer
    engine pode

    # setup session details
    session @{ 'secret' = 'schwifty' }

    middleware {
        param($s)

        $v = $s.Session.Get($s.Request, 'pode-sid')
        if (![string]::IsNullOrWhiteSpace($v)) {
            $v | Out-Default
        }

        return $true
    }

    middleware {
        param($s)
        $s.Session.Set($s.Response, 'pode-sid', 'hello')
        return $true
    }

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($session)
        view 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}