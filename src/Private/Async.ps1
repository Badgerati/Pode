
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
        $startingTime = [datetime]::UtcNow
        # $name = New-PodeGuid
        if ([string]::IsNullOrEmpty($Id)) {
            $Id = New-PodeGuid
        }
        $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $runspace = Add-PodeRunspace -Type AsyncRoutes -ScriptBlock (($Task.Script).GetNewClosure()) -Parameters $parameters -OutputStream $result -PassThru
        write-podehost "$Timeout -ge 0 = $($Timeout -ge 0)"
        if ($Timeout -ge 0) {
            $expireTime = [datetime]::UtcNow.AddSeconds($Timeout)
        }
        else {
            $expireTime = [datetime]::MaxValue
        }
        write-podehost  $expireTime

        $PodeContext.AsyncRoutes.Results[$Id] = @{
            ID            = $Id
            Task          = $Task.Name
            Runspace      = $runspace
            Result        = $result
            StartingTime  = $startingTime
            CompletedTime = $null
            ExpireTime    = $expireTime
            Timeout       = $Timeout
            State         = 'NotStarted'
            Error         = ''
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

    $enhancedScriptBlockTemplate = @'
<# Param #>
try {
    # Set the state to 'Running'
    $PodeContext.AsyncRoutes.Results[$id].State = 'Running'

    # Original ScriptBlock Start
    <# ScriptBlock #>
    # Original ScriptBlock End

}
catch {
    # Set the state to 'Failed' in case of error
    $PodeContext.AsyncRoutes.Results[$id].State = 'Failed'

    # Log the error
    $_ | Write-PodeErrorLog

    # Store the error in the AsyncRoutes results
    $PodeContext.AsyncRoutes.Results[$id].Error = $_

    return
}
finally {
    # Ensure state is set to 'Completed' if it was still 'Running'
    if ($PodeContext.AsyncRoutes.Results[$id].State -eq 'Running') {
        $PodeContext.AsyncRoutes.Results[$id].State = 'Completed'
    }

    # Set the completed time
    $PodeContext.AsyncRoutes.Results[$id].CompletedTime = [datetime]::UtcNow
}
'@
    $sc = $ScriptBlock.ToString()
    #  if ($sc.StartsWith('param(')) {

    # Split the string into lines
    $lines = $sc -split "`n"

    # Initialize variables
    $paramLineIndex = $null
    $parameters = ''

    # Find the line containing 'param' and extract parameters
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match "^\s*param\((.*)\)\s*$") {
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
        $param = 'param({0}, $WebEvent, $id)' -f $parameters
    }
    else {
        $remainingString = $string
        $param = 'param($WebEvent, $id)'
    }


    #  }
    #  else {
    #      $param = 'param($WebEvent, $id)'
    # }
    $enhancedScriptBlockContent = $enhancedScriptBlockTemplate.Replace('<# ScriptBlock #>', $remainingString.ToString()).Replace('<# Param #>', $param)


    [ScriptBlock]::Create($enhancedScriptBlockContent)
}




function Start-PodeAsyncRoutesHousekeeper {
    if (Test-PodeTimer -Name '__pode_asyncroutes_housekeeper__') {
        return
    }
    Add-PodeTimer -Name '__pode_asyncroutes_housekeeper__' -Interval 30 -ScriptBlock {
        write-podehost 'start __pode_asyncroutes_housekeeper__'
        write-podehost   $PodeContext.AsyncRoutes.Results.Count
        if ($PodeContext.AsyncRoutes.Results.Count -eq 0) {
            return
        }

        $now = [datetime]::UtcNow
        write-podehost     $PodeContext.AsyncRoutes.Results.Keys -Explode
        foreach ($key in $PodeContext.AsyncRoutes.Results.Keys.Clone()) {

            $result = $PodeContext.AsyncRoutes.Results[$key]
            Write-PodeHost "$($result.ExpireTime) -lt $now= $($result.ExpireTime -lt $now)"
            # has it force expired?
            if ($result.ExpireTime -lt $now) {
                Close-PodeAsyncRoutesInternal -Result $result
                continue
            }
            Write-PodeHost       $result.Runspace.Handler -Explode
            # is it completed?
            if (!$result.Runspace.Handler.IsCompleted) {
                continue
            }

            write-podeHost "$($result.CompletedTime.AddMinutes(1)) -lt $now = $($result.CompletedTime.AddMinutes(1) -lt $now)"
            if ($result.CompletedTime.AddMinutes(30) -lt $now) {
                write-podeHost 'Clean Force'
                Close-PodeAsyncRoutesInternal -Result $result -Force
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
        $Result,

        [switch]
        $Force
    )

    if ($null -eq $Result) {
        return
    }

    Close-PodeDisposable -Disposable $Result.Runspace.Pipeline
    Close-PodeDisposable -Disposable $Result.Result
    if ($Force) {
        $null = $PodeContext.AsyncRoutes.Results.Remove($Result.ID)
    }

}