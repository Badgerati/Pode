<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with various routes, middleware, and custom functions.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081. It demonstrates how to handle GET requests,
    use middleware, export and use custom functions, and set up timers. The script includes examples of
    using `$using:` scope for variables in script blocks and middleware.

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

$outerfoo = 'outer-bar'
$outer_ken = 'Hello, there'

function Write-MyOuterResponse {
    Write-PodeJsonResponse -Value @{ Message = 'From an outer function' }
}

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {
    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # load file funcs
    Use-PodeScript -Path ./modules/Imported-Funcs.ps1

    $innerfoo = 'inner-bar'
    $inner_ken = 'General Kenobi'

    function Write-MyInnerResponse {
        Write-PodeJsonResponse -Value @{ Message = 'From an inner function' }
    }

    Export-PodeFunction -Name 'Write-MyOuterResponse', 'Write-MyInnerResponse'

    New-PodeMiddleware -ScriptBlock {
        "M1: $($using:outer_ken) ... $($using:inner_ken)" | Out-Default
        return $true
    } | Add-PodeMiddleware -Name 'TestUsingMiddleware1'

    Add-PodeMiddleware -Name 'TestUsingMiddleware2' -ScriptBlock {
        "M2: $($using:outer_ken) ... $($using:inner_ken)" | Out-Default
        return $true
    }

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $using:innerfoo | Out-Default
        $using:outerfoo | Out-Default
        $using:innerfoo | Out-Default

        $WebEvent.Method | Out-Default

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