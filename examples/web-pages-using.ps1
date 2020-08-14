$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

$outerfoo = 'outer-bar'
$outer_ken = 'Hello, there'

function Write-MyOuterResponse
{
    Write-PodeJsonResponse -Value @{ Message = 'From an outer function' }
}

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8090
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # load file funcs
    Use-PodeScript -Path ./modules/imported-funcs.ps1

    $innerfoo = 'inner-bar'
    $inner_ken = 'General Kenobi'

    function Write-MyInnerResponse
    {
        Write-PodeJsonResponse -Value @{ Message = 'From an inner function' }
    }

    New-PodeMiddleware -ScriptBlock {
        "M1: $($using:outer_ken) ... $($using:inner_ken)" | Out-Default
        return $true
    } |  Add-PodeMiddleware -Name 'TestUsingMiddleware1'

    Add-PodeMiddleware -Name 'TestUsingMiddleware2' -ScriptBlock {
        "M2: $($using:outer_ken) ... $($using:inner_ken)" | Out-Default
        return $true
    }

    # GET request for web page on "localhost:8090/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($e)

        $using:innerfoo | Out-Default
        $using:outerfoo | Out-Default
        $using:innerfoo | Out-Default

        $e.Method | Out-Default

        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    Add-PodeRoute -Method Get -Path '/random' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Message = "$($using:outer_ken) ... $($using:inner_ken)" }
    }

    Add-PodeRoute -Method Get -Path '/inner-func' -ScriptBlock {
        Write-MyInnerResponse
    }

    Add-PodeRoute -Method Get -Path '/outer-func' -ScriptBlock {
        Write-MyOuterResponse
    }

    Add-PodeRoute -Method Get -Path '/greetings' -ScriptBlock {
        Write-MyGreeting
    }

    Add-PodeRoute -Method Get -Path '/sub-greetings' -ScriptBlock {
        Write-MySubGreeting
    }

    Add-PodeTimer -Name 'empty' -Interval 60 -ScriptBlock {}

    Add-PodeRoute -Method Get -Path '/timer' -ScriptBlock {
        Add-PodeTimer -Name 'inner_timer' -Interval 5 -ScriptBlock {
            $using:innerfoo | Out-PodeHost
        }
    }
}