<#
.SYNOPSIS
    Finds Pode endpoints based on protocol, address, or endpoint name.

.DESCRIPTION
    This function allows you to search for Pode endpoints based on different criteria. You can specify the protocol (HTTP or HTTPS), the address, or the endpoint name. It returns an array of hashtable objects representing the matching endpoints.

.PARAMETER Protocol
    The protocol of the endpoint (HTTP or HTTPS).

.PARAMETER Address
    The address of the endpoint.

.PARAMETER EndpointName
    The name of the endpoint.

.OUTPUTS
    An array of hashtables representing the matching endpoints, with the following keys:
    - 'Protocol'
    - 'Address'
    - 'Name'

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Find-PodeEndpoint {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter()]
        [ValidateSet('', 'Http', 'Https')]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Address,

        [Parameter()]
        [string[]]
        $EndpointName
    )

    $endpoints = @()

    # just use a single endpoint/protocol
    if ([string]::IsNullOrWhiteSpace($EndpointName)) {
        $endpoints += @{
            Protocol = $Protocol
            Address  = $Address
            Name     = [string]::Empty
        }
    }

    # get all defined endpoints by name
    else {
        foreach ($name in @($EndpointName)) {
            $_endpoint = Get-PodeEndpointByName -Name $name -ThrowError
            if ($null -ne $_endpoint) {
                $endpoints += @{
                    Protocol = $_endpoint.Protocol
                    Address  = $_endpoint.RawAddress
                    Name     = $name
                }
            }
        }
    }

    # convert the endpoint's address into host:port format
    foreach ($_endpoint in $endpoints) {
        if (![string]::IsNullOrWhiteSpace($_endpoint.Address)) {
            $_addr = Get-PodeEndpointInfo -Address $_endpoint.Address -AnyPortOnZero
            $_endpoint.Address = "$($_addr.Host):$($_addr.Port)"
        }
    }

    return $endpoints
}

<#
.SYNOPSIS
    Retrieves internal endpoints based on the specified types.

.DESCRIPTION
    The `Get-PodeEndpointByProtocolType` function returns internal endpoints from the PodeContext
    based on the specified types (HTTP, WebSocket, SMTP, or TCP).

.PARAMETER Type
    Specifies the type of endpoints to retrieve. Valid values are 'Http', 'Ws', 'Smtp', and 'Tcp'.
    This parameter is mandatory.

.OUTPUTS
    Returns an array of internal endpoints matching the specified types.

.EXAMPLE
    # Example usage:
    $httpEndpoints = Get-PodeEndpointByProtocolType -Type 'Http'
    $wsEndpoints = Get-PodeEndpointByProtocolType -Type 'Ws'
    # Retrieve HTTP and WebSocket endpoints from the PodeContext.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeEndpointByProtocolType {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Http', 'Ws', 'Smtp', 'Tcp')]
        [string[]]
        $Type
    )

    $endpoints = @()

    foreach ($t in $Type) {
        switch ($t.ToLowerInvariant()) {
            'http' {
                $endpoints += @($PodeContext.Server.Endpoints.Values | Where-Object { @('http', 'https') -icontains $_.Protocol })
            }

            'ws' {
                $endpoints += @($PodeContext.Server.Endpoints.Values | Where-Object { @('ws', 'wss') -icontains $_.Protocol })
            }

            'smtp' {
                $endpoints += @($PodeContext.Server.Endpoints.Values | Where-Object { @('smtp', 'smtps') -icontains $_.Protocol })
            }

            'tcp' {
                $endpoints += @($PodeContext.Server.Endpoints.Values | Where-Object { @('tcp', 'tcps') -icontains $_.Protocol })
            }
        }
    }

    return $endpoints
}

function Test-PodeEndpointByProtocolTypeProtocol {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Http', 'Https', 'Ws', 'Wss', 'Smtp', 'Smtps', 'Tcp', 'Tcps')]
        [string]
        $Protocol
    )

    $endpoint = $PodeContext.Server.Endpoints.Values | Where-Object { $_.Protocol -ieq $Protocol }
    return ($null -ne $endpoint)
}

function Get-PodeEndpointType {
    param(
        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol
    )

    switch ($Protocol) {
        { $_ -iin @('http', 'https') } {
            'Http'
        }

        { $_ -iin @('ws', 'wss') } {
            'Ws'
        }

        { $_ -iin @('smtp', 'smtps') } {
            'Smtp'
        }

        { $_ -iin @('tcp', 'tcps') } {
            'Tcp'
        }

        default {
            $Protocol
        }
    }
}

function Get-PodeEndpointRunspacePoolName {
    param(
        [Parameter()]
        [ValidateSet('Http', 'Https', 'Smtp', 'Smtps', 'Tcp', 'Tcps', 'Ws', 'Wss')]
        [string]
        $Protocol
    )

    switch ($Protocol) {
        { $_ -iin @('http', 'https') } {
            'Web'
        }

        { $_ -iin @('ws', 'wss') } {
            'Signals'
        }

        { $_ -iin @('smtp', 'smtps') } {
            'Smtp'
        }

        { $_ -iin @('tcp', 'tcps') } {
            'Tcp'
        }

        default {
            $Protocol
        }
    }
}

<#
.SYNOPSIS
Tests whether Pode endpoints of a specified type exist.

.DESCRIPTION
This function checks if there are any Pode endpoints of the specified type (HTTP, WebSocket, SMTP, or TCP). It returns a boolean value indicating whether endpoints of that type are available.

.PARAMETER Type
The type of Pode endpoint to test (HTTP, WebSocket, SMTP, or TCP).

.OUTPUTS
A boolean value (True if endpoints exist, False otherwise).

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeEndpointByProtocolType {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Http', 'Ws', 'Smtp', 'Tcp')]
        [string]
        $Type
    )

    $endpoints = (Get-PodeEndpointByProtocolType -Type $Type)
    return (($null -ne $endpoints) -and ($endpoints.Length -gt 0))

}

function Find-PodeEndpointName {
    param(
        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Address,

        [Parameter()]
        [System.Net.EndPoint]
        $LocalAddress,

        [switch]
        $Force,

        [switch]
        $ThrowError,

        [switch]
        $Enabled
    )

    if (!$Enabled -and !$Force) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Protocol) -or
        [string]::IsNullOrWhiteSpace($Address) -or
        [string]::IsNullOrWhiteSpace($LocalAddress)) {
        return $null
    }

    <#
       using Host header
    #>

    # add a default port to the address if missing
    if (!$Address.Contains(':')) {
        $port = Get-PodeDefaultPort -Protocol $Protocol -Real -TlsMode Implicit
        $Address = "$($Address):$($port)"
    }

    # change localhost/computer name to ip address
    if (($Address -ilike 'localhost:*') -or ($Address -ilike "$($PodeContext.Server.ComputerName):*")) {
        $Address = ($Address -ireplace "(localhost|$([regex]::Escape($PodeContext.Server.ComputerName)))\:", "(127\.0\.0\.1|0\.0\.0\.0|\:\:ffff\:127\.0\.0\.1|\:\:ffff\:0\:0|\[\:\:\]|\[\:\:1\]|\:\:1|\:\:|localhost|$([regex]::Escape($PodeContext.Server.ComputerName))):")
    }
    else {
        $Address = [regex]::Escape($Address)
    }

    # create the endpoint key for address
    $key = "$($Protocol)\|$($Address)"

    # try and find endpoint for address
    $key = @(foreach ($k in $PodeContext.Server.EndpointsMap.Keys) {
            if ($k -imatch $key) {
                $k
                break
            }
        })[0]

    if (![string]::IsNullOrWhiteSpace($key) -and $PodeContext.Server.EndpointsMap.ContainsKey($key)) {
        return $PodeContext.Server.EndpointsMap[$key]
    }

    <#
       using local endpoint from socket
    #>

    # setup the local address as a string
    $_localAddress = "$($LocalAddress.Address.IPAddressToString):$($LocalAddress.Port)"
    $_localAddress = [regex]::Escape($_localAddress)

    # create the endpoint key for local address
    $key = "$($Protocol)\|$($_localAddress)"

    # try and find endpoint for local address
    $key = @(foreach ($k in $PodeContext.Server.EndpointsMap.Keys) {
            if ($k -imatch $key) {
                $k
                break
            }
        })[0]

    if (![string]::IsNullOrWhiteSpace($key) -and $PodeContext.Server.EndpointsMap.ContainsKey($key)) {
        return $PodeContext.Server.EndpointsMap[$key]
    }

    <#
       check for * address
    #>

    # set * address as string
    $_anyAddress = "(0\.0\.0\.0|\[\:\:\]|\:\:|\:\:ffff\:0\:0):$($LocalAddress.Port)"
    $key = "$($Protocol)\|$($_anyAddress)"

    # try and find endpoint for any address
    $key = @(foreach ($k in $PodeContext.Server.EndpointsMap.Keys) {
            if ($k -imatch $key) {
                $k
                break
            }
        })[0]

    if (![string]::IsNullOrWhiteSpace($key) -and $PodeContext.Server.EndpointsMap.ContainsKey($key)) {
        return $PodeContext.Server.EndpointsMap[$key]
    }

    # error?
    if ($ThrowError) {
        throw ($PodeLocale.endpointNotExistExceptionMessage -f $Protocol, $Address, $_localAddress) #"Endpoint with protocol '$($Protocol)' and address '$($Address)' or local address '$($_localAddress)' does not exist"
    }

    return $null
}

function Get-PodeEndpointByName {
    param(
        [Parameter()]
        [string]
        $Name,

        [switch]
        $ThrowError
    )

    # if an EndpointName was supplied, find it and use it
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    # ensure it exists
    if ($PodeContext.Server.Endpoints.ContainsKey($Name)) {
        return $PodeContext.Server.Endpoints[$Name]
    }

    # error?
    if ($ThrowError) {
        throw ($PodeLocale.endpointNameNotExistExceptionMessage -f $Name) #"Endpoint with name '$($Name)' does not exist"
    }

    return $null
}
 