$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

$outerfoo = 'outer-bar'

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8090
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    $innerfoo = 'inner-bar'

    # GET request for web page on "localhost:8090/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($e)

        $using:innerfoo | out-default
        $using:outerfoo | out-default

        $e.Method | out-default

        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

}