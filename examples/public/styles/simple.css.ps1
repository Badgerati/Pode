<#
.SYNOPSIS
    Custom script for index.ps1

.DESCRIPTION
    Custom script for index.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
return (. {
    $date = [DateTime]::UtcNow;

    "body {"
    if ($date.Second % 2 -eq 0) {
        "background-color: rebeccapurple;"
    } else {
        "background-color: red;"
    }
    "}"
})