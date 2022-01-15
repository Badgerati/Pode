function Set-PodeSecurity
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Simple', 'Strict')]
        [string]
        $Type
    )

    #TODO:
    switch ($Type.ToLowerInvariant()) {
        'simple' {
            Set-PodeSecurityFrameOptions -Access SameOrigin
        }

        'strict' {
            Set-PodeSecurityFrameOptions -Access Deny
        }
    }
}

function Remove-PodeSecurity
{
    [CmdletBinding()]
    param()

    $PodeContext.Server.Security.Headers.Clear()
}

function Add-PodeSecurityHeader
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [string]
        $Value
    )

    $PodeContext.Server.Security.Headers[$Name] = $Value
}

function Remove-PodeSecurityHeader
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $PodeContext.Server.Security.Headers.Remove($Name)
}

function Set-PodeSecurityFrameOptions
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('None', 'Deny', 'SameOrigin', 'AllowFrom')]
        [string]
        $Access,

        [Parameter()]
        [string]
        $Url
    )

    # set value
    $value = $Access.ToUpperInvariant()

    # check allow from and url
    if ($value -ieq 'AllowFrom') {
        if ([string]::IsNullOrWhiteSpace($Url)) {
            throw "A URL is required when setting X-Frame-Options to ALLOW-FROM"
        }

        $value += " $($Url)"
    }

    Add-PodeSecurityHeader -Name 'X-Frame-Options' -Value $value
}

function Remove-PodeSecurityFrameOptions
{
    [CmdletBinding()]
    param()

    Remove-PodeSecurityHeader -Name 'X-Frame-Options'
}