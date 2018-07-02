function Test-ValueAccess
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

    # get permission lists for type
    $allow = $PodeSession.Access.Allow[$Type]
    $deny = $PodeSession.Access.Deny[$Type]

    # are they empty?
    $alEmpty = (Test-Empty $allow)
    $dnEmpty = (Test-Empty $deny)

    # if both are empty, value is valid
    if ($alEmpty -and $dnEmpty) {
        return $true
    }

    # if value in allow, it's allowed
    if (!$alEmpty -and $allow.ContainsKey($Value)) {
        return $true
    }

    # if value in deny, it's disallowed
    if (!$dnEmpty -and $deny.ContainsKey($Value)) {
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

    # get opposite permission
    $opp = "$(if ($Permission -ieq 'allow') { 'Deny' } else { 'Allow' })"

    # get permission lists for type
    $permType = $PodeSession.Access[$Permission][$Type]
    $oppType = $PodeSession.Access[$opp][$Type]

    # setup up perm type
    if ($permType -eq $null) {
        $PodeSession.Access[$Permission][$Type] = @{}
        $permType = $PodeSession.Access[$Permission][$Type]
    }

    # ensure value not already in perm type list
    elseif ($permType.ContainsKey($Value)) {
        return
    }

    # remove from opp type
    if ($oppType -ne $null -and $oppType.ContainsKey($Value)) {
        $oppType.Remove($Value)
    }

    # add to perm type
    $permType.Add($Value, $true)
}