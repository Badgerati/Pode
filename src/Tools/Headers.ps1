function Header
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('Add', 'Exists', 'Get', 'Set')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('v')]
        [string]
        $Value
    )

    # run logic for the action
    switch ($Action.ToLowerInvariant())
    {
        # set a headers against the response (overwriting all with same name)
        'set' {
            return (Set-PodeHeader -Name $Name -Value $Value)
        }

        # appends a header against the response
        'add' {
            return (Add-PodeHeader -Name $Name -Value $Value)
        }

        # get a header from the request
        'get' {
            return (Get-PodeHeader -Name $Name)
        }

        # checks whether a given header exists on the request
        'exists' {
            return (Test-PodeHeaderExists -Name $Name)
        }
    }
}

function Test-PodeHeaderExists
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $header = (Get-PodeHeader -Name $Name)
    return (![string]::IsNullOrWhiteSpace($header))
}

function Get-PodeHeader
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    # get the header from the request
    if ($PodeContext.Server.IsServerless) {
        $header = $WebEvent.Request.Headers.$Name
    }
    else {
        $header = $WebEvent.Request.Headers[$Name]
    }

    return $header
}

function Set-PodeHeader
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Value
    )

    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    else {
        $WebEvent.Response.AddHeader($Name, $Value) | Out-Null
    }
}

function Set-PodeServerHeader
{
    param (
        [Parameter()]
        [string]
        $Type
    )

    Set-PodeHeader -Name 'Server' -Value "Pode - $($Type)"
}

function Add-PodeHeader
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Value
    )

    if ($PodeContext.Server.IsServerless) {
        $WebEvent.Response.Headers[$Name] = $Value
    }
    else {
        $WebEvent.Response.AppendHeader($Name, $Value) | Out-Null
    }
}