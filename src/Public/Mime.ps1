<#
.SYNOPSIS
Add a new MIME type mapping for a file extension.

.DESCRIPTION
Add a new MIME type mapping for a file extension in the global MIME type registry.
Throws an exception if the extension already exists.

.PARAMETER Extension
The file extension (with or without leading dot) to map to a MIME type.

.PARAMETER MimeType
The MIME type to associate with the extension.

.EXAMPLE
Add-PodeMimeType -Extension '.json' -MimeType 'application/json'

.EXAMPLE
Add-PodeMimeType -Extension 'xml' -MimeType 'application/xml'
#>
function Add-PodeMimeType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Extension,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MimeType
    )

    try {
        [Pode.PodeMimeTypes]::Add($Extension, $MimeType)
        Write-Verbose "Added MIME type mapping: $Extension -> $MimeType"
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

<#
.SYNOPSIS
Update an existing MIME type mapping for a file extension.

.DESCRIPTION
Update an existing MIME type mapping for a file extension. This function will add the mapping
if it doesn't exist, or update it if it does exist.

.PARAMETER Extension
The file extension (with or without leading dot) to update.

.PARAMETER MimeType
The new MIME type to associate with the extension.

.EXAMPLE
Set-PodeMimeType -Extension '.json' -MimeType 'application/vnd.api+json'
#>
function Set-PodeMimeType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Extension,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $MimeType
    )
    try {
        [Pode.PodeMimeTypes]::AddOrUpdate($Extension, $MimeType)
        Write-Verbose "Updated MIME type mapping: $Extension -> $MimeType"
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

<#
.SYNOPSIS
Remove a MIME type mapping for a file extension.

.DESCRIPTION
Remove a MIME type mapping for a file extension from the global MIME type registry.

.PARAMETER Extension
The file extension (with or without leading dot) to remove from the registry.

.EXAMPLE
Remove-PodeMimeType -Extension '.myext'

.EXAMPLE
Remove-PodeMimeType -Extension 'customtype'
Write-Host "MIME type mapping removal attempted"
#>
function Remove-PodeMimeType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Extension
    )

    try {
        $result = [Pode.PodeMimeTypes]::Remove($Extension)
        if ($result) {
            Write-Verbose "Removed MIME type mapping for extension: $Extension"
        }
        else {
            Write-Verbose "No MIME type mapping found for extension: $Extension"
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

<#
.SYNOPSIS
Get the MIME type for a file extension.

.DESCRIPTION
Get the MIME type associated with a file extension from the global MIME type registry.

.PARAMETER Extension
The file extension (with or without leading dot) to look up.

.PARAMETER DefaultMimeType
The default MIME type to return if the extension is not found. Defaults to 'application/octet-stream'.

.OUTPUTS
[string] The MIME type associated with the extension, or the default if not found.

.EXAMPLE
Get-PodeMimeType -Extension '.json'

.EXAMPLE
$mimeType = Get-PodeMimeType -Extension 'pdf'
Write-Host "PDF MIME type: $mimeType"

.EXAMPLE
$mimeType = Get-PodeMimeType -Extension '.unknown' -DefaultMimeType 'text/plain'
#>
function Get-PodeMimeType {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Extension,

        [Parameter()]
        [string]
        $DefaultMimeType = 'application/octet-stream'
    )

    try {
        $mimeType = $null
        if ([Pode.PodeMimeTypes]::TryGet($Extension, [ref]$mimeType)) {
            return $mimeType
        }
        else {
            Write-Verbose "No MIME type found for extension '$Extension', returning default: $DefaultMimeType"
            return $DefaultMimeType
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

<#
.SYNOPSIS
Test if a MIME type mapping exists for a file extension.

.DESCRIPTION
Test if a MIME type mapping exists for a file extension in the global MIME type registry.

.PARAMETER Extension
The file extension (with or without leading dot) to test.

.OUTPUTS
[bool] Returns $true if a mapping exists, $false otherwise.

.EXAMPLE
Test-PodeMimeType -Extension '.json'

.EXAMPLE
if (Test-PodeMimeType -Extension '.myext') {
    Write-Host "Custom extension is registered"
}
#>
function Test-PodeMimeType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Extension
    )

    try {
        return [Pode.PodeMimeTypes]::Contains($Extension)
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}


<#
.SYNOPSIS
Load MIME type mappings from a file.

.DESCRIPTION
Bulk-load MIME type mappings from a file in "type ext1 ext2 ..." format (e.g., Apache mime.types list).

.PARAMETER Path
The path to the file containing MIME type mappings.

.EXAMPLE
Import-PodeMimeTypeFromFile -Path 'C:\path\to\mime.types'

.EXAMPLE
Import-PodeMimeTypeFromFile -Path './custom-mime-types.txt'
#>
function Import-PodeMimeTypeFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )

    # Validate path exists
    if (!(Test-Path $Path)) {
        throw ($Podelocale.pathNotExistExceptionMessage -f $Path)
    }

    try {
        [Pode.PodeMimeTypes]::LoadFromFile($Path)
        Write-Verbose "Loaded MIME type mappings from file: $Path"
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_.Exception
    }
}

