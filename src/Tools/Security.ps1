function Test-PodeIPLimit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $IP
    )

    $type = 'IP'

    # get the ip address in bytes
    $IP = @{
        'String' = $IP.IPAddressToString;
        'Family' = $IP.AddressFamily;
        'Bytes' = $IP.GetAddressBytes();
    }

    # get the limit rules and active list
    $rules = $PodeContext.Server.Limits.Rules[$type]
    $active = $PodeContext.Server.Limits.Active[$type]
    $now = [DateTime]::UtcNow

    # if there are no rules, it's valid
    if (Test-Empty $rules) {
        return $true
    }

    # is the ip active? (get a direct match, then try grouped subnets)
    $_active_ip = $active[$IP.String]
    if ($null -eq $_active_ip) {
        $_groups = ($active.Keys | Where-Object { $active[$_].Rule.Grouped } | ForEach-Object { $active[$_] })
        $_active_ip = ($_groups | Where-Object { Test-PodeIPAddressInRange -IP $IP -LowerIP $_.Rule.Lower -UpperIP $_.Rule.Upper } | Select-Object -First 1)
    }

    # the ip is active, or part of a grouped subnet
    if ($null -ne $_active_ip) {
        # if limit is -1, always allowed
        if ($_active_ip.Rule.Limit -eq -1) {
            return $true
        }

        # check expire time, a reset if needed
        if ($now -ge $_active_ip.Expire) {
            $_active_ip.Rate = 0
            $_active_ip.Expire = $now.AddSeconds($_active_ip.Rule.Seconds)
        }

        # are we over the limit?
        if ($_active_ip.Rate -ge $_active_ip.Rule.Limit) {
            return $false
        }

        # increment the rate
        $_active_ip.Rate++
        return $true
    }

    # the ip isn't active
    else {
        # get the ip's rule
        $_rule_ip = ($rules.Values | Where-Object { Test-PodeIPAddressInRange -IP $IP -LowerIP $_.Lower -UpperIP $_.Upper } | Select-Object -First 1)

        # if ip not in rules, it's valid
        # (add to active list as always allowed - saves running where search everytime)
        if ($null -eq $_rule_ip) {
            $active.Add($IP.String, @{
                'Rule' = @{
                    'Limit' = -1
                }
            })

            return $true
        }

        # add ip to active list (ip if not grouped, else the subnet if it's grouped)
        $_ip = (iftet $_rule_ip.Grouped $_rule_ip.IP $IP.String)

        $active.Add($_ip, @{
            'Rule' = $_rule_ip;
            'Rate' = 1;
            'Expire' = $now.AddSeconds($_rule_ip.Seconds);
        })

        # if limit is 0, it's never allowed
        return ($_rule_ip -ne 0)
    }
}

function Test-PodeIPAccess
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $IP
    )

    $type = 'IP'

    # get the ip address in bytes
    $IP = @{
        'Family' = $IP.AddressFamily;
        'Bytes' = $IP.GetAddressBytes();
    }

    # get permission lists for ip
    $allow = $PodeContext.Server.Access.Allow[$type]
    $deny = $PodeContext.Server.Access.Deny[$type]

    # are they empty?
    $alEmpty = (Test-Empty $allow)
    $dnEmpty = (Test-Empty $deny)

    # if both are empty, value is valid
    if ($alEmpty -and $dnEmpty) {
        return $true
    }

    # if value in allow, it's allowed
    if (!$alEmpty -and ($allow.Values | Where-Object { Test-PodeIPAddressInRange -IP $IP -LowerIP $_.Lower -UpperIP $_.Upper } | Measure-Object).Count -gt 0) {
        return $true
    }

    # if value in deny, it's disallowed
    if (!$dnEmpty -and ($deny.Values | Where-Object { Test-PodeIPAddressInRange -IP $IP -LowerIP $_.Lower -UpperIP $_.Upper } | Measure-Object).Count -gt 0) {
        return $false
    }

    # if we have an allow, it's disallowed (because it's not in there)
    if (!$alEmpty) {
        return $false
    }

    # otherwise it's allowed (because it's not in the deny)
    return $true
}

function Limit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [Alias('t')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('v')]
        [object]
        $Value,

        [Parameter(Mandatory=$true)]
        [Alias('l')]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [Alias('s')]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # if it's array add them all
    if ((Get-PodeType $Value).BaseName -ieq 'array') {
        $Value | ForEach-Object {
            limit -Type $Type -Value $_ -Limit $Limit -Seconds $Seconds -Group:$Group
        }

        return
    }

    # call the appropriate limit method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            Add-PodeIPLimit -IP $Value -Limit $Limit -Seconds $Seconds -Group:$Group
        }
    }
}

function Add-PodeIPLimit
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]
        $IP,

        [Parameter(Mandatory=$true)]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [int]
        $Seconds,

        [switch]
        $Group
    )

    # current limit type
    $type = 'IP'

    # ensure limit and seconds are non-zero and negative
    if ($Limit -le 0) {
        throw "Limit value cannot be 0 or less for $($IP)"
    }

    if ($Seconds -le 0) {
        throw "Seconds value cannot be 0 or less for $($IP)"
    }

    # get current rules
    $rules = $PodeContext.Server.Limits.Rules[$type]

    # setup up perm type
    if ($null -eq $rules) {
        $PodeContext.Server.Limits.Rules[$type] = @{}
        $PodeContext.Server.Limits.Active[$type] = @{}
        $rules = $PodeContext.Server.Limits.Rules[$type]
    }

    # have we already added the ip?
    elseif ($rules.ContainsKey($IP)) {
        return
    }

    # calculate the lower/upper ip bounds
    if (Test-PodeIPAddressIsSubnetMask -IP $IP) {
        $_tmp = Get-PodeSubnetRange -SubnetMask $IP
        $_tmpLo = Get-PodeIPAddress -IP $_tmp.Lower
        $_tmpHi = Get-PodeIPAddress -IP $_tmp.Upper
    }
    elseif (Test-PodeIPAddressAny -IP $IP) {
        $_tmpLo = Get-PodeIPAddress -IP '0.0.0.0'
        $_tmpHi = Get-PodeIPAddress -IP '255.255.255.255'
    }
    else {
        $_tmpLo = Get-PodeIPAddress -IP $IP
        $_tmpHi = $_tmpLo
    }

    # add limit rule for ip
    $rules.Add($IP, @{
        'Limit' = $Limit;
        'Seconds' = $Seconds;
        'Grouped' = [bool]$Group;
        'IP' = $IP;
        'Lower' = @{
            'Family' = $_tmpLo.AddressFamily;
            'Bytes' = $_tmpLo.GetAddressBytes();
        };
        'Upper' = @{
            'Family' = $_tmpHi.AddressFamily;
            'Bytes' = $_tmpHi.GetAddressBytes();
        };
    })
}

function Access
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Allow', 'Deny')]
        [Alias('p')]
        [string]
        $Permission,

        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [Alias('t')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('v')]
        [object]
        $Value
    )

    # if it's array add them all
    if ((Get-PodeType $Value).BaseName -ieq 'array') {
        $Value | ForEach-Object {
            access -Permission $Permission -Type $Type -Value $_
        }

        return
    }

    # call the appropriate access method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            Add-PodeIPAccess -Permission $Permission -IP $Value
        }
    }
}

function Add-PodeIPAccess
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Allow', 'Deny')]
        [string]
        $Permission,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [string]
        $IP
    )

    # current access type
    $type = 'IP'

    # get opposite permission
    $opp = "$(if ($Permission -ieq 'allow') { 'Deny' } else { 'Allow' })"

    # get permission lists for type
    $permType = $PodeContext.Server.Access[$Permission][$type]
    $oppType = $PodeContext.Server.Access[$opp][$type]

    # setup up perm type
    if ($null -eq $permType) {
        $PodeContext.Server.Access[$Permission][$type] = @{}
        $permType = $PodeContext.Server.Access[$Permission][$type]
    }

    # have we already added the ip?
    elseif ($permType.ContainsKey($IP)) {
        return
    }

    # remove from opp type
    if ($null -ne $oppType -and $oppType.ContainsKey($IP)) {
        $oppType.Remove($IP)
    }

    # calculate the lower/upper ip bounds
    if (Test-PodeIPAddressIsSubnetMask -IP $IP) {
        $_tmp = Get-PodeSubnetRange -SubnetMask $IP
        $_tmpLo = Get-PodeIPAddress -IP $_tmp.Lower
        $_tmpHi = Get-PodeIPAddress -IP $_tmp.Upper
    }
    elseif (Test-PodeIPAddressAny -IP $IP) {
        $_tmpLo = Get-PodeIPAddress -IP '0.0.0.0'
        $_tmpHi = Get-PodeIPAddress -IP '255.255.255.255'
    }
    else {
        $_tmpLo = Get-PodeIPAddress -IP $IP
        $_tmpHi = $_tmpLo
    }

    # add access rule for ip
    $permType.Add($IP, @{
        'Lower' = @{
            'Family' = $_tmpLo.AddressFamily;
            'Bytes' = $_tmpLo.GetAddressBytes();
        };
        'Upper' = @{
            'Family' = $_tmpHi.AddressFamily;
            'Bytes' = $_tmpHi.GetAddressBytes();
        };
    })
}