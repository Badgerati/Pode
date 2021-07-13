function Register-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser')]
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

    # add event
    $PodeContext.Server.Events[$Type][$Name] = @{
        Name = $Name
        ScriptBlock = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = $ArgumentList
    }
}

function Unregister-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser')]
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
    $PodeContext.Server.Events[$Type].Remove($Name) | Out-Null
}

function Test-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Events[$Type].Contains($Name)
}

function Get-PodeEvent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser')]
        [string]
        $Type,

        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return $PodeContext.Server.Events[$Type][$Name]
}

function Clear-PodeEvents
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('Start', 'Terminate', 'Restart', 'Browser')]
        [string]
        $Type
    )

    $PodeContext.Server.Events[$Type].Clear() | Out-Null
}