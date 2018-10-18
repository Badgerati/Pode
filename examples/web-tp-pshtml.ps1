$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server -Threads 2 {

    # listen on localhost:8085
    listen *:8085 http

    # log requests to the terminal
    logger terminal

    # import the PSHTML module to each runspace
    import pshtml

    # set view engine to PSHTML renderer
    engine ps1 {
        param($path, $data)
        return (. $path $data) -join "`r`n"
    }

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        view 'index' -Data @{ 'numbers' = @(1, 2, 3); }
    }

} -FileMonitor