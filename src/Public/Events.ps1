<#
.SYNOPSIS
Registers a script to be run when a certain server event occurs within Pode

.DESCRIPTION
Registers a script to be run when a certain server event occurs within Pode, such as Start, Terminate, and Restart.

.PARAMETER Type
The Type of event to be registered.

.PARAMETER Name
A unique Name for the registered event.

.PARAMETER ScriptBlock
A ScriptBlock to invoke when the event is triggered.

.PARAMETER ArgumentList
An array of arguments to supply to the ScriptBlock.

.EXAMPLE
Register-PodeEvent -Type Start -Name 'Event1' -ScriptBlock { }
#>
function Register-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # error if already registered
    if (Test-PodeEvent -Type $Type -Name $Name) {
        # "$($Type) event already registered: $($Name)"
        throw ($PodeLocale.eventAlreadyRegisteredExceptionMessage -f $Type, $Name)
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add event
    $PodeContext.Server.Events[$Type.ToString()][$Name] = @{
        Name           = $Name
        Type           = $Type.ToString()
        ScriptBlock    = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = $ArgumentList
    }
}

<#
.SYNOPSIS
Unregister an event that has been registered with the specified Name.

.DESCRIPTION
Unregister an event that has been registered with the specified Name.

.PARAMETER Type
The Type of the event to unregister.

.PARAMETER Name
The Name of the event to unregister.

.EXAMPLE
Unregister-PodeEvent -Type Start -Name 'Event1'
#>
function Unregister-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # error if not registered
    if (!(Test-PodeEvent -Type $Type -Name $Name)) {
        # "No $($Type) event registered: $($Name)"
        throw ($PodeLocale.noEventRegisteredExceptionMessage -f $Type, $Name)
    }

    # remove event
    $null = $PodeContext.Server.Events[$Type.ToString()].Remove($Name)
}

<#
.SYNOPSIS
Tests if an event type has been registered.

.DESCRIPTION
Tests if an event type has been registered, and optionally with a specified Name.

.PARAMETER Type
One or more event Types to test. If multiple are supplied, will return true if any are found.

.PARAMETER Name
An optional list of event Names to test.

.EXAMPLE
Test-PodeEvent -Type Start

.EXAMPLE
Test-PodeEvent -Type Start -Name 'Event1'

.EXAMPLE
Test-PodeEvent -Type Start, Stop

.EXAMPLE
Test-PodeEvent -Type Start, Stop -Name 'Event1', 'Event2'
#>
function Test-PodeEvent {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType[]]
        $Type,

        [Parameter()]
        [string[]]
        $Name
    )

    $evts = Get-PodeEvent -Type $Type -Name $Name
    return (($null -ne $evts) -and ($evts.Count -gt 0))
}

<#
.SYNOPSIS
Retrieves one or more events of a specified Type.

.DESCRIPTION
Retrieves one or more events of a specified Type, and optionally by Name.

.PARAMETER Type
One of more event Types to retrieve.

.PARAMETER Name
AN optional list of event Names to retrieve.

.EXAMPLE
Get-PodeEvent -Type Start -Name 'Event1'

.EXAMPLE
Get-PodeEvent -Type Start, Stop

.EXAMPLE
Get-PodeEvent -Type Start, Stop -Name 'Event1', 'Event2'
#>
function Get-PodeEvent {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Pode.PodeServerEventType[]]
        $Type,

        [Parameter()]
        [string[]]
        $Name
    )

    if ($null -eq $PodeContext.Server.Events) {
        return $null
    }

    # get events by type
    $evts = @(foreach ($t in $Type) {
            $PodeContext.Server.Events[$t.ToString()].Values
        })

    # filter by names if specified
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $evts = @(foreach ($e in $evts) {
                if ($Name -icontains $e.Name) {
                    $e
                }
            })
    }

    # return events
    return $evts
}

<#
.SYNOPSIS
Clears an event of all registered scripts.

.DESCRIPTION
Clears an event of all registered scripts.

.PARAMETER Type
The Type of event to clear.

.EXAMPLE
Clear-PodeEvent -Type Start
#>
function Clear-PodeEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerEventType]
        $Type
    )

    $null = $PodeContext.Server.Events[$Type.ToString()].Clear()
}

<#
.SYNOPSIS
Automatically loads event ps1 files

.DESCRIPTION
Automatically loads event ps1 files from either a /events folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeEvents

.EXAMPLE
Use-PodeEvents -Path './my-events'
#>
function Use-PodeEvents {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'events'
}