if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

Import-Module Pode

# create a server, and start listening on port 8085
Server -Threads 2 {

    # listen on *:8085
    listen *:8085 http

    # set view engine to pode renderer
    engine pode

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        param($session)
        view 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    route 'get' '/error' {
        param($session)
        status 500
    }

    # PUT update a file to trigger monitor
    route 'put' '/file' {
        param($session)
        'Hello, world!' | Out-File -FilePath "$($PodeSession.Server.Root)/file.txt" -Append -Force
    }

} -FileMonitor
