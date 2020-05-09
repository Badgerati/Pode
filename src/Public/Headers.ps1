<#
.SYNOPSIS
Appends a header against the Response.

.DESCRIPTION
Appends a header against the Response. If the current context is serverless, then this function acts like Set-PodeHeader.

.PARAMETER Name
The name of the header.

.PARAMETER Value
The value to set against the header.

.PARAMETER Secret
If supplied, the secret with which to sign the header's value.

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
        $Value,

        [Parameter()]
        [string]
        $Secret
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret)
    }

    # add the header to the response
    switch ($PodeContext.Server.Type) {
        'http' {
            $WebEvent.Response.AppendHeader($Name, $Value) | Out-Null
        }

        'pode' {
            if (!$WebEvent.Response.Headers.ContainsKey($Name)) {
                $WebEvent.Response.Headers[$Name] = @()
            }

            $WebEvent.Response.Headers[$Name] += $Value
        }

        default {
            $WebEvent.Response.Headers[$Name] = $Value
        }
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

.PARAMETER Secret
The secret used to unsign the header's value.

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
        $Name,

        [Parameter()]
        [string]
        $Secret
    )

    # get the value for the header from the request
    if ($PodeContext.Server.Type -ine 'http') {
        $header = $WebEvent.Request.Headers.$Name
    }
    else {
        $header = $WebEvent.Request.Headers[$Name]
    }

    # if a secret was supplied, attempt to unsign the header's value
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $header = (Invoke-PodeValueUnsign -Value $header -Secret $Secret)
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

.PARAMETER Secret
If supplied, the secret with which to sign the header's value.

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
        $Value,

        [Parameter()]
        [string]
        $Secret
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret)
    }

    # set the header on the response
    switch ($PodeContext.Server.Type) {
        'http' {
            $WebEvent.Response.AddHeader($Name, $Value) | Out-Null
        }

        'pode' {
            $WebEvent.Response.Headers[$Name] = @($Value)
        }

        default {
            $WebEvent.Response.Headers[$Name] = $Value
        }
    }
}

<#
.SYNOPSIS
Tests if a header on the Request is validly signed.

.DESCRIPTION
Tests if a header on the Request is validly signed, by attempting to unsign it using some secret.

.PARAMETER Name
The name of the header to test.

.PARAMETER Secret
A secret to use for attempting to unsign the header's value.

.EXAMPLE
Test-PodeHeaderSigned -Name 'X-Header-Name' -Secret 'hunter2'
#>
function Test-PodeHeaderSigned
{
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret
    )

    $header = Get-PodeHeader -Name $Name
    if ([string]::IsNullOrWhiteSpace($header)) {
        return $false
    }

    $value = (Invoke-PodeValueUnsign -Value $header -Secret $Secret)
    return (![string]::IsNullOrWhiteSpace($value))
}