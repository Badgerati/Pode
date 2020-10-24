function Find-PodeEndpoints
{
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
            Address = $Address
            Name = [string]::Empty
        }
    }

    # get all defined endpoints by name
    else {
        foreach ($name in @($EndpointName)) {
            $_endpoint = Get-PodeEndpointByName -Name $name -ThrowError
            if ($null -ne $_endpoint) {
                $endpoints += @{
                    Protocol = $_endpoint.Protocol
                    Address = $_endpoint.RawAddress
                    Name = $name
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

function Get-PodeEndpoints
{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Http', 'Ws')]
        [string]
        $Type
    )

    $endpoints = $null

    switch ($Type.ToLowerInvariant()) {
        'http' {
            $endpoints = @($PodeContext.Server.Endpoints.Values | Where-Object { @('http', 'https') -icontains $_.Protocol })
        }

        'ws' {
            $endpoints = @($PodeContext.Server.Endpoints.Values | Where-Object { @('ws', 'wss') -icontains $_.Protocol })
        }
    }

    return $endpoints
}

function Find-PodeEndpointName
{
    param(
        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Address,

        [switch]
        $ThrowError
    )

    if ([string]::IsNullOrWhiteSpace($Protocol) -or [string]::IsNullOrWhiteSpace($Address)) {
        return $null
    }

    # try and find endpoint
    if ($Address -ilike 'localhost:*') {
        $Address = ($Address -ireplace 'localhost\:', '127.0.0.1:')
    }

    $key = "$($Protocol)|$($Address)"

    $key = @(foreach ($k in $PodeContext.Server.EndpointsMap.Keys) {
        if ($key -ilike $k) {
            $k
            break
        }
    })[0]

    if (![string]::IsNullOrWhiteSpace($key) -and $PodeContext.Server.EndpointsMap.ContainsKey($key)) {
        return $PodeContext.Server.EndpointsMap[$key]
    }

    # error?
    if ($ThrowError) {
        throw "Endpoint with protocol '$($Protocol)' and address '$($Address)' does not exist"
    }

    return $null
}

function Get-PodeEndpointByName
{
    param (
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
        throw "Endpoint with name '$($Name)' does not exist"
    }

    return $null
}