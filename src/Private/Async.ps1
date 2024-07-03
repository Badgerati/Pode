
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
param($WebEvent, $id)
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

    $enhancedScriptBlockContent = $enhancedScriptBlockTemplate -replace '<# ScriptBlock #>', $ScriptBlock.ToString()

    [ScriptBlock]::Create($enhancedScriptBlockContent)
}
