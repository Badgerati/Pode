function Find-PodeEndpoints {
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

function Get-PodeEndpoints {
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

function Test-PodeEndpointProtocol {
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

function Test-PodeEndpoints {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Http', 'Ws', 'Smtp', 'Tcp')]
        [string]
        $Type
    )

    $endpoints = (Get-PodeEndpoints -Type $Type)
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
        throw ($msgTable.endpointNotExistMessage -f $Protocol, $Address, $_localAddress) #"Endpoint with protocol '$($Protocol)' and address '$($Address)' or local address '$($_localAddress)' does not exist"
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
        throw ($msgTable.endpointNameNotExistMessage -f $Name) #"Endpoint with name '$($Name)' does not exist"
    }

    return $null
}