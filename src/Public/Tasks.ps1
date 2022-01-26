function Add-PodeTask
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]
        $FilePath,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )
    # ensure the task doesn't already exist
    if ($PodeContext.Tasks.Items.ContainsKey($Name)) {
        throw "[Task] $($Name): Task already defined"
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check if the scriptblock has any using vars
    $ScriptBlock, $usingVars = Invoke-PodeUsingScriptConversion -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # check for state/session vars
    $ScriptBlock = Invoke-PodeStateScriptConversion -ScriptBlock $ScriptBlock
    $ScriptBlock = Invoke-PodeSessionScriptConversion -ScriptBlock $ScriptBlock

    # add the task
    $PodeContext.Tasks.Enabled = $true
    $PodeContext.Tasks.Items[$Name] = @{
        Name = $Name
        Count = 0
        Script = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = (Protect-PodeValue -Value $ArgumentList -Default @{})
    }
}

function Set-PodeTaskConcurrency
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]
        $Maximum
    )

    # error if <=0
    if ($Maximum -le 0) {
        throw "Maximum concurrent tasks must be >=1 but got: $($Maximum)"
    }

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.Tasks) {
        $_min = $PodeContext.RunspacePools.Tasks.Pool.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        throw "Maximum concurrent tasks cannot be less than the minimum of $($_min) but got: $($Maximum)"
    }

    # set the max tasks
    $PodeContext.Threads.Tasks = $Maximum
    if ($null -ne $PodeContext.RunspacePools.Tasks) {
        $PodeContext.RunspacePools.Tasks.Pool.SetMaxRunspaces($Maximum)
    }
}

function Invoke-PodeTask
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null,

        [Parameter()]
        [int]
        $Timeout = -1,

        [switch]
        $Wait
    )

    # ensure the task exists
    if (!$PodeContext.Tasks.Items.ContainsKey($Name)) {
        throw "Task '$($Name)' does not exist"
    }

    # run task logic
    $task = Invoke-PodeInternalTask -Task $PodeContext.Tasks.Items[$Name] -ArgumentList $ArgumentList -Timeout $Timeout

    # wait, and return result?
    if ($Wait) {
        $null = $task.Runspace.Handler.AsyncWaitHandle.WaitOne($Timeout) # multiple timeout by 1000 (if > 0)
        $result = $task.Result.ReadAll()
        Close-PodeTask -Task $task
        return $result
    }

    # return task
    return $task
}

function Test-PodeTaskCompleted
{
    #TODO: return if a task is completed
}

function Remove-PodeTask
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]
        $Name
    )

    $null = $PodeContext.Tasks.Items.Remove($Name)

    #TODO: find task results for task and remove?
}

<#
.SYNOPSIS
Removes all Tasks.

.DESCRIPTION
Removes all Tasks.

.EXAMPLE
Clear-PodeTasks
#>
function Clear-PodeTasks
{
    [CmdletBinding()]
    param()

    $PodeContext.Tasks.Items.Clear()
    $PodeContext.Tasks.Results.Clear() #TODO: and close/dispose!!
}

function Edit-PodeTask
{
    #TODO:
}

function Get-PodeTask
{
    #TODO:
}

<#
.SYNOPSIS
Automatically loads task ps1 files

.DESCRIPTION
Automatically loads task ps1 files from either a /tasks folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeTasks

.EXAMPLE
Use-PodeTasks -Path './my-tasks'
#>
function Use-PodeTasks
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'tasks'
}

function Close-PodeTask
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Task
    )

    Close-PodeTaskInternal -Result $Task
}