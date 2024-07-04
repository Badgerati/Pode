
function Invoke-PodeInternalAsync {
    param(
        [Parameter(Mandatory = $true)]
        $Task,

        [Parameter()]
        [hashtable]
        $ArgumentList = $null,

        [Parameter()]
        [int]
        $Timeout = -1,

        [Parameter()]
        [string]
        $Id
    )

    try {
        # setup event param
        $parameters = @{
            Event = @{
                Lockable = $PodeContext.Threading.Lockables.Global
                Sender   = $Task
                Metadata = @{}
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

        $creationTime = [datetime]::UtcNow
        # $name = New-PodeGuid
        if ([string]::IsNullOrEmpty($Id)) {
            $Id = New-PodeGuid
        }

        $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $runspace = Add-PodeRunspace -Type AsyncRoutes -ScriptBlock (($Task.Script).GetNewClosure()) -Parameters $parameters -OutputStream $result -PassThru

        if ($Timeout -ge 0) {
            $expireTime = [datetime]::UtcNow.AddSeconds($Timeout)
        }
        else {
            $expireTime = [datetime]::MaxValue
        }

        $PodeContext.AsyncRoutes.Results[$Id] = @{
            ID            = $Id
            Task          = $Task.Name
            Runspace      = $runspace
            Result        = $result
            StartingTime  = $null
            CreationTime  = $creationTime
            CompletedTime = $null
            ExpireTime    = $expireTime
            Timeout       = $Timeout
            State         = 'NotStarted'
            Error         = $null
        }

        return $PodeContext.AsyncRoutes.Results[$Id]
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}


function ConvertTo-PodeEnhancedScriptBlock {
    param (
        [ScriptBlock]$ScriptBlock
    )

    $enhancedScriptBlockTemplate = {
        <# Param #>
        try {
            $PodeContext.AsyncRoutes.Results[$___async___id___].StartingTime = [datetime]::UtcNow
            # Set the state to 'Running'
            $PodeContext.AsyncRoutes.Results[$___async___id___].State = 'Running'

            # Original ScriptBlock Start
            <# ScriptBlock #>
            # Original ScriptBlock End

        }
        catch {
            # Set the state to 'Failed' in case of error
            $PodeContext.AsyncRoutes.Results[$___async___id___].State = 'Failed'

            # Log the error
            $_ | Write-PodeErrorLog

            # Store the error in the AsyncRoutes results
            $PodeContext.AsyncRoutes.Results[$___async___id___].Error = $_

            return
        }
        finally {
            # Ensure state is set to 'Completed' if it was still 'Running'
            if ($PodeContext.AsyncRoutes.Results[$___async___id___].State -eq 'Running') {
                $PodeContext.AsyncRoutes.Results[$___async___id___].State = 'Completed'
            }

            # Set the completed time
            $PodeContext.AsyncRoutes.Results[$___async___id___].CompletedTime = [datetime]::UtcNow
        }
    }

    $sc = $ScriptBlock.ToString()
    #  if ($sc.StartsWith('param(')) {

    # Split the string into lines
    $lines = $sc -split "`n"

    # Initialize variables
    $paramLineIndex = $null
    $parameters = ''

    # Find the line containing 'param' and extract parameters
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^\s*param\((.*)\)\s*$') {
            $parameters = $matches[1].Trim()
            $paramLineIndex = $i
            break
        }
    }
    # Remove the line containing 'param'
    if ($null -ne $paramLineIndex ) {
        if ($paramLineIndex -eq 0) {
            $remainingLines = $lines[1..($lines.Length - 1)]
        }
        else {
            $remainingLines = $lines[0..($paramLineIndex - 1)] + $lines[($paramLineIndex + 1)..($lines.Length - 1)]
        }

        $remainingString = $remainingLines -join "`n"
        $param = 'param({0}, $WebEvent, $___async___id___ )' -f $parameters
    }
    else {
        $remainingString = $sc
        $param = 'param($WebEvent, $___async___id___ )'
    }

    $enhancedScriptBlockContent = $enhancedScriptBlockTemplate.ToString().Replace('<# ScriptBlock #>', $remainingString.ToString()).Replace('<# Param #>', $param)

    [ScriptBlock]::Create($enhancedScriptBlockContent)
}




function Start-PodeAsyncRoutesHousekeeper {
    if (Test-PodeTimer -Name '__pode_asyncroutes_housekeeper__') {
        return
    }
    Add-PodeTimer -Name '__pode_asyncroutes_housekeeper__' -Interval 30 -ScriptBlock {
        #  write-podehost 'start __pode_asyncroutes_housekeeper__'
        #   write-podehost   $PodeContext.AsyncRoutes.Results.Count
        if ($PodeContext.AsyncRoutes.Results.Count -eq 0) {
            return
        }

        $now = [datetime]::UtcNow
        #    write-podehost     $PodeContext.AsyncRoutes.Results.Keys -Explode
        foreach ($key in $PodeContext.AsyncRoutes.Results.Keys.Clone()) {

            $result = $PodeContext.AsyncRoutes.Results[$key]
            #        Write-PodeHost "$($result.ExpireTime) -lt $now= $($result.ExpireTime -lt $now)"
            # has it force expired?
            if ($result.ExpireTime -lt $now) {
                Close-PodeAsyncRoutesInternal -Result $result
                continue
            }
            #       Write-PodeHost       $result.Runspace.Handler -Explode
            # is it completed?
            if (!$result.Runspace.Handler.IsCompleted) {
                continue
            }

            #        write-podeHost "$($result.CompletedTime.AddMinutes(1)) -lt $now = $($result.CompletedTime.AddMinutes(1) -lt $now)"
            if ($result.CompletedTime.AddMinutes(60) -lt $now) {
                write-podeHost 'Remove'
                $null = $PodeContext.AsyncRoutes.Results.Remove($Result.ID)
            }

            # is it expired by completion? if so, dispose and remove
            elseif ($result.CompletedTime.AddMinutes(1) -lt $now) {
                write-podeHost 'Clean only'
                Close-PodeAsyncRoutesInternal -Result $result
            }
        }

        $result = $null
    }
}


function Close-PodeAsyncRoutesInternal {
    param(
        [Parameter()]
        [hashtable]
        $Result
    )

    if ($null -eq $Result) {
        return
    }

    Close-PodeDisposable -Disposable $Result.Runspace.Pipeline
    Close-PodeDisposable -Disposable $Result.Result
    $Result.Remove('Runspace')
    $Result.Remove('Result')

}



function Add-PodeAsyncComponentSchema {
    param (
        [string]
        $Name = 'PodeTask'
    )
    if (!(Test-PodeOAComponent -Field schemas -Name  $Name)) {
        New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required |
            New-PodeOAStringProperty -Name 'CreationTime' -Format Date-Time -Example '2024-07-02T20:58:15.2014422Z' -Required |
            New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Example '2024-07-02T20:58:15.2014422Z' |
            New-PodeOAStringProperty -Name 'Result'   -Example '@{s=7}' |
            New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Example '2024-07-02T20:59:23.2174712Z' |
            New-PodeOAStringProperty -Name 'State' -Description 'Order Status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
            New-PodeOAStringProperty -Name 'Error' -Description 'The Error message if any.' |
            New-PodeOAStringProperty -Name 'Task' -Example 'Get:/path' -Required |
            New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $Name
    }

}