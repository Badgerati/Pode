<#
.SYNOPSIS
Appends a header against the Response.

.DESCRIPTION
Appends a header against the Response. If the current context is serverless, then this function acts like Set-PodeHeader.

.PARAMETER Name
The name of the header.

.PARAMETER Value
The value to set against the header.

.EXAMPLE
Add-PodeHeader -Name 'X-AuthToken' -Value 'AA-BB-CC-33'
#>
function Add-PodeHeader
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Value
    )

    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    elseif ($PodeContext.Server.IsKestrel) {
        [Microsoft.AspNetCore.Http.HeaderDictionaryExtensions]::Append($WebEvent.Response.Headers, $Name, $Value) | Out-Null
    }
    else {
        $WebEvent.Response.AppendHeader($Name, $Value) | Out-Null
    }
}

<#
.SYNOPSIS
Tests if a header is present on the Request.

.DESCRIPTION
Tests if a header is present on the Request.

.PARAMETER Name
The name of the header to test.

.EXAMPLE
Test-PodeHeader -Name 'X-AuthToken'
#>
function Test-PodeHeader
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $header = (Get-PodeHeader -Name $Name)
    return (![string]::IsNullOrWhiteSpace($header))
}

<#
.SYNOPSIS
Retrieves the value of a header from the Request.

.DESCRIPTION
Retrieves the value of a header from the Request.

.PARAMETER Name
The name of the header to retrieve.

.EXAMPLE
Get-PodeHeader -Name 'X-AuthToken'
#>
function Get-PodeHeader
{
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    if ($PodeContext.Server.IsServerless) {
        $header = $WebEvent.Request.Headers.$Name
    }
    else {
        $header = $WebEvent.Request.Headers[$Name]
    }

    return $header
}

<#
.SYNOPSIS
Sets a header on the Response, clearing all current values for the header.

.DESCRIPTION
Sets a header on the Response, clearing all current values for the header.

.PARAMETER Name
The name of the header.

.PARAMETER Value
The value to set against the header.

.EXAMPLE
Set-PodeHeader -Name 'X-AuthToken' -Value 'AA-BB-CC-33'
#>
function Set-PodeHeader
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Value
    )

    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    elseif ($PodeContext.Server.IsKestrel) {
        [Microsoft.AspNetCore.Http.HeaderDictionaryExtensions]::Append($WebEvent.Response.Headers, $Name, $Value) | Out-Null
    }
    else {
        $WebEvent.Response.AddHeader($Name, $Value) | Out-Null
    }
}