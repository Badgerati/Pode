function Test-IPAccess
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $IP
    )

    $type = 'IP'
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
            access $Permission $Type $_
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
    if ($permType -eq $null) {
        $PodeSession.Access[$Permission][$type] = @{}
        $permType = $PodeSession.Access[$Permission][$type]
    }

    # have we already added the ip?
    elseif ($permType.ContainsKey($IP)) {
        return
    }

    # remove from opp type
    if ($oppType -ne $null -and $oppType.ContainsKey($IP)) {
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

    $permType.Add($IP, @{
        'Lower' = @{
            'Family' = $_tmpLo.AddressFamily;
            'Bytes' = $_tmpLo.GetAddressBytes();
        };
        'Upper' = @{
            'Family' = $_tmpHi.AddressFamily;
            'Bytes' = $_tmpHi.GetAddressBytes();
        }
    })
}