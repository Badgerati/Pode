function Add-PodeFlashMessage
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Key,

        [Parameter()]
        [string]
        $Message
    )

    # append the message against the key
    if ($null -eq $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash = @{}
    }

    if ($null -eq $WebEvent.Session.Data.Flash[$Key]) {
        $WebEvent.Session.Data.Flash[$Key] = @($Message)
    }
    else {
        $WebEvent.Session.Data.Flash[$Key] += @($Message)
    }
}

function Get-PodeFlashMessage
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Key
    )

    # retrieve messages from session, then delete it
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return @()
    }

    $v = @($WebEvent.Session.Data.Flash[$Key])
    $WebEvent.Session.Data.Flash.Remove($Key)

    if (Test-Empty $v) {
        return @()
    }

    return @($v)
}

function Get-PodeFlashMessageKeys
{
    # return list of all current keys
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return @()
    }

    return @($WebEvent.Session.Data.Flash.Keys)
}

function Clear-PodeFlashMessages
{
    # clear all keys
    if ($null -ne $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash = @{}
    }
}

function Remove-PodeFlashMessage
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Key
    )

    # remove key from flash messages
    if ($null -ne $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash.Remove($Key)
    }
}