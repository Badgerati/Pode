<#
.SYNOPSIS
    Custom function for Web-PageUsing

.DESCRIPTION
    Custom function for Web-PageUsing

.NOTES
    Author: Pode Team
    License: MIT License
#>
function Write-MyGreeting {
    Write-PodeJsonResponse -Value @{ Message = "Hello, world! [$(Get-Random -Maximum 100)]" }
}

Export-PodeFunction -Name 'Write-MyGreeting'
Use-PodeScript -Path (Join-Path $PSScriptRoot .\Imported-SubFuncs.ps1)