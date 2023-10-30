<#
.SYNOPSIS
Adds a new Task.

.DESCRIPTION
Adds a new Task, which can be asynchronously or synchronously invoked.

.PARAMETER Name
The Name of the Task.

.PARAMETER ScriptBlock
The script for the Task.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the Task's logic.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the Task's ScriptBlock.

.EXAMPLE
Add-PodeTask -Name 'Example1' -ScriptBlock { Invoke-SomeLogic }

.EXAMPLE
Add-PodeTask -Name 'Example1' -ScriptBlock { return Get-SomeObject }
#>
function Add-PodeTask {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
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

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # add the task
    $PodeContext.Tasks.Enabled = $true
    $PodeContext.Tasks.Items[$Name] = @{
        Name           = $Name
        Script         = $ScriptBlock
        UsingVariables = $usingVars
        Arguments      = (Protect-PodeValue -Value $ArgumentList -Default @{})
    }
}

<#
.SYNOPSIS
Set the maximum number of concurrent Tasks.

.DESCRIPTION
Set the maximum number of concurrent Tasks.

.PARAMETER Maximum
The Maximum number of Tasks to run.

.EXAMPLE
Set-PodeTaskConcurrency -Maximum 10
#>
function Set-PodeTaskConcurrency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
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

<#
.SYNOPSIS
Invoke a Task.

.DESCRIPTION
Invoke a Task either asynchronously or synchronously, with support for returning values.

.PARAMETER Name
The Name of the Task.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the Task's ScriptBlock.

.PARAMETER Timeout
A Timeout, in seconds, to abort running the task. (Default: -1 [never timeout])

.PARAMETER Wait
If supplied, Pode will wait until the Task has finished executing, and then return any values.

.EXAMPLE
Invoke-PodeTask -Name 'Example1' -Wait -Timeout 5

.EXAMPLE
$task = Invoke-PodeTask -Name 'Example1'

.EXAMPLE
Invoke-PodeTask -Name 'Example1' | Wait-PodeTask -Timeout 3
#>
function Invoke-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
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
        return (Wait-PodeTask -Task $task -Timeout $Timeout)
    }

    # return task
    return $task
}

<#
.SYNOPSIS
Removes a specific Task.

.DESCRIPTION
Removes a specific Task.

.PARAMETER Name
The Name of Task to be removed.

.EXAMPLE
Remove-PodeTask -Name 'Example1'
#>
function Remove-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name
    )

    $null = $PodeContext.Tasks.Items.Remove($Name)
}

<#
.SYNOPSIS
Removes all Tasks.

.DESCRIPTION
Removes all Tasks.

.EXAMPLE
Clear-PodeTasks
#>
function Clear-PodeTasks {
    [CmdletBinding()]
    param()

    $PodeContext.Tasks.Items.Clear()
}

<#
.SYNOPSIS
Edits an existing Task.

.DESCRIPTION
Edits an existing Task's properties, such as scriptblock.

.PARAMETER Name
The Name of the Task.

.PARAMETER ScriptBlock
The new ScriptBlock for the Task.

.PARAMETER ArgumentList
Any new Arguments for the Task.

.EXAMPLE
Edit-PodeTask -Name 'Example1' -ScriptBlock { Invoke-SomeNewLogic }
#>
function Edit-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )

    # ensure the task exists
    if (!$PodeContext.Tasks.Items.ContainsKey($Name)) {
        throw "Task '$($Name)' does not exist"
    }

    $_task = $PodeContext.Tasks.Items[$Name]

    # edit scriptblock if supplied
    if (!(Test-PodeIsEmpty $ScriptBlock)) {
        $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState
        $_task.Script = $ScriptBlock
        $_task.UsingVariables = $usingVars
    }

    # edit arguments if supplied
    if (!(Test-PodeIsEmpty $ArgumentList)) {
        $_task.Arguments = $ArgumentList
    }
}

<#
.SYNOPSIS
Returns any defined Tasks.

.DESCRIPTION
Returns any defined Tasks, with support for filtering.

.PARAMETER Name
Any Task Names to filter the Tasks.

.EXAMPLE
Get-PodeTask

.EXAMPLE
Get-PodeTask -Name Example1, Example2
#>
function Get-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    $tasks = $PodeContext.Tasks.Items.Values

    # further filter by task names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $tasks = @(foreach ($_name in $Name) {
                foreach ($task in $tasks) {
                    if ($task.Name -ine $_name) {
                        continue
                    }

                    $task
                }
            })
    }

    # return
    return $tasks
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
function Use-PodeTasks {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'tasks'
}

<#
.SYNOPSIS
Close and dispose of a Task.

.DESCRIPTION
Close and dispose of a Task, even if still running.

.PARAMETER Task
The Task to be closed.

.EXAMPLE
Invoke-PodeTask -Name 'Example1' | Close-PodeTask
#>
function Close-PodeTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Task
    )

    Close-PodeTaskInternal -Result $Task
}

<#
.SYNOPSIS
Test if a running Task has completed.

.DESCRIPTION
Test if a running Task has completed.

.PARAMETER Task
The Task to be check.

.EXAMPLE
Invoke-PodeTask -Name 'Example1' | Test-PodeTaskCompleted
#>
function Test-PodeTaskCompleted {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Task
    )

    return [bool]$Task.Runspace.Handler.IsCompleted
}

<#
.SYNOPSIS
Waits for a task to finish, and returns a result if there is one.

.DESCRIPTION
Waits for a task to finish, and returns a result if there is one.

.PARAMETER Task
The task to wait on.

.PARAMETER Timeout
An optional Timeout in milliseconds.

.EXAMPLE
$context = Wait-PodeTask -Task $listener.GetContextAsync()

.EXAMPLE
$result = Invoke-PodeTask -Name 'Example1' | Wait-PodeTask
#>
function Wait-PodeTask {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Task,

        [Parameter()]
        [int]
        $Timeout = -1
    )

    if ($Task -is [System.Threading.Tasks.Task]) {
        return (Wait-PodeNetTaskInternal -Task $Task -Timeout $Timeout)
    }

    if ($Task -is [hashtable]) {
        return (Wait-PodeTaskInternal -Task $Task -Timeout $Timeout)
    }

    throw 'Task type is invalid, expected either [System.Threading.Tasks.Task] or [hashtable]'
}