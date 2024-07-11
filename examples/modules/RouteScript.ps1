<#
.SYNOPSIS
    Custom script for Web-Pages.ps1 and Web-PagesKestrel.ps1

.DESCRIPTION
    Custom script for Web-Pages.ps1 and Web-PagesKestrel.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
return {
    $using:hmm | out-default
    Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(4, 5, 6); }
}