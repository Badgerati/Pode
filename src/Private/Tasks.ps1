function Test-PodeTasksExist {
    return (($null -ne $PodeContext.Tasks) -and (($PodeContext.Tasks.Enabled) -or ($PodeContext.Tasks.Items.Count -gt 0)))
}

function Start-PodeTaskHousekeeper {
    if (!(Test-PodeTasksExist)) {
        return
    }

    Add-PodeTimer -Name '__pode_task_housekeeper__' -Interval $PodeContext.Tasks.HouseKeeping.TimerInterval -ScriptBlock {
        try {
            # return if no task processes
            if ($PodeContext.Tasks.Processes.Count -eq 0) {
                return
            }

            # get the current time
            $now = [datetime]::UtcNow

            # loop through each process
            foreach ($key in $PodeContext.Tasks.Processes.Keys.Clone()) {
                try {
                    # get the process and the task
                    $process = $PodeContext.Tasks.Processes[$key]
                    $task = $PodeContext.Tasks.Items[$process.Task]

                    # if completed, and no completed time set, then set one and continue
                    if ($process.Runspace.Handler.IsCompleted -and ($null -eq $process.CompletedTime)) {
                        $process.CompletedTime = $now
                        $process.State = 'Completed'
                        continue
                    }

                    # if the process is completed, then close and remove
                    if (($process.State -ieq 'Completed') -and ($process.CompletedTime.AddMinutes(1) -lt $now)) {
                        Close-PodeTaskInternal -Process $process
                        continue
                    }

                    # has the process failed?
                    if ($process.State -ieq 'Failed') {
                        # if we have hit the max retries, then close and remove
                        if ($process.Retry.Count -ge $task.Retry.Max) {
                            Close-PodeTaskInternal -Process $process
                            continue
                        }

                        # if we aren't auto-retrying, then continue
                        if (!$task.Retry.AutoRetry) {
                            continue
                        }

                        # if the retry delay hasn't passed, then continue
                        if (($null -eq $process.Retry.From) -or ($process.Retry.From -gt $now)) {
                            continue
                        }

                        # restart the process
                        Restart-PodeTaskInternal -ProcessId $process.ID
                        continue
                    }

                    # if the process is running, and the expire time has passed, then close and remove
                    if ($process.ExpireTime -lt $now) {
                        Close-PodeTaskInternal -Process $process
                        continue
                    }
                }
                catch {
                    $_ | Write-PodeErrorLog
                }
            }

            $process = $null
        }
        catch {
            $_ | Write-PodeErrorLog
        }
    }
}

function Close-PodeTaskInternal {
    param(
        [Parameter()]
        [hashtable]
        $Process,

        [switch]
        $Keep
    )

    # return if no process
    if ($null -eq $Process) {
        return
    }

    # close the runspace
    Close-PodeDisposable -Disposable $Process.Runspace.Pipeline
    Close-PodeDisposable -Disposable $Process.Result

    # remove the process
    if (!$Keep) {
        $null = $PodeContext.Tasks.Processes.Remove($Process.ID)
    }
}

function Invoke-PodeTaskInternal {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Task,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null,

        [Parameter()]
        [int]
        $Timeout = -1,

        [Parameter()]
        [ValidateSet('Default', 'Create', 'Start')]
        [string]
        $TimeoutFrom = 'Default'
    )

    try {
        # generate processId for task
        $processId = New-PodeGuid

        # setup event param
        $parameters = @{
            ProcessId    = $processId
            ArgumentList = $ArgumentList
        }

        # what's the timeout values to use?
        if ($TimeoutFrom -eq 'Default') {
            $TimeoutFrom = $Task.Timeout.From
        }

        if ($Timeout -eq -1) {
            $Timeout = $Task.Timeout.Value
        }

        # what is the expire time if using "create" timeout?
        $expireTime = [datetime]::MaxValue
        $createTime = [datetime]::UtcNow

        if (($TimeoutFrom -ieq 'Create') -and ($Timeout -ge 0)) {
            $expireTime = $createTime.AddSeconds($Timeout)
        }

        # add task process
        $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $PodeContext.Tasks.Processes[$processId] = @{
            ID            = $processId
            Task          = $Task.Name
            Parameters    = $parameters
            Runspace      = $null
            Result        = $result
            CreateTime    = $createTime
            StartTime     = $null
            CompletedTime = $null
            ExpireTime    = $expireTime
            Exception     = $null
            Timeout       = @{
                Value = $Timeout
                From  = $TimeoutFrom
            }
            Retry         = @{
                Count = 0
                From  = $null
            }
            State         = 'Pending'
        }

        # start the task runspace
        $scriptblock = Get-PodeTaskScriptBlock
        $runspace = Add-PodeRunspace -Type Tasks -Name $Task.Name -ScriptBlock $scriptblock -Parameters $parameters -OutputStream $result -PassThru

        # add runspace to process
        $PodeContext.Tasks.Processes[$processId].Runspace = $runspace

        # return the task process
        return $PodeContext.Tasks.Processes[$processId]
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}

function Restart-PodeTaskInternal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ProcessId
    )

    try {
        # get the process, and return if not found or not failed
        $process = $PodeContext.Tasks.Processes[$ProcessId]
        if (($null -eq $process) -or ($process.State -ine 'Failed')) {
            return
        }

        # get the task
        $task = $PodeContext.Tasks.Items[$process.Task]

        # dispose of the old runspace
        Close-PodeTaskInternal -Process $process -Keep

        # return if we have hit the max retries
        if ($process.Retry.Count -ge $task.Retry.Max) {
            return
        }

        # what is the expire time if using "create" timeout?
        $expireTime = [datetime]::MaxValue
        $createTime = [datetime]::UtcNow

        if (($process.Timeout.From -ieq 'Create') -and ($process.Timeout.Value -ge 0)) {
            $expireTime = $createTime.AddSeconds($process.Timeout.Value)
        }

        $process.CreateTime = $createTime
        $process.ExpireTime = $expireTime
        $process.StartTime = $null
        $process.CompletedTime = $null

        # reset the process result
        $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $process.Result = $result

        # reset the process state
        $process.State = 'Pending'
        $process.Exception = $null
        $process.Retry.Count++
        $process.Retry.From = $null

        # start the task runspace
        $scriptblock = Get-PodeTaskScriptBlock
        $runspace = Add-PodeRunspace -Type Tasks -Name $process.Task -ScriptBlock $scriptblock -Parameters $process.Parameters -OutputStream $result -PassThru

        # add runspace to process
        $process.Runspace = $runspace

        # return the task process
        return $process
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}

function Get-PodeTaskScriptBlock {
    return {
        param($ProcessId, $ArgumentList)

        try {
            $process = $PodeContext.Tasks.Processes[$ProcessId]
            if ($null -eq $process) {
                # Task process does not exist: $ProcessId
                throw ($PodeLocale.taskProcessDoesNotExistExceptionMessage -f $ProcessId)
            }

            # set the start time and state
            $process.StartTime = [datetime]::UtcNow
            $process.State = 'Running'

            # set the expire time of timeout based on "start" time
            if (($process.Timeout.From -ieq 'Start') -and ($process.Timeout.Value -ge 0)) {
                $process.ExpireTime = $process.StartTime.AddSeconds($process.Timeout.Value)
            }

            # get the task, error if not found
            $task = $PodeContext.Tasks.Items[$process.Task]
            if ($null -eq $task) {
                # Task does not exist
                throw ($PodeLocale.taskDoesNotExistExceptionMessage -f $process.Task)
            }

            # build the script arguments
            $TaskEvent = @{
                Lockable  = $PodeContext.Threading.Lockables.Global
                Sender    = $task
                Timestamp = [DateTime]::UtcNow
                Count     = $process.Retry.Count
                Metadata  = @{}
            }

            $_args = @{ Event = $TaskEvent }

            if ($null -ne $task.Arguments) {
                foreach ($key in $task.Arguments.Keys) {
                    $_args[$key] = $task.Arguments[$key]
                }
            }

            if ($null -ne $ArgumentList) {
                foreach ($key in $ArgumentList.Keys) {
                    $_args[$key] = $ArgumentList[$key]
                }
            }

            # add any using variables
            if ($null -ne $task.UsingVariables) {
                foreach ($usingVar in $task.UsingVariables) {
                    $_args[$usingVar.NewName] = $usingVar.Value
                }
            }

            # invoke the script from the task
            Invoke-PodeScriptBlock -ScriptBlock $task.Script -Arguments $_args -Scoped -Splat -Return

            # set the state to completed
            $process.State = 'Completed'
        }
        catch {
            # update the state
            if ($null -ne $process) {
                $process.State = 'Failed'
                $process.ExpireTime = $null
                $process.Retry.From = [datetime]::UtcNow.AddMinutes($task.Retry.Delay)
                $process.Exception = $_
            }

            # log the error
            $_ | Write-PodeErrorLog
        }
        finally {
            $process.CompletedTime = [datetime]::UtcNow
            Reset-PodeRunspaceName
            Invoke-PodeGC
        }
    }
}

function Wait-PodeTaskNetInternal {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Threading.Tasks.Task]
        $Task,

        [Parameter()]
        [int]
        $Timeout = -1
    )

    # do we need a timeout?
    $timeoutTask = $null
    if ($Timeout -gt 0) {
        $timeoutTask = [System.Threading.Tasks.Task]::Delay($Timeout)
    }

    # set the check task
    if ($null -eq $timeoutTask) {
        $checkTask = $Task
    }
    else {
        $checkTask = [System.Threading.Tasks.Task]::WhenAny($Task, $timeoutTask)
    }

    # is there a cancel token to supply?
    if (($null -eq $PodeContext) -or ($null -eq $PodeContext.Tokens.Cancellation.Token)) {
        $checkTask.Wait()
    }
    else {
        $checkTask.Wait($PodeContext.Tokens.Cancellation.Token)
    }

    # if the main task isn't complete, it timed out
    if (($null -ne $timeoutTask) -and (!$Task.IsCompleted)) {
        # "Task has timed out after $($Timeout)ms")
        throw [System.TimeoutException]::new($PodeLocale.taskTimedOutExceptionMessage -f $Timeout)
    }

    # only return a value if the result has one
    if ($null -ne $Task.Result) {
        return $Task.Result
    }
}

function Wait-PodeTaskProcessInternal {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Process,

        [Parameter()]
        [int]
        $Timeout = -1
    )

    # timeout needs to be in milliseconds
    if ($Timeout -gt 0) {
        $Timeout *= 1000
    }

    # wait for the pipeline to finish processing
    $null = $Process.Runspace.Handler.AsyncWaitHandle.WaitOne($Timeout)

    # get the current result
    $result = $Process.Result.ReadAll()

    # close the task
    Close-PodeTask -Process $Process

    # only return a value if the result has one
    if (($null -ne $result) -and ($result.Count -gt 0)) {
        return $result
    }
}