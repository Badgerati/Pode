<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with multiple routes using different approaches.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with various routes demonstrating different
    approaches to route creation. These include using script blocks, file paths, and direct script inclusion.

.EXAMPLE
    To run the sample: ./Create-Routes.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Create-Routes.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

#crete routes using different approaches
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

Start-PodeServer -Threads 1 -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeRoute -PassThru -Method Get -Path '/routeCreateScriptBlock/:id' -ScriptBlock ([ScriptBlock]::Create( (Get-Content -Path "$ScriptPath\scripts\routeScript.ps1" -Raw))) |
        Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeCreateScriptBlock' -PassThru |
        Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path -Required) )


    Add-PodeRoute -PassThru -Method Post -Path '/routeFilePath/:id' -FilePath '.\scripts\routeScript.ps1' | Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeFilePath' -PassThru |
        Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path -Required) )


    Add-PodeRoute -PassThru -Method Get -Path '/routeScriptBlock/:id' -ScriptBlock { $Id = $WebEvent.Parameters['id'] ; Write-PodeJsonResponse -StatusCode 200 -Value @{'id' = $Id } } |
        Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeScriptBlock' -PassThru |
        Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path -Required) )


    Add-PodeRoute -PassThru -Method Get -Path '/routeScriptSameScope/:id' -ScriptBlock { . $ScriptPath\scripts\routeScript.ps1 } |
        Set-PodeOARouteInfo -Summary 'Test' -OperationId 'routeScriptSameScope' -PassThru |
        Set-PodeOARequest -Parameters @((New-PodeOAStringProperty -Name 'id' | ConvertTo-PodeOAParameter -In Path -Required) )

}