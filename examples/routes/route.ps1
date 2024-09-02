<#
.SYNOPSIS
    Used by Web-Pages.ps1 using Use-PodeRoutes

.DESCRIPTION
    Used by Web-Pages.ps1 using Use-PodeRoutes

.NOTES
    Author: Pode Team
    License: MIT License
#>
Add-PodeRoute -Method Get -Path '/route-file' -ScriptBlock {
    Write-PodeJsonResponse -Value @{ Message = "I'm from a route file!" }
}