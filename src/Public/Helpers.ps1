function Coalesce
{
    param (
        [Parameter()]
        $Value1,

        [Parameter()]
        $Value2
    )

    return (iftet (Test-Empty $Value1) $Value2 $Value1)
}

function Invoke-ScriptBlock
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [Alias('s')]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [Alias('a')]
        $Arguments = $null,

        [switch]
        $Scoped,

        [switch]
        $Return,

        [switch]
        $Splat,

        [switch]
        $NoNewClosure
    )

    if ($PodeContext.Server.IsServerless) {
        $NoNewClosure = $true
    }

    if (!$NoNewClosure) {
        $ScriptBlock = ($ScriptBlock).GetNewClosure()
    }

    if ($Scoped) {
        if ($Splat) {
            $result = (& $ScriptBlock @Arguments)
        }
        else {
            $result = (& $ScriptBlock $Arguments)
        }
    }
    else {
        if ($Splat) {
            $result = (. $ScriptBlock @Arguments)
        }
        else {
            $result = (. $ScriptBlock $Arguments)
        }
    }

    if ($Return) {
        return $result
    }
}

function Test-Empty
{
    param (
        [Parameter()]
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    switch ($Value) {
        { $_ -is 'string' } {
            return [string]::IsNullOrWhiteSpace($Value)
        }

        { $_ -is 'array' } {
            return ($Value.Length -eq 0)
        }

        { $_ -is 'hashtable' } {
            return ($Value.Count -eq 0)
        }

        { $_ -is 'scriptblock' } {
            return ($null -eq $Value -or [string]::IsNullOrWhiteSpace($Value.ToString()))
        }

        { $_ -is 'valuetype' } {
            return $false
        }
    }

    return ([string]::IsNullOrWhiteSpace($Value) -or ((Get-PodeCount $Value) -eq 0))
}

function Test-IsPSCore
{
    return (Get-PodePSVersionTable).PSEdition -ieq 'core'
}

function Test-IsUnix
{
    return (Get-PodePSVersionTable).Platform -ieq 'unix'
}

function Test-IsWindows
{
    $v = Get-PodePSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}