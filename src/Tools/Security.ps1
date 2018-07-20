function Test-IPLimit
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
    $rules = $PodeSession.Limits.Rules[$type]
    $active = $PodeSession.Limits.Active[$type]
    $now = [DateTime]::UtcNow

    # if there are no rules, it's valid
    if (Test-Empty $rules) {
        return $true
    }

    # is the ip active?
    $_active_ip = $active[$IP.String]

    # the ip is active
    if ($null -ne $_active_ip) {
        # if limit is -1, always allowed
        if ($_active_ip.Limit -eq -1) {
            return $true
        }

        # check expire time, a reset if needed
        if ($now -ge $_active_ip.Expire) {
            $_active_ip.Rate = 0
            $_active_ip.Expire = $now.AddSeconds($_active_ip.Seconds)
        }

        # are we over the limit?
        if ($_active_ip.Rate -ge $_active_ip.Limit) {
            return $false
        }

        # increment the rate
        $_active_ip.Rate++
        return $true
    }

    # the ip isn't active
    else {
        # get the ip's rule
        $_rule_ip = ($rules.Values | Where-Object { Test-IPAddressInRange -IP $IP -LowerIP $_.Lower -UpperIP $_.Upper } | Select-Object -First 1)

        # if ip not in rules, it's valid
        # (add to active list as always allowed - saves running where search everytime)
        if ($null -eq $_rule_ip) {
            $active.Add($IP.String, @{
                'Limit' = -1
            })

            return $true
        }

        # add ip to active list
        $active.Add($IP.String, @{
            'Limit' = $_rule_ip.Limit;
            'Rate' = 1;
            'Seconds' = $_rule_ip.Seconds;
            'Expire' = $now.AddSeconds($_rule_ip.Seconds);
        })

        # if limit is 0, it's never allowed
        return ($_rule_ip -ne 0)
    }
}

function Test-IPAccess
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
    $allow = $PodeSession.Access.Allow[$type]
    $deny = $PodeSession.Access.Deny[$type]

    # are they empty?
    $alEmpty = (Test-Empty $allow)
    $dnEmpty = (Test-Empty $deny)

    # if both are empty, value is valid
    if ($alEmpty -and $dnEmpty) {
        return $true
    }

    # if value in allow, it's allowed
    if (!$alEmpty -and ($allow.Values | Where-Object { Test-IPAddressInRange -IP $IP -LowerIP $_.Lower -UpperIP $_.Upper } | Measure-Object).Count -gt 0) {
        return $true
    }

    # if value in deny, it's disallowed
    if (!$dnEmpty -and ($deny.Values | Where-Object { Test-IPAddressInRange -IP $IP -LowerIP $_.Lower -UpperIP $_.Upper } | Measure-Object).Count -gt 0) {
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
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [object]
        $Value,

        [Parameter(Mandatory=$true)]
        [int]
        $Limit,

        [Parameter(Mandatory=$true)]
        [int]
        $Seconds
    )

    # if it's array add them all
    if ((Get-Type $Value).BaseName -ieq 'array') {
        $Value | ForEach-Object {
            limit -Type $Type -Value $_ -Limit $Limit -Seconds $Seconds
        }

        return
    }

    # call the appropriate limit method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            Add-IPLimit -IP $Value -Limit $Limit -Seconds $Seconds
        }
    }
}

function Add-IPLimit
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
        $Seconds
    )

    # current limit type
    $type = 'IP'

    # get current rules
    $rules = $PodeSession.Limits.Rules[$type]

    # setup up perm type
    if ($null -eq $rules) {
        $PodeSession.Limits.Rules[$type] = @{}
        $PodeSession.Limits.Active[$type] = @{}
        $rules = $PodeSession.Limits.Rules[$type]
    }

    # have we already added the ip?
    elseif ($rules.ContainsKey($IP)) {
        return
    }

    # calculate the lower/upper ip bounds
    if (Test-IPAddressIsSubnetMask -IP $IP) {
        $_tmp = Get-SubnetRange -SubnetMask $IP
        $_tmpLo = Get-IPAddress -IP $_tmp.Lower
        $_tmpHi = Get-IPAddress -IP $_tmp.Upper
    }
    elseif (Test-IPAddressAny -IP $IP) {
        $_tmpLo = Get-IPAddress -IP '0.0.0.0'
        $_tmpHi = Get-IPAddress -IP '255.255.255.255'
    }
    else {
        $_tmpLo = Get-IPAddress -IP $IP
        $_tmpHi = $_tmpLo
    }

    # add limit rule for ip
    $rules.Add($IP, @{
        'Limit' = $Limit;
        'Seconds' = $Seconds;
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
        [string]
        $Permission,

        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [object]
        $Value
    )

    # if it's array add them all
    if ((Get-Type $Value).BaseName -ieq 'array') {
        $Value | ForEach-Object {
            access -Permission $Permission -Type $Type -Value $_
        }

        return
    }

    # call the appropriate access method
    switch ($Type.ToLowerInvariant())
    {
        'ip' {
            Add-IPAccess -Permission $Permission -IP $Value
        }
    }
}

function Add-IPAccess
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
    $permType = $PodeSession.Access[$Permission][$type]
    $oppType = $PodeSession.Access[$opp][$type]

    # setup up perm type
    if ($null -eq $permType) {
        $PodeSession.Access[$Permission][$type] = @{}
        $permType = $PodeSession.Access[$Permission][$type]
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
    if (Test-IPAddressIsSubnetMask -IP $IP) {
        $_tmp = Get-SubnetRange -SubnetMask $IP
        $_tmpLo = Get-IPAddress -IP $_tmp.Lower
        $_tmpHi = Get-IPAddress -IP $_tmp.Upper
    }
    elseif (Test-IPAddressAny -IP $IP) {
        $_tmpLo = Get-IPAddress -IP '0.0.0.0'
        $_tmpHi = Get-IPAddress -IP '255.255.255.255'
    }
    else {
        $_tmpLo = Get-IPAddress -IP $IP
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