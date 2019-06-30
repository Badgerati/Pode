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