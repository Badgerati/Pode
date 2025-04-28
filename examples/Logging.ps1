<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with configurable logging, view engine, and various routes.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081, configures a view engine, and allows for different
    types of request logging (terminal, file, custom). It includes routes for serving a web page, simulating a
    server error, and downloading a file.

.EXAMPLE
    To run the sample: ./Logging.ps1

    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/error -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/download -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Logging.ps1

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

$LOGGING_TYPE = 'terminal' # Terminal, File, Custom

# create a server, and start listening on port 8081
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    Set-PodeViewEngine -Type Pode

    switch ($LOGGING_TYPE.ToLowerInvariant()) {
        'terminal' {
            New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
        }

        'file' {
            New-PodeLoggingMethod -File -Name 'requests' -MaxDays 4 | Enable-PodeRequestLogging
        }

        'custom' {
            $type = New-PodeLoggingMethod -Custom -ScriptBlock {
                param($item)
                # send request row to S3
            }

            $type | Enable-PodeRequestLogging
        }
    }

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        Set-PodeResponseStatus -Code 500
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

}