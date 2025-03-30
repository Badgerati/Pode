<#
.SYNOPSIS
	Adds a favicon to one or more Pode HTTP/HTTPS endpoints.

.DESCRIPTION
	This function allows you to define a favicon for Pode endpoints. You can either use the default favicon provided
	by Pode, specify a file path to a `.ico` file, or directly supply the favicon as a byte array. The function can apply
	the favicon to all HTTP/S endpoints, a specific endpoint, or only to endpoints marked as default.

.PARAMETER Default
	Use the default Pode favicon.ico embedded in the module.

.PARAMETER Path
	The path to a custom favicon.ico file to use. Must be a valid, accessible path.

.PARAMETER Binary
	A raw byte array representing the favicon.ico file contents.

.PARAMETER EndpointName
	The name of the specific endpoint to apply the favicon to. If not provided, the favicon is applied to all HTTP/S endpoints.

.PARAMETER DefaultEndpoint
	If supplied, only endpoints marked with `.Default = $true` will receive the favicon.

.OUTPUTS
	None

.EXAMPLE
	Add-PodeFavicon -Default

	# Adds the default Pode favicon to all HTTP/S endpoints.

.EXAMPLE
	Add-PodeFavicon -Path './assets/favicon.ico'

	# Adds a custom favicon from file to all HTTP/S endpoints.

.EXAMPLE
	Add-PodeFavicon -Binary $bytes -EndpointName 'api'

	# Adds a binary favicon to a specific endpoint named 'api'.

.EXAMPLE
	Add-PodeFavicon -Default -DefaultEndpoint

	# Adds the default favicon only to endpoints marked as default.
#>
function Add-PodeFavicon {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [switch]
        $Default,

        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'Binary')]
        [byte[]]
        $Binary,

        [Parameter()]
        [string]
        $EndpointName,

        [switch]
        $DefaultEndpoint
    )

    # Validate if the given endpoint exists in the context; throw error if it doesn't
    if (! [string]::IsNullOrEmpty($EndpointName) -and (! $PodeContext.Server.Endpoints.ContainsKey($EndpointName))) {
        throw ($Podelocale.endpointNameNotExistExceptionMessage -f $EndpointName)
    }

    # Determine which parameter set is used to retrieve the favicon bytes
    switch ($PSCmdlet.ParameterSetName) {
        'Path' {
            # Load the favicon from the specified file path
            $FaviconData = @{
                Bytes = [System.IO.File]::ReadAllBytes((Get-PodeRelativePath -Path $Path -JoinRoot -Resolve -TestPath))
            }
            break
        }
        'Binary' {
            # If provided directly as a byte array, use it as-is
            $FaviconData = @{
                Bytes = $Binary
            }
            break
        }
        'Default' {
            # Resolve path to Pode's internal misc folder for default favicon.ico
            $podeRoot = Get-PodeModuleMiscPath

            # Load default favicon.ico as byte array
            $FaviconData = @{
                Bytes       = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($podeRoot, 'favicon.ico'))
                ContentType = 'image/x-icon'
            }
            break
        }
    }

    # Auto-detect content type of the image from its byte array
    $FaviconData.ContentType = Get-PodeImageContentType -Image $FaviconData.Bytes

    # Resolve endpoint targets: single specified or all
    $keys = if ([string]::IsNullOrEmpty($EndpointName)) {
        $PodeContext.Server.Endpoints.Keys
    }
    else {
        @($EndpointName)
    }

    foreach ($key in $keys) {
        # Only attach favicon to Http or Https endpoints
        $endpoint = $PodeContext.Server.Endpoints[$key]
        if ($DefaultEndpoint -and !$endpoint.Default) {
            continue
        }
        if (@('Http', 'Https') -icontains $endpoint.Protocol) {
            $Endpoint.Favicon = $FaviconData
        }
    }
}

<#
.SYNOPSIS
	Checks whether a favicon is configured for one or more Pode endpoints.

.DESCRIPTION
	This function determines if a favicon is configured on a specific HTTP/S endpoint, or across all
	endpoints if no name is supplied. You can also limit the check to only endpoints marked as default.
	It returns $true only if all applicable endpoints have a favicon configured.

.PARAMETER EndpointName
	The name of the specific endpoint to check. If not provided, all endpoints are checked.

.PARAMETER DefaultEndpoint
	If supplied, only endpoints marked with `.Default = $true` are checked.

.OUTPUTS
	System.Boolean

.EXAMPLE
	Test-PodeFavicon

	# Returns true if all endpoints have a favicon configured.

.EXAMPLE
	Test-PodeFavicon -EndpointName 'api'

	# Returns true if the 'api' endpoint has a favicon configured.

.EXAMPLE
	Test-PodeFavicon -DefaultEndpoint

	# Returns true only if all default endpoints have a favicon.

.NOTES
	This is an internal Pode function and is subject to change.
#>
function Test-PodeFavicon {
    param(
        [string]
        $EndpointName,

        [switch]
        $DefaultEndpoint
    )

    # Validate endpoint name if supplied
    if (! [string]::IsNullOrEmpty($EndpointName) -and (! $PodeContext.Server.Endpoints.ContainsKey($EndpointName))) {
        throw ($Podelocale.endpointNameNotExistExceptionMessage -f $EndpointName)
    }

    # Collect endpoints to evaluate
    $keys = if ([string]::IsNullOrEmpty($EndpointName)) {
        $PodeContext.Server.Endpoints.Keys
    }
    else {
        @($EndpointName)
    }

    foreach ($key in $keys) {
        $endpoint = $PodeContext.Server.Endpoints[$key]

        # If filtering to default endpoints only, skip others
        if ($DefaultEndpoint -and !$endpoint.Default) {
            continue
        }

        # If any matched endpoint lacks a favicon, return false
        if ($null -eq $endpoint.Favicon) {
            return $false
        }
    }

    return $true
}

<#
.SYNOPSIS
	Retrieves the configured favicon(s) for one or more Pode endpoints.

.DESCRIPTION
	This function returns a hashtable containing the endpoint names and their corresponding favicon data
	(byte array and content type). If an endpoint name is specified, only its favicon is returned if set.
	If none is specified, the function returns all favicons set across endpoints. You can also limit the
	query to only endpoints marked as default.

.PARAMETER EndpointName
	The name of a specific endpoint to retrieve the favicon from. If not provided, favicons from all endpoints are returned.

.PARAMETER DefaultEndpoint
	If supplied, only endpoints marked with `.Default = $true` are included in the result.

.OUTPUTS
	System.Collections.Hashtable

.EXAMPLE
	Get-PodeFavicon

	# Returns a hashtable of all endpoints with configured favicons.

.EXAMPLE
	Get-PodeFavicon -EndpointName 'api'

	# Returns the favicon for the 'api' endpoint.

.EXAMPLE
	Get-PodeFavicon -DefaultEndpoint

	# Returns favicons for endpoints marked as default only.
#>
function Get-PodeFavicon {
    param(
        [string]
        $EndpointName,

        [switch]
        $DefaultEndpoint
    )

    # Validate that the specified endpoint exists, if provided
    if (! [string]::IsNullOrEmpty($EndpointName) -and (! $PodeContext.Server.Endpoints.ContainsKey($EndpointName))) {
        throw ($Podelocale.endpointNameNotExistExceptionMessage -f $EndpointName)
    }

    # Determine which endpoint(s) to check
    $keys = if ([string]::IsNullOrEmpty($EndpointName)) {
        $PodeContext.Server.Endpoints.Keys
    }
    else {
        @($EndpointName)
    }

    $favicons = @{}

    foreach ($key in $keys) {
        $endpoint = $PodeContext.Server.Endpoints[$key]

        # If filtering to default endpoints only, skip others
        if ($DefaultEndpoint -and !$endpoint.Default) {
            continue
        }

        # Only include endpoints that have a favicon set
        if ($null -ne $endpoint.Favicon) {
            $favicons[$key] = $endpoint.Favicon
        }
    }

    return $favicons
}

<#
.SYNOPSIS
	Removes the favicon from one or more Pode endpoints.

.DESCRIPTION
	This function clears the favicon from a specified endpoint, or from all endpoints if no name is provided.
	It safely checks that the endpoint(s) exist and have a favicon assigned before removing. You can also limit
	the removal to endpoints marked as default.

.PARAMETER EndpointName
	The name of a specific endpoint to remove the favicon from. If not specified, all endpoints are affected.

.PARAMETER DefaultEndpoint
	If supplied, only endpoints marked with `.Default = $true` will be affected.

.OUTPUTS
	None

.EXAMPLE
	Remove-PodeFavicon

	# Removes the favicon from all endpoints.

.EXAMPLE
	Remove-PodeFavicon -EndpointName 'api'

	# Removes the favicon from the 'api' endpoint.

.EXAMPLE
	Remove-PodeFavicon -DefaultEndpoint

	# Removes favicons only from endpoints marked as default.
#>
function Remove-PodeFavicon {
    param(
        [string]
        $EndpointName,

        [switch]
        $DefaultEndpoint
    )

    # Validate that the endpoint exists if a name is provided
    if (! [string]::IsNullOrEmpty($EndpointName) -and (! $PodeContext.Server.Endpoints.ContainsKey($EndpointName))) {
        throw ($Podelocale.endpointNameNotExistExceptionMessage -f $EndpointName)
    }

    # Determine the target endpoint(s)
    $keys = if ([string]::IsNullOrEmpty($EndpointName)) {
        $PodeContext.Server.Endpoints.Keys
    }
    else {
        @($EndpointName)
    }

    foreach ($key in $keys) {
        $endpoint = $PodeContext.Server.Endpoints[$key]

        # If filtering to default endpoints only, skip others
        if ($DefaultEndpoint -and !$endpoint.Default) {
            continue
        }

        # Only reset if a favicon is actually set
        if ($null -ne $endpoint.Favicon) {
            $endpoint.Favicon = $null
        }
    }
}
