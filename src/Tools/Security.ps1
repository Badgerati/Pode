function Test-ValueAllowed
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('IP')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Value
    )

    # get black/white lists for type
    $whitelist = $PodeSession.Security.Whitelist[$Type]
    $blacklist = $PodeSession.Security.Blacklist[$Type]

    # are they empty?
    $wlEmpty = (Test-Empty $whitelist)
    $blEmpty = (Test-Empty $blacklist)

    # if both are empty, value is valid
    if ($wlEmpty -and $blEmpty) {
        return $true
    }

    # if value in blacklist, it's disallowed
    if (!$blEmpty -and $blacklist.ContainsKey($Value)) {
        return $false
    }

    # if value in whitelist, it's allowed
    if (!$wlEmpty -and $whitelist.ContainsKey($Value)) {
        return $true
    }

    # if we have a whitelist, it's disallowed (because it's not in there)
    if (!$wlEmpty) {
        return $false
    }

    # otherwise it's allowed (because it's not in the blacklist)
    return $true
}

function Whitelist
{
    param (
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
            whitelist $Type $_
        }

        return
    }

    # get black/white lists for type
    $whitelist = $PodeSession.Security.Whitelist[$Type]
    $blacklist = $PodeSession.Security.Blacklist[$Type]

    # setup up whitelist type
    if ($whitelist -eq $null) {
        $PodeSession.Security.Whitelist[$Type] = @{}
        $whitelist = $PodeSession.Security.Whitelist[$Type]
    }

    # ensure value not already in list
    elseif ($whitelist.ContainsKey($Value)) {
        return
    }

    # remove from blacklist
    if ($blacklist -ne $null -and $blacklist.ContainsKey($Value)) {
        $blacklist.Remove($Value)
    }

    # add to whitelist
    $whitelist.Add($Value, $true)
}

function Blacklist
{
    param (
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
            blacklist $Type $_
        }

        return
    }

    # get black/white lists for type
    $whitelist = $PodeSession.Security.Whitelist[$Type]
    $blacklist = $PodeSession.Security.Blacklist[$Type]

    # setup up blacklist type
    if ($blacklist -eq $null) {
        $PodeSession.Security.Blacklist[$Type] = @{}
        $blacklist = $PodeSession.Security.Blacklist[$Type]
    }

    # ensure value not already in list
    elseif ($blacklist.ContainsKey($Value)) {
        return
    }

    # remove from whitelist
    if ($whitelist -ne $null -and $whitelist.ContainsKey($Value)) {
        $whitelist.Remove($Value)
    }

    # add to blacklist
    $blacklist.Add($Value, $true)
}