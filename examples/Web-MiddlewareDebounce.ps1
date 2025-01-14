<#
.SYNOPSIS
    PowerShell script to set up a Pode server with a debounce mechanism.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8080 and includes a debounce middleware.
    The debounce mechanism ensures that repeated requests to the same endpoint within a specified time window
    are blocked, reducing server load and preventing redundant processing. The script demonstrates three simple
    GET endpoints to test the debounce functionality.

.EXAMPLE
    To run the sample: ./HelloWorld/HelloWorld.ps1

    # Example of debouncing behavior:
    Invoke-RestMethod -Uri http://localhost:8080/1 -Method Get
    Invoke-RestMethod -Uri http://localhost:8080/1 -Method Get

    The second request to '/1' within 2 seconds will return an HTTP 429 (Too Many Requests).

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/HelloWorld/HelloWorld.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    # Get the path of the script being executed
    $ScriptPath = (Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
    # Get the parent directory of the script's path
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the specified path or the system
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch {
    # Handle errors during the module import
    throw
}

# Start the Pode server
Start-PodeServer {
    # Add an HTTP endpoint listening on localhost at port 8080
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Add debounce middleware with a 2-second timeout and a cleanup frequency of 20 seconds
    Add-PodeDebounce -DebounceTimeoutMilliseconds 2000 -CleanupIntervalSeconds 20 -ExpirationSeconds 60

    # Add three GET routes for testing debounce functionality
    Add-PodeRoute -Method Get -Path '/1' -ScriptBlock {
        # Respond with a text message for requests to '/1'
        Write-PodeTextResponse -Value 'Hello, debouncing from route /1!'
    }
    Add-PodeRoute -Method Get -Path '/2' -ScriptBlock {
        # Respond with a text message for requests to '/2'
        Write-PodeTextResponse -Value 'Hello, debouncing from route /2!'
    }
    Add-PodeRoute -Method Get -Path '/3' -ScriptBlock {
        # Respond with a text message for requests to '/3'
        Write-PodeTextResponse -Value 'Hello, debouncing from route /3!'
    }
}
