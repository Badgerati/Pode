<#
.SYNOPSIS
Adds an access rule to allow or deny IP addresses.

.DESCRIPTION
Adds an access rule to allow or deny IP addresses.

.PARAMETER Access
The type of access to enable.

.PARAMETER Type
What type of request are we configuring?

.PARAMETER Values
A single, or an array of values.

.EXAMPLE
Add-PodeAccessRule -Access Allow -Type IP -Values '127.0.0.1'

.EXAMPLE
Add-PodeAccessRule -Access Deny -Type IP -Values @('192.168.1.1', '10.10.1.0/24')
#>
function Add-PodeAccessRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Access,

        [Parameter(Mandatory = $true)]
        [ValidateSet('IP')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Values
    )

    Add-PodeLimitAccessRule `
        -Name (New-PodeGuid) `
        -Action $Access `
        -Component (New-PodeLimitIPComponent -IP $Values)
}

<#
.SYNOPSIS
Adds rate limiting rules for an IP addresses, Routes, or Endpoints.

.DESCRIPTION
Adds rate limiting rules for an IP addresses, Routes, or Endpoints.

.PARAMETER Type
What type of request is being rate limited: IP, Route, or Endpoint?

.PARAMETER Values
A single, or an array of values.

.PARAMETER Limit
The maximum number of requests to allow.

.PARAMETER Seconds
The number of seconds to count requests before restarting the count.

.PARAMETER Group
If supplied, groups of IPs in a subnet will be considered as one IP.

.EXAMPLE
Add-PodeLimitRule -Type IP -Values '127.0.0.1' -Limit 10 -Seconds 1

.EXAMPLE
Add-PodeLimitRule -Type IP -Values @('192.168.1.1', '10.10.1.0/24') -Limit 50 -Seconds 1 -Group

.EXAMPLE
Add-PodeLimitRule -Type Route -Values '/downloads' -Limit 5 -Seconds 1
#>
function Add-PodeLimitRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('IP', 'Route', 'Endpoint')]
        [string]
        $Type,

        [Parameter(Mandatory = $true)]
        [string[]]
        $Values,

        [Parameter(Mandatory = $true)]
        [int]
        $Limit,

        [Parameter(Mandatory = $true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    $component = $null

    switch ($Type.ToLowerInvariant()) {
        'ip' {
            $component = New-PodeLimitIPComponent -IP $Values -Group:$Group
        }

        'route' {
            $component = New-PodeLimitRouteComponent -Path $Values
        }

        'endpoint' {
            $component = New-PodeLimitEndpointComponent -EndpointName $Values
        }
    }

    Add-PodeLimitRateRule `
        -Name (New-PodeGuid) `
        -Limit $Limit `
        -Timeout $Seconds `
        -Component $component
}

function Add-PodeLimitRateRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [hashtable[]]
        $Component,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $Limit,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $Timeout = 60,

        [Parameter()]
        [int]
        $StatusCode = 429
    )

    if (Test-PodeLimitRateRule -Name $Name) {
        throw "A rate limit rule with the name '$($Name)' already exists"
    }

    $PodeContext.Server.Limits.Rate.Rules[$Name] = @{
        Components = $Component
        Limit      = $Limit
        Timeout    = $Timeout
        StatusCode = $StatusCode
        Active     = [System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new()
    }

    Add-PodeLimitRateTimer
}

function Remove-PodeLimitRateRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Limits.Rate.Rules.Remove($Name)
    Remove-PodeLimitRateTimer
}

function Test-PodeLimitRateRule {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $Name
    )

    return $PodeContext.Server.Limits.Rate.Rules.Contains($Name)
}

function Get-PodeLimitRateRule {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    if ($Name) {
        return $Name | ForEach-Object { $PodeContext.Server.Limits.Rate.Rules[$_] }
    }

    return $PodeContext.Server.Limits.Rate.Rules.Values
}

function Add-PodeLimitAccessRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [hashtable[]]
        $Component,

        [Parameter()]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Action,

        [Parameter()]
        [int]
        $StatusCode = 403
    )

    if (Test-PodeLimitAccessRule -Name $Name) {
        throw "An access limit rule with the name '$($Name)' already exists"
    }

    $PodeContext.Server.Limits.Access.Rules[$Name] = @{
        Components = $Component
        Action     = $Action
        StatusCode = $StatusCode
    }

    # set the flag if we have any allow rules
    if ($Action -eq 'Allow') {
        $PodeContext.Server.Limits.Access.HaveAllowRules = $true
    }
}

function Remove-PodeLimitAccessRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    # remove the rule
    $null = $PodeContext.Server.Limits.Access.Rules.Remove($Name)

    # reset the flag if we have any allow rules
    $haveAccessRules = ($PodeContext.Server.Limits.Access.Rules.Value |
            Where-Object { $_.Action -eq 'Allow' } |
            Measure-Object).Count -gt 0

    if (!$haveAccessRules) {
        $PodeContext.Server.Limits.Access.HaveAllowRules = $false
    }
}

function Test-PodeLimitAccessRule {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [string]
        $Name
    )

    return $PodeContext.Server.Limits.Access.Rules.Contains($Name)
}

function Get-PodeLimitAccessRule {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    if ($Name) {
        return $Name | ForEach-Object { $PodeContext.Server.Limits.Access.Rules[$_] }
    }

    return $PodeContext.Server.Limits.Access.Rules.Values
}

function New-PodeLimitIPComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # empty, *, or "all" means all IPs
        [Parameter()]
        [string[]]
        $IP,

        # if not passed, IPs in a passed subnet will be treated individually
        # if passed, IPs in a passed subnet will be treated as a single entity
        [switch]
        $Group
    )

    # map of ip/subnet details
    $ipDetails = [ordered]@{
        Raw     = @{}
        Subnets = [ordered]@{}
        Any     = (Test-PodeIsEmpty -Value $IP)
        Local   = $false
    }

    # loop through each IP to parse details
    foreach ($_ip in $IP) {
        # is the ip valid?
        if (!(Test-PodeIPAddressLocal -IP $_ip) -and !(Test-PodeIPAddress -IP $_ip -IPOnly)) {
            throw "The IP '$($_ip)' is not a valid IP address"
        }

        # for any, just flag as any and continue
        if ([string]::IsNullOrWhiteSpace($_ip) -or (Test-PodeIPAddressAny -IP $_ip)) {
            $ipDetails.Any = $true
            continue
        }

        # for local, just flag as local and continue
        if (Test-PodeIPAddressLocal -IP $_ip) {
            $ipDetails.Local = $true
            continue
        }

        # for subnet, parse the subnet details
        if (Test-PodeIPAddressIsSubnetMask -IP $_ip) {
            $subnetRange = Get-PodeSubnetRange -SubnetMask $_ip
            $lowerDetails = Get-PodeIPAddress -IP $subnetRange.Lower
            $upperDetails = Get-PodeIPAddress -IP $subnetRange.Upper

            $ipDetails.Subnets[$_ip] = @{
                Family = $lowerDetails.Family
                Lower  = $lowerDetails.GetAddressBytes()
                Upper  = $upperDetails.GetAddressBytes()
            }
            continue
        }

        # for raw IP, just parse the IP details
        $details = Get-PodeIPAddress -IP $_ip
        $ipDetails.Raw[$_ip] = @{
            Family = $details.Family
        }
    }

    # pass back the IP component
    return @{
        Options     = @{
            IP    = $ipDetails
            Group = $Group.IsPresent
        }
        ScriptBlock = {
            param($options)

            # current request ip
            $ip = $WebEvent.Request.RemoteEndPoint.Address
            $ipDetails = @{
                Value  = $ip.IPAddressToString
                Family = $ip.AddressFamily
                Bytes  = $ip.GetAddressBytes()
            }

            # is the ip in the Raw list?
            if ($options.IP.Raw.ContainsKey($ipDetails.Value)) {
                return $ipDetails.Value
            }

            # is the ip in the Subnets list?
            foreach ($subnet in $options.IP.Subnets.Keys) {
                $subnetDetails = $options.IP.Subnets[$subnet]
                if ($subnetDetails.Family -ne $ipDetails.Family) {
                    continue
                }

                # if the ip is in the subnet range, then return the subnet
                if (Test-PodeIPAddressInSubnet -IP $ipDetails.Bytes -Lower $subnetDetails.Lower -Upper $subnetDetails.Upper) {
                    if ($options.Group) {
                        return $subnet
                    }

                    return $ipDetails.Value
                }
            }

            # is the ip local?
            if ($options.IP.Local) {
                if ([System.Net.IPAddress]::IsLoopback($ip)) {
                    if ($options.Group) {
                        return 'local'
                    }

                    return $ipDetails.Value
                }
            }

            # is any allowed?
            if ($options.IP.Any) {
                if ($options.Group) {
                    return '*'
                }

                return $ipDetails.Value
            }

            # return null
            return $null
        }
    }
}

function New-PodeLimitRouteComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Path,

        [switch]
        $Group
    )

    # convert paths into a hashtable for easier lookup
    $htPath = @{}
    foreach ($p in $Path) {
        $htPath[(ConvertTo-PodeRouteRegex -Path $p)] = $true
    }

    # pass back the route component
    return @{
        Options     = @{
            Path  = $htPath
            Group = $Group.IsPresent
            All   = (Test-PodeIsEmpty -Value $Path)
        }
        ScriptBlock = {
            param($options)

            # current request path
            $path = $WebEvent.Path

            # if the list is empty, or the list contains the path, then return the path
            if ($options.All -or $options.Path.ContainsKey($path)) {
                return $path
            }

            # check if the path is a wildcard
            foreach ($key in $options.Path.Keys) {
                if ($path -imatch "^$($key)$") {
                    if ($options.Group) {
                        return $key
                    }

                    return $path
                }
            }

            # return null
            return $null
        }
    }
}

function New-PodeLimitEndpointComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $EndpointName
    )

    # convert endpoint names into a hashtable for easier lookup
    $htEndpointName = @{}
    foreach ($e in $EndpointName) {
        $htEndpointName[$e] = $true
    }

    # pass back the endpoint component
    return @{
        Options     = @{
            EndpointName = $htEndpointName
            All          = (Test-PodeIsEmpty -Value $EndpointName)
        }
        ScriptBlock = {
            param($options)

            # current request endpoint name
            $endpointName = $WebEvent.Endpoint.Name

            # if the list is empty, or the list contains the endpoint name, then return the endpoint name
            if ($options.All -or $options.EndpointName.ContainsKey($endpointName)) {
                return $endpointName
            }

            # return null
            return $null
        }
    }
}

function New-PodeLimitMethodComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [ValidateSet('Connect', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        [string[]]
        $Method
    )

    # convert methods into a hashtable for easier lookup
    $htMethod = @{}
    foreach ($m in $Method) {
        $htMethod[$m] = $true
    }

    # pass back the method component
    return @{
        Options     = @{
            Method = $htMethod
            All    = (Test-PodeIsEmpty -Value $Method)
        }
        ScriptBlock = {
            param($options)

            # current request method
            $method = $WebEvent.Method

            # if the list is empty, or the list contains the method, then return the method
            if ($options.All -or $options.Method.ContainsKey($method)) {
                return $method
            }

            # return null
            return $null
        }
    }
}

function New-PodeLimitHeaderComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Name,

        [Parameter()]
        [string[]]
        $Value,

        [switch]
        $Group
    )

    # convert header names into a hashtable for easier lookup
    $htHeaderName = @{}
    foreach ($h in $Name) {
        $htHeaderName[$h] = $true
    }

    # convert header values into a hashtable for easier lookup
    $htHeaderValue = @{}
    foreach ($h in $Value) {
        $htHeaderValue[$h] = $true
    }

    # pass back the header component
    return @{
        Options     = @{
            HeaderNames  = $htHeaderName
            HeaderValues = $htHeaderValue
            Group        = $Group.IsPresent
            AllValues    = (Test-PodeIsEmpty -Value $Value)
        }
        ScriptBlock = {
            param($options)

            # current request headers
            $reqHeaders = $WebEvent.Request.Headers

            # loop through each specified header
            foreach ($header in $options.HeaderNames.Keys) {
                # skip if the header is not in the request
                if (!$reqHeaders.ContainsKey($header)) {
                    continue
                }

                # are we checking any specific values - if not, return name/value or just name
                if ($options.AllValues) {
                    if ($options.Group) {
                        return $header
                    }
                    return "$($header)=$($reqHeaders[$header])"
                }

                # otherwise, check if the header value is in the list
                if ($options.HeaderValues.ContainsKey($reqHeaders[$header])) {
                    return "$($header)=$($reqHeaders[$header])"
                }
            }

            # return null
            return $null
        }
    }
}