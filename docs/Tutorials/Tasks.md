# Tasks

A Task in Pode is a script that you can later invoke either asynchronously, or synchronously. They can be invoked many times, and they also support returning values from them for later use.

Similar to [Schedules](../Schedules), Tasks also run in their own separate runspaces; meaning you can have long or short running tasks. By default up to a maximum of 2 tasks can run concurrently, but this can be changed by using [`Set-PodeTaskConcurrency`](../../Functions/Tasks/Set-PodeTaskConcurrency). When more tasks are invoked than can be run concurrently, tasks will be added to the task queue and will run once there is available resource in the thread pool.

Behind the scenes there is a a Timer created that will automatically clean-up any completed tasks. Any task that has been completed for 1+ minutes will be disposed of to free up resources - there are functions which will let you clean-up tasks more quickly.

## Create a Task

You can create a new task by using [`Add-PodeTask`](../../Functions/Tasks/Add-PodeTask), this will let you define a name for the task and set the scriptblock:

```powershell
Add-PodeTask -Name 'Example' -ScriptBlock {
    # logic
}
```

A task's scriptblock can also return values, that can be retrieved later on (see [Invoking](#invoking)):

```powershell
Add-PodeTask -Name 'Example' -ScriptBlock {
    # logic
    return $result
}
```

Usually all tasks are created within the main `Start-PodeServer` scope, however it is possible to create adhoc tasks with routes/etc. If you create adhoc tasks in this manner, you might notice that they don't run when invoked; this is because the Runspace that tasks use to run won't have been configured. You can configure by using `-EnablePool` on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer):

```powershell
Start-PodeServer -EnablePool Tasks {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/create-task' -ScriptBlock {
        Add-PodeTask -Name 'example' -ScriptBlock {
            # logic
        }
    }
}
```

### Arguments

You can supply custom arguments to your tasks by using the `-ArgumentList` parameter. Similar to schedules, for tasks the `-ArgumentList` is a hashtable; this is done because parameters to the `-ScriptBlock` are splatted in, and the parameter names are literal.

There is always a parameter added to each task invocation in the `-Event` argument - this contains the `.Lockable` object. You can safely ignore/leave the parameter unbound if you do not need it. Other parameters come from any Key/Values contained with the optional `-ArgumentList`:

```powershell
Add-PodeTask -Name 'Example' -ArgumentList @{ Name = 'Rick'; Environment = 'Multiverse' } -ScriptBlock {
    param($Event, $Name, $Environment)
}
```

Tasks parameters **must** be bound in the param block in order to be used, but the values for the parameters can be set through the `-ArgumentList` hashtable parameter in either the Add-PodeTask definition or when invoking the task. The following snippet would populate the parameters to the task with the same values as the above example but the `-ArgumentList` parameter is populated during invocation. Note that Keys in the `-ArgumentList` hashtable parameter set during invocation override the same Keys set during task creation:

```powershell
Add-PodeTask -Name 'Example' -ScriptBlock {
    param($Event, $Name, $Environment)
}

Add-PodeRoute -Method Get -Path '/invoke-task' -ScriptBlock {
    Invoke-PodeTask -Name 'example' -ArgumentList @{ Name = 'Rick'; Environment = 'Multiverse' }
}
```

!!! important
    In tasks, your scriptblock parameter names must be exact - including case-sensitivity. This is because the arguments are splatted into a runspace. If you pass in an argument called "Names", the param-block must have `$Names` exactly. Furthermore, the event parameter *must* be called `$Event`.

## Invoking

You can invoke a task to run from anywhere, be it a route, schedule, middleware, or another task! To do so you use [`Invoke-PodeTask`](../../Functions/Tasks/Invoke-PodeTask) and this will either return the running task, or the result of running the task if used with `-Wait`.

### Asynchronously

When you use [`Invoke-PodeTask`](../../Functions/Tasks/Invoke-PodeTask) with just the name of the task, this will trigger a task to run asynchronously by default:

```powershell
$task = Invoke-PodeTask -Name 'Example'

# or

Invoke-PodeTask -Name 'Example' | Out-Null
```

The task will continue to run in the background even if, for example, the route you invoked it from as finished processing. Running tasks like this will be automatically cleaned-up once they've finished running for 1+ minutes.

If your task does some work, and then you want to run some extra logic while it runs, and then get some value back (or just wait for it do be done), you can use [`Wait-PodeTask`](../../Functions/Tasks/Wait-PodeTask):

```powershell
Add-PodeTask -Name 'Example' -ScriptBlock {
    # do some work
    return $user
}

Add-PodeRoute -Method Get -Path '/run-task' -ScriptBlock {
    $task = Invoke-PodeTask -Name 'Example'

    # do some other work here, while the task runs

    $user = $task | Wait-PodeTask
    Write-PodeJsonResponse -Value @{ User = $user }
}
```

### Synchronously

To run a task synchronously you use [`Invoke-PodeTask`](../../Functions/Tasks/Invoke-PodeTask) with the `-Wait` switch, and this will: run the task; wait for it to complete; clean-up the task; and then return any result:

```powershell
Add-PodeTask -Name 'Example' -ScriptBlock {
    # do some work
    return $user
}

Add-PodeRoute -Method Get -Path '/run-task' -ScriptBlock {
    $user = Invoke-PodeTask -Name 'Example' -Wait
    Write-PodeJsonResponse -Value @{ User = $user }
}
```

### Timeout

By default all tasks run for as long as they need until completion. You can set a timeout on the task by supplying the `-Timeout` parameter, in seconds, on [`Invoke-PodeTask`](../../Functions/Tasks/Invoke-PodeTask) or [`Wait-PodeTask`](../../Functions/Tasks/Wait-PodeTask). For example, to timeout a task running for longer than 5 seconds:

```powershell
$task = Invoke-PodeTask -Name 'Example' -Timeout 5
$user = $task | Wait-PodeTask -Timeout 5
```

Setting `-Timeout` on [`Invoke-PodeTask`](../../Functions/Tasks/Invoke-PodeTask) when not using `-Wait` will set an expiry time on the task.

### Clean-up

When you use the `-Wait` switch on [`Invoke-PodeEvent`](../../Functions//Invoke-PodeEvent), or if you use [`Wait-PodeEvent`](../../Functions//Wait-PodeEvent), both of these will automatically clean-up the task immediately.

However, if you run a task async without waiting for it to finish, then it will be left running in the background. When this happens, Pode will automatically dispose of completed tasks after 1+ minutes.

You can force a task to be cleaned-up by using [`Close-PodeTask`](../../Functions/Tasks/Close-PodeTask), and this will dispose and remove a running task regardless of completion status:

```powershell
$task = Invoke-PodeTask -Name 'Example'
$task | Close-PodeTask
```

or, to cleverly clean-up early if the task has finished you can use [`Test-PodeTaskCompleted`](../../Functions/Tasks/Test-PodeTaskCompleted):

```powershell
$task = Invoke-PodeTask -Name 'Example'

if (Test-PodeTaskCompleted -Process $task) {
    $task | Close-PodeTask
}
```

### Retrying

By default, when a Task process fails Pode will not retry it, and it will be cleaned-up automatically.

However, there are settings that will allow failed Task processes to be retried. The first thing you'll need to do it set `-MaxRetries` on [`Add-PodeTask`](../../Functions/Tasks/Add-PodeTask) - by default this is 0, which prevents the retrying of failed processes.

You then have two choices, auto- or manual retrying.

#### Automatic

To automatically have Pode retry a failed Task process, simply pass `-AutoRetry` to [`Add-PodeTask`](../../Functions/Tasks/Add-PodeTask). Pode will retry the process until either it succeeds, or it hits the max retry counter.

You can also specify a custom delay period; by default Pode will simply retry the process almost immediately (~20secs), but you can specify a custom `-RetryDelay` in minutes.

```powershell
# auto-retry up to 3 times, at approx. 1 minute intervals
Add-PodeTask -Name 'Example' -MaxRetries 3 -RetryDelay 1 -AutoRetry -ScriptBlock {
    # do some work
    return $user
}
```

#### Manual

To manually retry a failed Task process you can use [`Restart-PodeTaskProcess`](../../Functions/Tasks/Restart-PodeTaskProcess) - supplying the failed Task process, which can be retrieved from either [`Invoke-PodeTask`](../../Functions/Tasks/Invoke-PodeTask), [`Get-PodeTaskProcess`](../../Functions/Tasks/Get-PodeTaskProcess), or [`Restart-PodeTaskProcess`](../../Functions/Tasks/Restart-PodeTaskProcess) itself.

You can only restart failed processes, and retrying a process does increment and respect the `-MaxRetries` on `Add-PodeTask`.

```powershell
# allow the task to be retried up to 3 times
Add-PodeTask -Name 'Example' -MaxRetries 3 -ScriptBlock {
    # do some work
    return $user
}

# route to get failed processes, and retry them
Add-PodeRoute -Method Get -Path '/retry-tasks' -ScriptBlock {
    Get-PodeTaskProcess -State Failed | Foreach-Object {
        Restart-PodeTaskProcess -Process $_
    }
}
```

## Script from File

You normally define a task's script using the `-ScriptBlock` parameter however, you can also reference a file with the required scriptblock using `-FilePath`. Using the `-FilePath` parameter will dot-source a scriptblock from the file, and set it as the task's script.

For example, to create a task from a file that will output `Hello, world`:

* File.ps1

```powershell
{
    'Hello, world!' | Out-PodeHost
}
```

* Task

```powershell
Add-PodeTask -Name 'from-file' -FilePath './Tasks/File.ps1'
```

## Getting Tasks

The [`Get-PodeTask`](../../Functions/Tasks/Get-PodeTask) helper function will allow you to retrieve a list of tasks configured within Pode. You can use it to retrieve all of the tasks, or supply filters to retrieve specific ones.

To retrieve all of the tasks, you can call the function will no parameters. To filter, here are some examples:

```powershell
# one tasks by name
Get-PodeTask -Name Example1

# multiple tasks by name
Get-PodeTask -Name Example1, Example2
```

## Getting Task Processes

You can retrieve a list of processes triggered by Tasks via [`Get-PodeTaskProcess`](../../Functions/Tasks/Get-PodeTaskProcess) - this will return processes created via [`Invoke-PodeTask`](../../Functions/Tasks/Invoke-PodeTask).

You can either retrieve all processes, or filter them by Task Name, or Process ID/Status:

```powershell
# retrieves all task processes
Get-PodeTaskProcess

# retrieves all task processes for the "TaskName" process
Get-PodeTaskProcess -Name 'TaskName'

# retrieves the task process with ID "TaskId"
Get-PodeTaskProcess -Id 'TaskId'

# retrieves all running task processes
Get-PodeTaskProcess -State 'Running'

# retrieves all pending task processes for "TaskName"
Get-PodeTaskProcess -Name 'TaskName' -State 'Running'
```

## Task Object

!!! warning
    Be careful if you choose to edit these objects, as they will affect the server.

The following is the structure of the Task object internally, as well as the object that is returned from [`Get-PodeTask`](../../Functions/Tasks/Get-PodeTask):

| Name      | Type        | Description                              |
| --------- | ----------- | ---------------------------------------- |
| Name      | string      | The name of the Task                     |
| Script    | scriptblock | The scriptblock of the Task              |
| Arguments | hashtable   | The arguments supplied from ArgumentList |
