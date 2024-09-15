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

    "console.log(`""
    if ($date.Second % 2 -eq 0) {
        "hello, world!"
    } else {
        "goodbye, world!"
    }
    "`")"
})