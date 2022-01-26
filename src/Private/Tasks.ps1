function Test-PodeTasksExist
{
    return (($null -ne $PodeContext.Tasks) -and (($PodeContext.Tasks.Enabled) -or ($PodeContext.Tasks.Items.Count -gt 0)))
}

function Start-PodeTaskHousekeeper
{
    if (!(Test-PodeTasksExist)) {
        return
    }

    Add-PodeTimer -Name '__pode_task_housekeeper__' -Interval 10 -ScriptBlock {
        if ($PodeContext.Tasks.Results.Count -eq 0) {
            return
        }

        $now = [datetime]::UtcNow

        foreach ($key in $PodeContext.Tasks.Results.Keys.Clone()) {
            $result = $PodeContext.Tasks.Results[$key]

            # has it force expired?
            if ($result.ExpireTime -lt $now) {
                Close-PodeTaskInternal -Result $result
                continue
            }

            # is it completed?
            if (!$result.Runspace.Handler.IsCompleted) {
                continue
            }

            # is a completed time set?
            if ($null -eq $result.CompletedTime) {
                $result.CompletedTime = [datetime]::UtcNow
                continue
            }

            # is it expired by completion? if so, dispose and remove
            if ($result.CompletedTime.AddMinutes(1) -lt $now) {
                Close-PodeTaskInternal -Result $result
            }
        }
    }
}

function Close-PodeTaskInternal
{
    param(
        [Parameter()]
        [hashtable]
        $Result
    )

    Close-PodeDisposable -Disposable $Result.Runspace.Pipeline
    Close-PodeDisposable -Disposable $Result.Result
    $PodeContext.Tasks.Results.Remove($Result.ID)
}

function Invoke-PodeInternalTask
{
    param(
        [Parameter(Mandatory=$true)]
        $Task,

        [Parameter()]
        [object[]]
        $ArgumentList = $null,

        [Parameter()]
        [int]
        $Timeout = -1
    )

    try {
        # setup event param
        $parameters = @{
            Event = @{
                Lockable = $PodeContext.Lockables.Global
                Sender = $Task
            }
        }

        # add any task args
        foreach ($key in $Task.Arguments.Keys) {
            $parameters[$key] = $Task.Arguments[$key]
        }

        # add adhoc task invoke args
        if (($null -ne $ArgumentList) -and ($ArgumentList.Count -gt 0)) {
            foreach ($key in $ArgumentList.Keys) {
                $parameters[$key] = $ArgumentList[$key]
            }
        }

        # add any using variables
        if ($null -ne $Task.UsingVariables) {
            foreach ($usingVar in $Task.UsingVariables) {
                $parameters[$usingVar.NewName] = $usingVar.Value
            }
        }

        $name = New-PodeGuid
        $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $runspace = Add-PodeRunspace -Type Tasks -ScriptBlock (($Task.Script).GetNewClosure()) -Parameters $parameters -OutputStream $result -PassThru

        if ($Timeout -ge 0) {
            $expireTime = [datetime]::UtcNow.AddSeconds($Timeout)
        }
        else {
            $expireTime = [datetime]::MaxValue
        }

        $PodeContext.Tasks.Results[$name] = @{
            ID = $name
            Task = $Task.Name
            Runspace = $runspace
            Result = $result
            CompletedTime = $null
            ExpireTime = $expireTime
            Timeout = $Timeout
        }

        return $PodeContext.Tasks.Results[$name]
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}