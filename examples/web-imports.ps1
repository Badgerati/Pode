param (
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Server -Threads 2 {

    # listen on localhost:8085
    listen localhost:$Port http

    # import modules
    import eps

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        Get-Module | Out-Default
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

} -FileMonitor