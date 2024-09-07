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

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
Add-PodeHeader -Name 'X-AuthToken' -Value 'AA-BB-CC-33'
#>
function Add-PodeHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret -Strict:$Strict)
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

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
Add-PodeHeaderBulk -Values @{ Name1 = 'Value1'; Name2 = 'Value2' }
#>
function Add-PodeHeaderBulk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Values,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        # sign the value if we have a secret
        if (![string]::IsNullOrWhiteSpace($Secret)) {
            $value = (Invoke-PodeValueSign -Value $value -Secret $Secret -Strict:$Strict)
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
function Test-PodeHeader {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    $header = (Get-PodeHeader -Name $Name)
    return (![string]::IsNullOrWhiteSpace($header))
}

<#
.SYNOPSIS
    Retrieves the value of a specified header from the incoming request.

.DESCRIPTION
    The `Get-PodeHeader` function retrieves the value of a specified header from the incoming request.
    It supports deserialization of header values and can optionally unsign the header using a specified secret.
    The unsigning process can be further secured with the client's UserAgent and RemoteIPAddress if `-Strict` is specified.

.PARAMETER Name
    The name of the header to retrieve. This parameter is mandatory.

.PARAMETER Secret
    The secret used to unsign the header's value. This option is useful when working with signed headers to ensure
    the integrity and authenticity of the value. Applicable only in the 'BuiltIn' parameter set.

.PARAMETER Strict
    If specified, the secret is extended using the client's UserAgent and RemoteIPAddress, providing an additional
    layer of security during the unsigning process. Applicable only in the 'BuiltIn' parameter set.

.PARAMETER Deserialize
    Indicates that the retrieved header value should be deserialized. When this switch is used, the value will be
    interpreted based on the provided deserialization options. This parameter is mandatory in the 'Deserialize' parameter set.

.PARAMETER Explode
    Specifies whether the deserialization process should explode arrays in the header value. This is useful when
    handling comma-separated values within the header. Applicable only when the `-Deserialize` switch is used.

.EXAMPLE
    Get-PodeHeader -Name 'X-AuthToken'
    Retrieves the value of the 'X-AuthToken' header from the request.

.EXAMPLE
    Get-PodeHeader -Name 'X-SerializedHeader' -Deserialize -Explode
    Retrieves and deserializes the value of the 'X-SerializedHeader' header, exploding arrays if present.

.EXAMPLE
    Get-PodeHeader -Name 'X-AuthToken' -Secret 'MySecret' -Strict
    Retrieves and unsigns the 'X-AuthToken' header using the specified secret, extending it with UserAgent and
    RemoteIPAddress information for added security.

.NOTES
    This function should be used within a route's script block in a Pode server. The `-Deserialize` switch enables
    advanced handling of serialized header values, while the `-Secret` and `-Strict` options provide secure unsigning
    capabilities for signed headers.
#>
function Get-PodeHeader {
    [CmdletBinding(DefaultParameterSetName = 'BuiltIn' )]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Deserialize')]
        [Parameter(Mandatory = $true, ParameterSetName = 'BuiltIn')]
        [string]
        $Name,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [string]
        $Secret,

        [Parameter(ParameterSetName = 'BuiltIn')]
        [switch]
        $Strict,

        [Parameter(ParameterSetName = 'Deserialize')]
        [switch]
        $Explode,

        [Parameter(Mandatory = $true, ParameterSetName = 'Deserialize')]
        [switch]
        $Deserialize
    )
    if ($WebEvent) {
        # get the value for the header from the request
        $header = $WebEvent.Request.Headers.$Name

        if ($Deserialize.IsPresent) {
            return ConvertFrom-PodeSerializedString -SerializedString $header -Style 'Simple' -Explode:$Explode
        }
        # if a secret was supplied, attempt to unsign the header's value
        if (![string]::IsNullOrWhiteSpace($Secret)) {
            $header = (Invoke-PodeValueUnsign -Value $header -Secret $Secret -Strict:$Strict)
        }

        return $header
    }
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

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
Set-PodeHeader -Name 'X-AuthToken' -Value 'AA-BB-CC-33'
#>
function Set-PodeHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Value,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    # sign the value if we have a secret
    if (![string]::IsNullOrWhiteSpace($Secret)) {
        $Value = (Invoke-PodeValueSign -Value $Value -Secret $Secret -Strict:$Strict)
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

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
Set-PodeHeaderBulk -Values @{ Name1 = 'Value1'; Name2 = 'Value2' }
#>
function Set-PodeHeaderBulk {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Values,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    foreach ($key in $Values.Keys) {
        $value = $Values[$key]

        # sign the value if we have a secret
        if (![string]::IsNullOrWhiteSpace($Secret)) {
            $value = (Invoke-PodeValueSign -Value $value -Secret $Secret -Strict:$Strict)
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

.PARAMETER Strict
If supplied, the Secret will be extended using the client request's UserAgent and RemoteIPAddress.

.EXAMPLE
Test-PodeHeaderSigned -Name 'X-Header-Name' -Secret 'hunter2'
#>
function Test-PodeHeaderSigned {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Secret,

        [switch]
        $Strict
    )

    $header = Get-PodeHeader -Name $Name
    return Test-PodeValueSigned -Value $header -Secret $Secret -Strict:$Strict
}