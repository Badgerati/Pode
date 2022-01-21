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
    param(
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
    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    else {
        $WebEvent.Response.Headers.Add($Name, $Value)
    }
}

<#
.SYNOPSIS
Appends multiple headers against the Response.

.DESCRIPTION
Appends multiple headers against the Response. If the current context is serverless, then this function acts like Set-PodeHeaderBulk.

.PARAMETER Values
A hashtable of headers to be appended.

.PARAMETER Secret
If supplied, the secret with which to sign the header values.

.EXAMPLE
Add-PodeHeaderBulk -Values @{ Name1 = 'Value1'; Name2 = 'Value2' }
#>
function Add-PodeHeaderBulk
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Value,

        [Parameter()]
        [string]
        $Secret
    )

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        # sign the value if we have a secret
        if (![string]::IsNullOrWhiteSpace($Secret)) {
            $value = (Invoke-PodeValueSign -Value $value -Secret $Secret)
        }

        # add the header to the response
        if ($PodeContext.Server.IsServerless) {
            $WebEvent.Response.Headers[$key] = $value
        }
        else {
            $WebEvent.Response.Headers.Add($key, $value)
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
    $header = $WebEvent.Request.Headers.$Name

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
    param(
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
    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    else {
        $WebEvent.Response.Headers.Set($Name, $Value)
    }
}

<#
.SYNOPSIS
Sets multiple headers on the Response, clearing all current values for the header.

.DESCRIPTION
Sets multiple headers on the Response, clearing all current values for the header.

.PARAMETER Values
A hashtable of headers to be set.

.PARAMETER Secret
If supplied, the secret with which to sign the header values.

.EXAMPLE
Set-PodeHeaderBulk -Values @{ Name1 = 'Value1'; Name2 = 'Value2' }
#>
function Set-PodeHeaderBulk
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $Values,

        [Parameter()]
        [string]
        $Secret
    )

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        # sign the value if we have a secret
        if (![string]::IsNullOrWhiteSpace($Secret)) {
            $value = (Invoke-PodeValueSign -Value $value -Secret $Secret)
        }

        # set the header on the response
        if ($PodeContext.Server.IsServerless) {
            $WebEvent.Response.Headers[$key] = $value
        }
        else {
            $WebEvent.Response.Headers.Set($key, $value)
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