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
    middleware (session @{
        'Secret' = 'schwifty';
        'Name' = 'pode.sid';
        'Duration' = 120;
        'Rolling' = $true; # extend the duration each time
        'GenerateId' = {
            return [System.IO.Path]::GetRandomFileName()
        };
    })

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($s)
        $s.Session.Data.Views++
        view 'simple' -Data @{ 'numbers' = @($s.Session.Data.Views); }
    }

}