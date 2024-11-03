<#
.SYNOPSIS
    Used by Create-Routes.ps1

.DESCRIPTION
    Create-Routes.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
{
    $Id = $WebEvent.Parameters['id']
    Write-PodeJsonResponse -StatusCode 200 -Value @{'id' = $Id }
}