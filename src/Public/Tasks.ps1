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

.PARAMETER Timeout
    A Timeout, in seconds, to abort running the Task process. (Default: -1 [never timeout])

.PARAMETER TimeoutFrom
    Where to start the Timeout from, either 'Create', 'Start'. (Default: 'Create')

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
        $ArgumentList,

        [Parameter()]
        [int]
        $Timeout = -1,

        [Parameter()]
        [ValidateSet('Create', 'Start')]
        [string]
        $TimeoutFrom = 'Create'
    )
    # ensure the task doesn't already exist
    if ($PodeContext.Tasks.Items.ContainsKey($Name)) {
        # [Task] Task already defined
        throw ($PodeLocale.taskAlreadyDefinedExceptionMessage -f $Name)
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
        Timeout        = @{
            Value = $Timeout
            From  = $TimeoutFrom
        }
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
        # Maximum concurrent tasks must be >=1 but got
        throw ($PodeLocale.maximumConcurrentTasksInvalidExceptionMessage -f $Maximum)

    }

    # ensure max > min
    $_min = 1
    if ($null -ne $PodeContext.RunspacePools.Tasks) {
        $_min = $PodeContext.RunspacePools.Tasks.Pool.GetMinRunspaces()
    }

    if ($_min -gt $Maximum) {
        # Maximum concurrent tasks cannot be less than the minimum of $_min but got $Maximum
        throw ($PodeLocale.maximumConcurrentTasksLessThanMinimumExceptionMessage -f $_min, $Maximum)
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
The function returns the Task process onbject which was triggered.

.PARAMETER Name
The Name of the Task.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the Task's ScriptBlock.

.PARAMETER Timeout
A Timeout, in seconds, to abort running the Task process. (Default: -1 [never timeout])

.PARAMETER TimeoutFrom
Where to start the Timeout from, either 'Default', 'Create', or 'Start'. (Default: 'Default' - will use the value from Add-PodeTask)

.PARAMETER Wait
If supplied, Pode will wait until the Task process has finished executing, and then return any values.

.OUTPUTS
The triggered Task process.

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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null,

        [Parameter()]
        [int]
        $Timeout = -1,

        [Parameter()]
        [ValidateSet('Default', 'Create', 'Start')]
        [string]
        $TimeoutFrom = 'Default',

        [switch]
        $Wait
    )
    process {
        # ensure the task exists
        if (!$PodeContext.Tasks.Items.ContainsKey($Name)) {
            # Task does not exist
            throw ($PodeLocale.taskDoesNotExistExceptionMessage -f $Name)
        }

        # run task logic
        $task = Invoke-PodeInternalTask -Task $PodeContext.Tasks.Items[$Name] -ArgumentList $ArgumentList -Timeout $Timeout -TimeoutFrom $TimeoutFrom

        # wait, and return result?
        if ($Wait) {
            return (Wait-PodeTask -Task $task -Timeout $Timeout)
        }

        # return task
        return $task
    }
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name
    )
    process {
        $null = $PodeContext.Tasks.Items.Remove($Name)
    }
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]
        $Name,

        [Parameter()]
        [scriptblock]
        $ScriptBlock,

        [Parameter()]
        [hashtable]
        $ArgumentList
    )
    process {
        # ensure the task exists
        if (!$PodeContext.Tasks.Items.ContainsKey($Name)) {
            # Task does not exist
            throw ($PodeLocale.taskDoesNotExistExceptionMessage -f $Name)
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [hashtable]
        $Task
    )
    process {
        Close-PodeTaskInternal -Process $Task
    }
}

<#
.SYNOPSIS
Test if a running Task process has completed.

.DESCRIPTION
Test if a running Task process has completed.

.PARAMETER Task
The Task process to be check. The process returned by either Invoke-PodeTask or Get-PodeTaskProcess.

.EXAMPLE
Invoke-PodeTask -Name 'Example1' | Test-PodeTaskCompleted
#>
function Test-PodeTaskCompleted {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [hashtable]
        $Task
    )
    process {
        return [bool]$Task.Runspace.Handler.IsCompleted
    }
}

<#
.SYNOPSIS
Waits for a Task process to finish, and returns a result if there is one.

.DESCRIPTION
Waits for a Task process to finish, and returns a result if there is one.

.PARAMETER Task
The Task process to wait on. The process returned by either Invoke-PodeTask or Get-PodeTaskProcess.

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
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        $Task,

        [Parameter()]
        [int]
        $Timeout = -1
    )
    begin {
        $pipelineItemCount = 0
    }

    process {
        $pipelineItemCount++
    }

    end {
        if ($pipelineItemCount -gt 1) {
            throw ($PodeLocale.fnDoesNotAcceptArrayAsPipelineInputExceptionMessage -f $($MyInvocation.MyCommand.Name))
        }
        if ($Task -is [System.Threading.Tasks.Task]) {
            return (Wait-PodeNetTaskInternal -Task $Task -Timeout $Timeout)
        }

        if ($Task -is [hashtable]) {
            return (Wait-PodeTaskInternal -Task $Task -Timeout $Timeout)
        }

        # Task type is invalid, expected either [System.Threading.Tasks.Task] or [hashtable]
        throw ($PodeLocale.invalidTaskTypeExceptionMessage)
    }
}

<#
.SYNOPSIS
Get all Task Processes.

.DESCRIPTION
Get all Task Processes, with support for filtering. These are the processes created when using Invoke-PodeTask.

.PARAMETER Name
An optional Name of the Task to filter by, can be one or more.

.PARAMETER Id
An optional ID of the Task process to filter by, can be one or more.

.PARAMETER State
An optional State of the Task process to filter by, can be one or more.

.EXAMPLE
Get-PodeTaskProcess

.EXAMPLE
Get-PodeTaskProcess -Name 'TaskName'

.EXAMPLE
Get-PodeTaskProcess -Id 'TaskId'

.EXAMPLE
Get-PodeTaskProcess -State 'Running'
#>
function Get-PodeTaskProcess {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name,

        [Parameter()]
        [string[]]
        $Id,

        [Parameter()]
        [ValidateSet('All', 'Pending', 'Running', 'Completed', 'Failed')]
        [string[]]
        $State = 'All'
    )

    $processes = $PodeContext.Tasks.Processes.Values

    # filter processes by name
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $processes = @(foreach ($_name in $Name) {
                foreach ($process in $processes) {
                    if ($process.Task -ine $_name) {
                        continue
                    }

                    $process
                }
            })
    }

    # filter processes by id
    if (($null -ne $Id) -and ($Id.Length -gt 0)) {
        $processes = @(foreach ($_id in $Id) {
                foreach ($process in $processes) {
                    if ($process.ID -ine $_id) {
                        continue
                    }

                    $process
                }
            })
    }

    # filter processes by status
    if ($State -inotcontains 'All') {
        $processes = @(foreach ($process in $processes) {
                if ($State -inotcontains $process.State) {
                    continue
                }

                $process
            })
    }

    # return processes
    return $processes
}