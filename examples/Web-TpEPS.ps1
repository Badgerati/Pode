<#
.SYNOPSIS
    PowerShell script to set up a Pode server with EPS view engine.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port, logs requests to the terminal,
    and uses the EPS renderer for serving web pages.

.EXAMPLE
    To run the sample: ./Web-TpEPS.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-TpEPS.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }

    Import-Module -Name 'EPS' -ErrorAction Stop
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging

    # set view engine to EPS renderer
    Set-PodeViewEngine -Type EPS -ScriptBlock {
        param($path, $data)
        $template = Get-Content -Path $path -Raw -Force

        if ($null -eq $data) {
            return (Invoke-EpsTemplate -Template $template)
        }
        else {
            return (Invoke-EpsTemplate -Template $template -Binding $data)
        }
    }

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index' -Data @{ 'numbers' = @(1, 2, 3); 'date' = [DateTime]::UtcNow; }
    }

}