<#
.SYNOPSIS
    A sample PowerShell script to set up a HTTPS Pode server with a self-sign certificate

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 in HTTPS

.EXAMPLE
    To run the sample: ./Web-SelfSigned.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-SelfSigned.ps1

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
}
catch { throw }

Start-PodeServer -Threads 6 {
    Add-PodeEndpoint -Address localhost -Port '8081' -Protocol 'Https' -SelfSigned

    New-PodeLoggingMethod -File -Name 'requests' | Enable-PodeRequestLogging
    New-PodeLoggingMethod -File -Name 'errors' | Enable-PodeErrorLogging

    Add-PodeRoute -Method Get -Path / -ScriptBlock {
        Write-PodeTextResponse -Value 'Test'
    }
}