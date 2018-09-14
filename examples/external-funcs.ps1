$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server {

    # listen on localhost:8085
    listen *:8085 http

    # include the external function module
    script './modules/external-funcs.psm1'

    # GET request for "localhost:8085/"
    route 'get' '/' {
        param($session)
        json @{ 'result' = (Get-Greeting) }
    }

} -FileMonitor