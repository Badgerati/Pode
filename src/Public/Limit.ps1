<#
.SYNOPSIS
Adds an access rule to allow or deny IP addresses. This is a legacy function, use Add-PodeLimitAccessRule instead.

.DESCRIPTION
Adds an access rule to allow or deny IP addresses. This is a legacy function, use Add-PodeLimitAccessRule instead.

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
Adds rate limiting rules for an IP addresses, Routes, or Endpoints. This is a legacy function, use Add-PodeLimitRateRule instead.

.DESCRIPTION
Adds rate limiting rules for an IP addresses, Routes, or Endpoints. This is a legacy function, use Add-PodeLimitRateRule instead.

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
            $component = New-PodeLimitEndpointComponent -Name $Values
        }
    }

    Add-PodeLimitRateRule `
        -Name (New-PodeGuid) `
        -Limit $Limit `
        -Duration ($Seconds * 1000) `
        -Component $component
}

<#
.SYNOPSIS
Adds a rate limit rule.

.DESCRIPTION
Adds a rate limit rule.

.PARAMETER Name
The name of the rate limit rule.

.PARAMETER Component
The component(s) to check. This can be a single, or an array of components.

.PARAMETER Limit
The limit for the rule - the maximum number of requests to allow within the duration.

.PARAMETER Duration
The duration for the rule, in milliseconds. (Default: 60000)

.PARAMETER StatusCode
The status code to return when the limit is reached. (Default: 429)

.PARAMETER Priority
The priority of the rule. The higher the number, the higher the priority. (Default: [int]::MinValue)

.EXAMPLE
# limit to 10 requests per minute for all IPs
Add-PodeLimitRateRule -Name 'rule1' -Limit 10 -Component @(
    New-PodeLimitIPComponent
)

.EXAMPLE
# limit to 5 requests per minute for all IPs and the /downloads route
Add-PodeLimitRateRule -Name 'rule1' -Limit 5 -Component @(
    New-PodeLimitIPComponent
    New-PodeLimitRouteComponent -Path '/downloads'
)

.EXAMPLE
# limit to 1 request, per 30 seconds, for all IPs in a subnet grouped, to the /downloads route
Add-PodeLimitRateRule -Name 'rule1' -Limit 1 -Duration 30000 -Component @(
    New-PodeLimitIPComponent -IP '10.0.0.0/24' -Group
    New-PodeLimitRouteComponent -Path '/downloads'
)

.EXAMPLE
# limit to 10 requests per second, for specific IPs, with a custom status code and priority
Add-PodeLimitRateRule -Name 'rule1' -Limit 10 -Duration 1000 -StatusCode 401 -Priority 100 -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1', '192.0.0.1', '10.0.0.1'
)
#>
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
        [ValidateRange(0, [int]::MaxValue)]
        [int]
        $Limit,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]
        $Duration = 60000,

        [Parameter()]
        [int]
        $StatusCode = 429,

        [Parameter()]
        [int]
        $Priority = [int]::MinValue
    )

    if (Test-PodeLimitRateRule -Name $Name) {
        # A rate limit rule with the name '$($Name)' already exists
        throw ($PodeLocale.rateLimitRuleAlreadyExistsExceptionMessage -f $Name)
    }

    $PodeContext.Server.Limits.Rate.Rules[$Name] = @{
        Name       = $Name
        Components = $Component
        Limit      = $Limit
        Duration   = $Duration
        StatusCode = $StatusCode
        Priority   = $Priority
        Active     = [System.Collections.Concurrent.ConcurrentDictionary[string, hashtable]]::new()
    }

    $PodeContext.Server.Limits.Rate.RulesAltered = $true
    Add-PodeLimitRateTimer
}

<#
.SYNOPSIS
Updates a rate limit rule.

.DESCRIPTION
Updates a rate limit rule.

.PARAMETER Name
The name of the rate limit rule.

.PARAMETER Limit
The new limit for the rule. If not supplied, the limit will not be updated.

.PARAMETER Duration
The new duration for the rule, in milliseconds. If not supplied, the duration will not be updated.

.PARAMETER StatusCode
The new status code for the rule. If not supplied, the status code will not be updated.

.EXAMPLE
Update-PodeLimitRateRule -Name 'rule1' -Limit 10

.EXAMPLE
Update-PodeLimitRateRule -Name 'rule1' -Duration 10000

.EXAMPLE
Update-PodeLimitRateRule -Name 'rule1' -StatusCode 429

.EXAMPLE
Update-PodeLimitRateRule -Name 'rule1' -Limit 10 -Duration 10000 -StatusCode 429
#>
function Update-PodeLimitRateRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [int]
        $Limit = -1,

        [Parameter()]
        [int]
        $Duration = -1,

        [Parameter()]
        [int]
        $StatusCode = -1
    )

    $rule = $PodeContext.Server.Limits.Rate.Rules[$Name]
    if (!$rule) {
        # A rate limit rule with the name '$($Name)' does not exist
        throw ($PodeLocale.rateLimitRuleDoesNotExistExceptionMessage -f $Name)
    }

    if ($Limit -ge 0) {
        $rule.Limit = $Limit
    }

    if ($Duration -gt 0) {
        $rule.Duration = $Duration
    }

    if ($StatusCode -gt 0) {
        $rule.StatusCode = $StatusCode
    }
}

<#
.SYNOPSIS
Removes a rate limit rule.

.DESCRIPTION
Removes a rate limit rule.

.PARAMETER Name
The name of the rate limit rule.

.EXAMPLE
Remove-PodeLimitRateRule -Name 'rule1'
#>
function Remove-PodeLimitRateRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    $null = $PodeContext.Server.Limits.Rate.Rules.Remove($Name)
    $PodeContext.Server.Limits.Rate.RulesAltered = $true
    Remove-PodeLimitRateTimer
}

<#
.SYNOPSIS
Tests if a rate limit rule exists.

.DESCRIPTION
Tests if a rate limit rule exists.

.PARAMETER Name
The name of the rate limit rule.

.EXAMPLE
Test-PodeLimitRateRule -Name 'rule1'

.NOTES
This function is used to test if a rate limit rule exists.
#>
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

<#
.SYNOPSIS
Gets a rate limit rule by name.

.DESCRIPTION
Gets a rate limit rule by name.

.PARAMETER Name
The name(s) of the rate limit rule.

.EXAMPLE
$rules = Get-PodeLimitRateRule -Name 'rule1'

.EXAMPLE
$rules = Get-PodeLimitRateRule -Name 'rule1', 'rule2'

.EXAMPLE
$rules = Get-PodeLimitRateRule

.OUTPUTS
A hashtable array containing the rate limit rule(s).
#>
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

<#
.SYNOPSIS
Adds an access limit rule.

.DESCRIPTION
Adds an access limit rule.

.PARAMETER Name
The name of the access rule.

.PARAMETER Component
The component(s) to check. This can be a single, or an array of components.

.PARAMETER Action
The action to take. Either 'Allow' or 'Deny'.

.PARAMETER StatusCode
The status code to return. (Default: 403)

.PARAMETER Priority
The priority of the rule. The higher the number, the higher the priority. (Default: [int]::MinValue)

.EXAMPLE
# only allow localhost
Add-PodeLimitAccessRule -Name 'rule1' -Action Allow -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1'
)

.EXAMPLE
# only allow localhost and the /downloads route
Add-PodeLimitAccessRule -Name 'rule1' -Action Allow -Component @(
    New-PodeLimitIPComponent -IP '127.0.0.1'
    New-PodeLimitRouteComponent -Path '/downloads'
)

.EXAMPLE
# deny all requests
Add-PodeLimitAccessRule -Name 'rule1' -Action Deny -Component @(
    New-PodeLimitIPComponent
)

.EXAMPLE
# deny all requests from a subnet, with a custom status code
Add-PodeLimitAccessRule -Name 'rule1' -Action Deny -StatusCode 401 -Component @(
    New-PodeLimitIPComponent -IP '10.0.0.0/24'
)

.EXAMPLE
# deny all requests from a subnet, with a custom status code and priority
Add-PodeLimitAccessRule -Name 'rule1' -Action Deny -StatusCode 401 -Priority 100 -Component @(
    New-PodeLimitIPComponent -IP '192.0.1.0/16'
)
#>
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
        $StatusCode = 403,

        [Parameter()]
        [int]
        $Priority = [int]::MinValue
    )

    if (Test-PodeLimitAccessRule -Name $Name) {
        # An access limit rule with the name '$($Name)' already exists
        throw ($PodeLocale.accessLimitRuleAlreadyExistsExceptionMessage -f $Name)
    }

    $PodeContext.Server.Limits.Access.Rules[$Name] = @{
        Name       = $Name
        Components = $Component
        Action     = $Action
        StatusCode = $StatusCode
        Priority   = $Priority
    }

    $PodeContext.Server.Limits.Access.RulesAltered = $true

    # set the flag if we have any allow rules
    if ($Action -eq 'Allow') {
        $PodeContext.Server.Limits.Access.HaveAllowRules = $true
    }
}

<#
.SYNOPSIS
Updates an access rule.

.DESCRIPTION
Updates an access rule.

.PARAMETER Name
The name of the access rule.

.PARAMETER Action
The action to take. Either 'Allow' or 'Deny'. If not supplied, the action will not be updated.

.PARAMETER StatusCode
The status code to return. If not supplied, the status code will not be updated.

.EXAMPLE
Update-PodeLimitAccessRule -Name 'rule1' -Action 'Deny'

.EXAMPLE
Update-PodeLimitAccessRule -Name 'rule1' -StatusCode 404

.EXAMPLE
Update-PodeLimitAccessRule -Name 'rule1' -Action 'Allow' -StatusCode 200
#>
function Update-PodeLimitAccessRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Action = $null,

        [Parameter()]
        [int]
        $StatusCode = -1
    )

    $rule = $PodeContext.Server.Limits.Access.Rules[$Name]
    if (!$rule) {
        # An access limit rule with the name '$($Name)' does not exist
        throw ($PodeLocale.accessLimitRuleDoesNotExistExceptionMessage -f $Name)
    }

    if (![string]::IsNullOrWhiteSpace($Action)) {
        $rule.Action = $Action
    }

    if ($StatusCode -gt 0) {
        $rule.StatusCode = $StatusCode
    }

    # reset the flag if we have any allow rules
    $PodeContext.Server.Limits.Access.HaveAllowRules = ($PodeContext.Server.Limits.Access.Rules.Value |
            Where-Object { $_.Action -eq 'Allow' } |
            Measure-Object).Count -gt 0
}

<#
.SYNOPSIS
Removes an access rule.

.DESCRIPTION
Removes an access rule.

.PARAMETER Name
The name of the access rule.

.EXAMPLE
Remove-PodeLimitAccessRule -Name 'rule1'
#>
function Remove-PodeLimitAccessRule {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Name
    )

    # remove the rule
    $null = $PodeContext.Server.Limits.Access.Rules.Remove($Name)
    $PodeContext.Server.Limits.Access.RulesAltered = $true

    # reset the flag if we have any allow rules
    $PodeContext.Server.Limits.Access.HaveAllowRules = ($PodeContext.Server.Limits.Access.Rules.Value |
            Where-Object { $_.Action -eq 'Allow' } |
            Measure-Object).Count -gt 0
}

<#
.SYNOPSIS
Tests if an access rule exists.

.DESCRIPTION
Tests if an access rule exists.

.PARAMETER Name
The name of the access rule.

.EXAMPLE
Test-PodeLimitAccessRule -Name 'rule1'

.OUTPUTS
A boolean indicating if the access rule exists.
#>
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

<#
.SYNOPSIS
Gets an access rule by name.

.DESCRIPTION
Gets an access rule by name.

.PARAMETER Name
The name(s) of the access rule.

.EXAMPLE
$rules = Get-PodeLimitAccessRule -Name 'rule1'

.EXAMPLE
$rules = Get-PodeLimitAccessRule -Name 'rule1', 'rule2'

.EXAMPLE
$rules = Get-PodeLimitAccessRule

.OUTPUTS
A hashtable array containing the access rule(s).
#>
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

<#
.SYNOPSIS
Creates a new Limit IP component.

.DESCRIPTION
Creates a new Limit IP component. This supports the WebEvent, SmtpEvent, and TcpEvent IPs.

.PARAMETER IP
The IP address(es) to check. Supports raw IPs, subnets, local, and any.

.PARAMETER Location
Where to get the IP from: RemoteAddress or XForwardedFor. (Default: RemoteAddress)

.PARAMETER XForwardedForType
If the Location is XForwardedFor, which IP in the X-Forwarded-For header to use: Leftmost, Rightmost, or All. (Default: Leftmost)
If Leftmost, the first IP in the X-Forwarded-For header will be used.
If Rightmost, the last IP in the X-Forwarded-For header will be used.
If All, all IPs in the X-Forwarded-For header will be used - at least one must match.

.PARAMETER Group
If supplied, IPs in a subnet will be treated as a single entity.

.EXAMPLE
New-PodeLimitIPComponent

.EXAMPLE
New-PodeLimitIPComponent -IP '127.0.0.1'

.EXAMPLE
New-PodeLimitIPComponent -IP '10.0.0.0/24'

.EXAMPLE
New-PodeLimitIPComponent -IP 'localhost'

.EXAMPLE
New-PodeLimitIPComponent -IP 'all'

.EXAMPLE
New-PodeLimitIPComponent -IP '192.0.1.0/16' -Group

.EXAMPLE
New-PodeLimitIPComponent -IP '10.0.0.1' -Location XForwardedFor

.EXAMPLE
New-PodeLimitIPComponent -IP '192.0.1.0/16' -Group -Location XForwardedFor -XForwardedForType Rightmost

.OUTPUTS
A hashtable containing the options and scriptblock for the IP component.
The scriptblock will return the IP - or subnet for grouped - if found, or null if not.
#>
function New-PodeLimitIPComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $IP,

        [Parameter()]
        [ValidateSet('RemoteAddress', 'XForwardedFor')]
        [string]
        $Location = 'RemoteAddress',

        [Parameter()]
        [ValidateSet('Leftmost', 'Rightmost', 'All')]
        [string]
        $XForwardedForType = 'Leftmost',

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
            # The IP address supplied is invalid: {0}
            throw ($PodeLocale.invalidIpAddressExceptionMessage -f $_ip)
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
            IP                = $ipDetails
            Location          = $Location.ToLowerInvariant()
            XForwardedForType = $XForwardedForType.ToLowerInvariant()
            Group             = $Group.IsPresent
        }
        ScriptBlock = {
            param($options)

            # current request ip - for webevent, smtpevent, or tcpevent
            # for webevent, we can get the ip from the remote address or x-forwarded-for
            $ipAddresses = $null

            if ($WebEvent) {
                switch ($options.Location) {
                    'remoteaddress' {
                        $ipAddresses = @($WebEvent.Request.RemoteEndPoint.Address)
                    }
                    'xforwardedfor' {
                        $xForwardedFor = $WebEvent.Request.Headers['X-Forwarded-For']
                        if ([string]::IsNullOrEmpty($xForwardedFor)) {
                            return $null
                        }

                        $xffIps = $xForwardedFor.Split(',')
                        switch ($options.XForwardedForType) {
                            'leftmost' {
                                $ipAddresses = @(Get-PodeIPAddress -IP $xffIps[0].Trim() -ContainsPort)
                            }
                            'rightmost' {
                                $ipAddresses = @(Get-PodeIPAddress -IP $xffIps[-1].Trim() -ContainsPort)
                            }
                            'all' {
                                $ipAddresses = @(foreach ($ip in $xffIps) { Get-PodeIPAddress -IP $ip.Trim() -ContainsPort })
                            }
                        }
                    }
                }
            }
            elseif ($SmtpEvent) {
                $ipAddresses = @($SmtpEvent.Request.RemoteEndPoint.Address)
            }
            elseif ($TcpEvent) {
                $ipAddresses = @($TcpEvent.Request.RemoteEndPoint.Address)
            }

            # if we have no ip addresses, then return null
            if (($null -eq $ipAddresses) -or ($ipAddresses.Length -eq 0)) {
                return $null
            }

            # loop through each ip address
            for ($i = $ipAddresses.Length - 1; $i -ge 0; $i--) {
                $ip = $ipAddresses[$i]

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
                if ($options.IP.Any -and ($i -eq 0)) {
                    if ($options.Group) {
                        return '*'
                    }

                    return $ipDetails.Value
                }
            }

            # ip didn't match any rules
            return $null
        }
    }
}

<#
.SYNOPSIS
Creates a new Limit Route component.

.DESCRIPTION
Creates a new Limit Route component. This supports the WebEvent routes.

.PARAMETER Path
The route path(s) to check. This can be a full path, or a wildcard path.

.PARAMETER Group
If supplied, the routes will be grouped by any wildcard, ignoring the full path.
For example, any routes matching "/api/*" will be grouped as "/api/*", and not "/api/test" or "/api/test/hello".

.EXAMPLE
New-PodeLimitRouteComponent -Path '/downloads'

.EXAMPLE
New-PodeLimitRouteComponent -Path '/downloads', '/api/*'

.EXAMPLE
New-PodeLimitRouteComponent -Path '/api/*' -Group

.OUTPUTS
A hashtable containing the options and scriptblock for the route component.
The scriptblock will return the route path if found, or null if not.
#>
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
            if ([string]::IsNullOrEmpty($path)) {
                return $null
            }

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

<#
.SYNOPSIS
Creates a new Limit Endpoint component.

.DESCRIPTION
Creates a new Limit Endpoint component. This supports the WebEvent, SmtpEvent, and TcpEvent endpoints.

.PARAMETER Name
The endpoint name(s) to check.

.EXAMPLE
New-PodeLimitEndpointComponent

.EXAMPLE
New-PodeLimitEndpointComponent -Name 'api'

.OUTPUTS
A hashtable containing the options and scriptblock for the endpoint component.
The scriptblock will return the endpoint name if found, or null if not.
#>
function New-PodeLimitEndpointComponent {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    # convert endpoint names into a hashtable for easier lookup
    $htName = @{}
    foreach ($e in $Name) {
        $htName[$e] = $true
    }

    # pass back the endpoint component
    return @{
        Options     = @{
            EndpointName = $htName
            All          = (Test-PodeIsEmpty -Value $Name)
        }
        ScriptBlock = {
            param($options)

            # current request endpoint name - from webevent, smtpevent, or tcpevent
            $endpointName = $null
            if ($WebEvent) {
                $endpointName = $WebEvent.Endpoint.Name
            }
            elseif ($SmtpEvent) {
                $endpointName = $SmtpEvent.Endpoint.Name
            }
            elseif ($TcpEvent) {
                $endpointName = $TcpEvent.Endpoint.Name
            }

            if ($null -eq $endpointName) {
                return $null
            }

            # if the list is empty, or the list contains the endpoint name, then return the endpoint name
            if ($options.All -or $options.EndpointName.ContainsKey($endpointName)) {
                return $endpointName
            }

            # return null
            return $null
        }
    }
}

<#
.SYNOPSIS
Creates a new Limit HTTP Method component.

.DESCRIPTION
Creates a new Limit HTTP Method component. This supports the WebEvent methods.

.PARAMETER Method
The HTTP method(s) to check.

.EXAMPLE
New-PodeLimitMethodComponent

.EXAMPLE
New-PodeLimitMethodComponent -Method 'Get'

.EXAMPLE
New-PodeLimitMethodComponent -Method 'Get', 'Post'

.OUTPUTS
A hashtable containing the options and scriptblock for the method component.
The scriptblock will return the method if found, or null if not.
#>
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
            if ([string]::IsNullOrEmpty($method)) {
                return $null
            }

            # if the list is empty, or the list contains the method, then return the method
            if ($options.All -or $options.Method.ContainsKey($method)) {
                return $method
            }

            # return null
            return $null
        }
    }
}

<#
.SYNOPSIS
Creates a new Limit Header component.

.DESCRIPTION
Creates a new Limit Header component. This support WebEvent and SmtpEvent headers.

.PARAMETER Name
The name of the header(s) to check.

.PARAMETER Value
The value of the header(s) to check.

.PARAMETER Group
If supplied, the headers will be grouped by name, ignoring the value.
For example, any headers matching "X-AuthToken" will be grouped as "X-AuthToken", and not "X-AuthToken=123".

.EXAMPLE
New-PodeLimitHeaderComponent -Name 'X-AuthToken'

.EXAMPLE
New-PodeLimitHeaderComponent -Name 'X-AuthToken', 'X-AuthKey'

.EXAMPLE
New-PodeLimitHeaderComponent -Name 'X-AuthToken' -Value '12345'

.EXAMPLE
New-PodeLimitHeaderComponent -Name 'X-AuthToken' -Group

.OUTPUTS
A hashtable containing the options and scriptblock for the header component.
The scriptblock will return the header name and value if found, or just the name if Group is supplied.
#>
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

            # current request headers - from webevent or smtpevent
            $reqHeaders = @{}
            if ($WebEvent) {
                $reqHeaders = $WebEvent.Request.Headers
            }
            elseif ($SmtpEvent) {
                $reqHeaders = $SmtpEvent.Request.Headers
            }

            if ($reqHeaders.Count -eq 0) {
                return $null
            }

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