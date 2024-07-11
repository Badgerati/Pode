<#
.SYNOPSIS
    Custom function for Imported-Funcs.ps1

.DESCRIPTION
    Custom function for Imported-Funcs.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
function Write-MySubGreeting {
    Write-PodeJsonResponse -Value @{ Message = "Mudkipz! [$(Get-Random -Maximum 100)]" }
}

Export-PodeFunction -Name 'Write-MySubGreeting'