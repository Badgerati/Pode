$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

$outerfoo = 'outer-bar'
$outer_ken = 'Hello, there'

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
    $inner_ken = 'General Kenobi'

    # GET request for web page on "localhost:8090/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($e)

        $using:innerfoo | out-default
        $using:outerfoo | out-default
        $using:innerfoo | out-default

        $e.Method | out-default

        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    Add-PodeRoute -Method Get -Path '/random' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Message = "$($using:outer_ken) ... $($using:inner_ken)" }
    }

    Add-PodeTimer -Name 'empty' -Interval 60 -ScriptBlock {}

    Add-PodeRoute -Method Get -Path '/timer' -ScriptBlock {
        Add-PodeTimer -Name 'inner_timer' -Interval 5 -ScriptBlock {
            $using:innerfoo | Out-PodeHost
        }
    }
}