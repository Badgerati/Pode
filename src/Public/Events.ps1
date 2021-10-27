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
function Register-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser', 'Crash', 'Stop')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [object[]]
        $ArgumentList
    )

    # error if already registered
    if (Test-PodeEvent -Type $Type -Name $Name) {
        throw "$($Type) event already registered: $($Name)"
    }

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # check for state/session vars
    $ScriptBlock = Invoke-PodeStateScriptConversion -ScriptBlock $ScriptBlock
    $ScriptBlock = Invoke-PodeSessionScriptConversion -ScriptBlock $ScriptBlock

    # add event
    $PodeContext.Server.Events[$Type][$Name] = @{
        Name = $Name
        ScriptBlock = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = $ArgumentList
    }
}

<#
.SYNOPSIS
Unregisters an event that has been registered with the specified Name.

.DESCRIPTION
Unregisters an event that has been registered with the specified Name.

.PARAMETER Type
The Type of the event to unregister.

.PARAMETER Name
The Name of the event to unregister.

.EXAMPLE
Unregister-PodeEvent -Type Start -Name 'Event1'
#>
function Unregister-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser', 'Crash', 'Stop')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    # error if not registered
    if (!(Test-PodeEvent -Type $Type -Name $Name)) {
        throw "No $($Type) event registered: $($Name)"
    }

    # remove event
    $null = $PodeContext.Server.Events[$Type].Remove($Name)
}

<#
.SYNOPSIS
Tests if an event has been registered with the specified Name.

.DESCRIPTION
Tests if an event has been registered with the specified Name.

.PARAMETER Type
The Type of the event to test.

.PARAMETER Name
The Name of the event to test.

.EXAMPLE
Test-PodeEvent -Type Start -Name 'Event1'
#>
function Test-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser', 'Crash', 'Stop')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Events[$Type].Contains($Name)
}

<#
.SYNOPSIS
Retrieves an event.

.DESCRIPTION
Retrieves an event.

.PARAMETER Type
The Type of event to retrieve.

.PARAMETER Name
The Name of the event to retrieve.

.EXAMPLE
Get-PodeEvent -Type Start -Name 'Event1'
#>
function Get-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser', 'Crash', 'Stop')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Events[$Type][$Name]
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
function Clear-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser', 'Crash', 'Stop')]
        [string]
        $Type
    )

    $null = $PodeContext.Server.Events[$Type].Clear()
}