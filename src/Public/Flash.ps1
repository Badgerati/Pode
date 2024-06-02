<#
.SYNOPSIS
Appends a message to the current flash messages stored in the session.

.DESCRIPTION
Appends a message to the current flash messages stored in the session for the supplied name.
The messages per name are stored as an array.

.PARAMETER Name
The name of the flash message to be appended.

.PARAMETER Message
The message to append.

.EXAMPLE
Add-PodeFlashMessage -Name 'error' -Message 'There was an error'
#>
function Add-PodeFlashMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string]
        $Message
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        throw 'Sessions are required to use Flash messages'
    }

    # append the message against the key
    if ($null -eq $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash = @{}
    }

    if ($null -eq $WebEvent.Session.Data.Flash[$Name]) {
        $WebEvent.Session.Data.Flash[$Name] = @($Message)
    }
    else {
        $WebEvent.Session.Data.Flash[$Name] += @($Message)
    }
}

<#
.SYNOPSIS
Clears all flash messages.

.DESCRIPTION
Clears all of the flash messages currently stored in the session.

.EXAMPLE
Clear-PodeFlashMessages
#>
function Clear-PodeFlashMessages {
    [CmdletBinding()]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        throw 'Sessions are required to use Flash messages'
    }

    # clear all keys
    if ($null -ne $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash = @{}
    }
}

<#
.SYNOPSIS
Returns all flash messages stored against a name, and the clears the messages.

.DESCRIPTION
Returns all of the flash messages, as an array, currently stored for the name within the session.
Once retrieved, the messages are removed from storage.

.PARAMETER Name
The name of the flash messages to return.

.EXAMPLE
Get-PodeFlashMessage -Name 'error'
#>
function Get-PodeFlashMessage {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        throw 'Sessions are required to use Flash messages'
    }

    # retrieve messages from session, then delete it
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return @()
    }

    $v = @($WebEvent.Session.Data.Flash[$Name])
    $WebEvent.Session.Data.Flash.Remove($Name)

    if (Test-PodeIsEmpty $v) {
        return @()
    }

    return @($v)
}

<#
.SYNOPSIS
Returns all of the names for each of the messages currently being stored.

.DESCRIPTION
Returns all of the names for each of the messages currently being stored. This does not clear the messages.

.EXAMPLE
Get-PodeFlashMessageNames
#>
function Get-PodeFlashMessageNames {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param()

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        throw 'Sessions are required to use Flash messages'
    }

    # return list of all current keys
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return @()
    }

    return @($WebEvent.Session.Data.Flash.Keys)
}

<#
.SYNOPSIS
Removes flash messages for the supplied name currently being stored.

.DESCRIPTION
Removes flash messages for the supplied name currently being stored.

.PARAMETER Name
The name of the flash messages to remove.

.EXAMPLE
Remove-PodeFlashMessage -Name 'error'
#>
function Remove-PodeFlashMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        throw 'Sessions are required to use Flash messages'
    }

    # remove key from flash messages
    if ($null -ne $WebEvent.Session.Data.Flash) {
        $WebEvent.Session.Data.Flash.Remove($Name)
    }
}

<#
.SYNOPSIS
Tests if there are any flash messages currently being stored for a supplied name.

.DESCRIPTION
Tests if there are any flash messages currently being stored for a supplied name.

.PARAMETER Name
The name of the flash message to check.

.EXAMPLE
Test-PodeFlashMessage -Name 'error'
#>
function Test-PodeFlashMessage {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # if sessions haven't been setup, error
    if (!(Test-PodeSessionsEnabled)) {
        throw 'Sessions are required to use Flash messages'
    }

    # return if a key exists as a flash message
    if ($null -eq $WebEvent.Session.Data.Flash) {
        return $false
    }

    return $WebEvent.Session.Data.Flash.ContainsKey($Name)
}