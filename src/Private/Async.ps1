
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
        $runspace = Add-PodeRunspace -Type $Task.name -ScriptBlock (($Task.Script).GetNewClosure()) -Parameters $parameters -OutputStream $result -PassThru

        if ($Timeout -ge 0) {
            $expireTime = [datetime]::UtcNow.AddSeconds($Timeout)
        }
        else {
            $expireTime = [datetime]::MaxValue
        }

        $PodeContext.AsyncRoutes.Results[$Id] = @{
            ID            = $Id
            Name          = $Task.Name
            Runspace      = $runspace
            Result        = $result
            StartingTime  = $null
            CreationTime  = $creationTime
            CompletedTime = $null
            ExpireTime    = $expireTime
            Timeout       = $Timeout
            State         = 'NotStarted'
            Error         = $null
            CallbackInfo  = $Task.CallbackInfo
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
        $asyncResult = $PodeContext.AsyncRoutes.Results[$___async___id___]
        try {
            $asyncResult.StartingTime = [datetime]::UtcNow
            # Set the state to 'Running'
            $asyncResult.State = 'Running'

            $___result___ = & { # Original ScriptBlock Start
                <# ScriptBlock #>
                # Original ScriptBlock End
            }
            return $___result___
        }
        catch {
            # Set the state to 'Failed' in case of error
            $asyncResult.State = 'Failed'

            # Log the error
            $_ | Write-PodeErrorLog

            # Store the error in the AsyncRoutes results
            $asyncResult.Error = $_

            return
        }
        finally {
            # Ensure state is set to 'Completed' if it was still 'Running'
            if ($asyncResult.State -eq 'Running') {
                $asyncResult.State = 'Completed'
            }

            # Set the completed time
            $asyncResult.CompletedTime = [datetime]::UtcNow

            try {
                if ($asyncResult.CallbackInfo) {
                    $callbackUrl = (CallBackResolver -Variable $asyncResult.CallbackInfo.UrlField).Value
                    write-podehost  $callbackUrl -Explode
                    write-podeHost "$($asyncResult.CallbackInfo.UrlField)=$callbackUrl"
                    $method = (CallBackResolver -Variable $asyncResult.CallbackInfo.Method -DefaultValue 'Post').Value
                    write-podeHost "method=$method"
                    $headers = @{}
                    foreach ($key in $asyncResult.HeaderFields.Keys) {
                        $value = CallBackResolver -Variable $key -DefaultValue $asyncResult.HeaderFields[$key]
                        if ($value) {
                            $headers.$($value.key) = $value.value
                        }
                    }

                    if ($asyncResult.CallbackInfo.SendResult) {
                        Invoke-RestMethod -Uri ($callbackUrl) -Method $method -Headers $headers -Body ($___result___ | ConvertTo-Json) -ContentType $asyncResult.CallbackInfo.ContentType
                    }
                    else {
                        Invoke-RestMethod -Uri ($callbackUrl) -Method $method -Headers $headers
                    }
                }
            }
            catch {
                # Log the error
                $_ | Write-PodeErrorLog
            }
        }
    }

    $sc = $ScriptBlock.ToString()

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
        if ($PodeContext.AsyncRoutes.Results.Count -eq 0) {
            return
        }

        $now = [datetime]::UtcNow
        foreach ($key in $PodeContext.AsyncRoutes.Results.Keys.Clone()) {

            $result = $PodeContext.AsyncRoutes.Results[$key]
            # has it force expired?
            if ($result.ExpireTime -lt $now) {
                Close-PodeAsyncRoutesInternal -Result $result
                continue
            }
            # is it completed?
            if (!$result.Runspace.Handler.IsCompleted) {
                continue
            }

            if ($result.CompletedTime.AddMinutes(60) -lt $now) {
                $null = $PodeContext.AsyncRoutes.Results.Remove($Result.ID)
            }

            # is it expired by completion? if so, dispose and remove
            elseif ($result.CompletedTime.AddMinutes(1) -lt $now) {
                Close-PodeAsyncRoutesInternal -Result $result
            }
        }

        $result = $null
    }
}

<#
.SYNOPSIS
    Closes and cleans up resources for asynchronous Pode routes.

.DESCRIPTION
    The Close-PodeAsyncRoutesInternal function is used to close and clean up disposable resources associated with asynchronous Pode routes.
    It ensures that runspaces and results are properly disposed of and removed from the provided result hashtable.

.PARAMETER Result
    A hashtable containing the resources to be disposed of. The hashtable should contain 'Runspace' and 'Result' keys.

.EXAMPLE
    $result = @{
        Runspace = [some runspace object]
        Result   = [some result object]
    }
    Close-PodeAsyncRoutesInternal -Result $result

    This example demonstrates how to use the Close-PodeAsyncRoutesInternal function to clean up resources in the provided result hashtable.

.OUTPUTS
    None
#>
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


<#
.SYNOPSIS
    Adds an OpenAPI component schema for Pode asynchronous tasks.

.DESCRIPTION
    The Add-PodeAsyncComponentSchema function creates an OpenAPI component schema for Pode asynchronous tasks if it does not already exist.
    This schema includes properties such as ID, CreationTime, StartingTime, Result, CompletedTime, State, Error, and Task.

.PARAMETER Name
    The name of the OpenAPI component schema. Defaults to 'PodeTask'.

.EXAMPLE
    Add-PodeAsyncComponentSchema -Name 'CustomTask'

    This example creates an OpenAPI component schema named 'CustomTask' with the specified properties if it does not already exist.

.OUTPUTS
    None
#>
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
            New-PodeOAStringProperty -Name 'Name' -Example 'Get:/path' -Required |
            New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $Name
    }

}

<#
.SYNOPSIS
    Searches for asynchronous Pode tasks based on specified query conditions.

.DESCRIPTION
    The Search-PodeAsyncTask function searches the Pode context for asynchronous tasks that match the specified query conditions.
    It supports comparison operators such as greater than (GT), less than (LT), greater than or equal (GE), less than or equal (LE),
    equal (EQ), not equal (NE), like (LIKE), and not like (NOTLIKE).

.PARAMETER Query
    A hashtable containing the query conditions. Each key in the hashtable represents a field to search on,
    and the value is another hashtable containing 'op' (operator) and 'value' (comparison value).

.EXAMPLE
    $query = @{
        'State' = @{ 'op' = 'EQ'; 'value' = 'Running' }
        'CreationTime' = @{ 'op' = 'GT'; 'value' = (Get-Date).AddHours(-1) }
    }
    $results = Search-PodeAsyncTask -Query $query

    This example searches for tasks that are in the 'Running' state and were created within the last hour.

.OUTPUTS
    Returns an array of hashtables representing the matched tasks.
#>
function Search-PodeAsyncTask {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Query
    )

    $matchedElements = @()
    if ($PodeContext.AsyncRoutes.Results.count -gt 0) {
        foreach ( $rkey in $PodeContext.AsyncRoutes.Results.keys.Clone()) {
            $result = $PodeContext.AsyncRoutes.Results[$rkey]
            $match = $true

            foreach ($key in $Query.Keys) {
                $queryCondition = $Query[$key]

                if ($queryCondition.ContainsKey('op') -and $queryCondition.ContainsKey('value')) {
                    if ($result.ContainsKey( $key) -and ($null -ne $result[$key])) {

                        $operator = $queryCondition['op']
                        $value = $queryCondition['value']

                        switch ($operator) {
                            'GT' {
                                $match = $match -and ($result[$key] -gt $value)
                                break
                            }
                            'LT' {
                                $match = $match -and ($result[$key] -lt $value)
                                break
                            }
                            'GE' {
                                $match = $match -and ($result[$key] -ge $value)
                                break
                            }
                            'LE' {
                                $match = $match -and ($result[$key] -le $value)
                                break
                            }
                            'EQ' {
                                $match = $match -and ($result[$key] -eq $value)
                                break
                            }
                            'NE' {
                                $match = $match -and ($result[$key] -ne $value)
                                break
                            }
                            'NOTLIKE' {
                                $match = $match -and ($result[$key] -notlike "*$value*")
                                break
                            }
                            'LIKE' {
                                $match = $match -and ($result[$key] -like "*$value*")
                                break
                            }
                            Default {
                                $match = $match -and $false
                                break
                            }
                        }
                    }
                    else {
                        $match = $match -and $false
                    }
                }
                else {
                    # The query provided has an invalid format.
                    throw $PodeLocale.InvalidQueryFormatExceptionMessage
                }
            }

            if ($match) {
                $matchedElements += $result
            }
        }
    }
    return $matchedElements
}


function CallBackResolver {
    param( [string]$Variable, [string]$DefaultValue)
    if ( $Variable.StartsWith('$request.header')) {
        if ($Variable -match '^[^.]*\.[^.]*\.(.*)') {
            $Value = $WebEvent.Request.Headers[$Matches[1]]
            if ($value) {
                return @{Key = $Matches[1]; Value = $value }
            }
            else {
                return @{Key = $Matches[1]; Value = $DefaultValue }
            }
        }
    }
    elseif ( $Variable.StartsWith('$request.query')) {
        $Value =   $WebEvent.Query[ $Matches[1]]
        if ($Variable -match '^[^.]*\.[^.]*\.(.*)') {
            if ($value) {
                return @{Key = $Matches[1]; Value = $value }
            }
            else {
                return @{Key = $Matches[1]; Value = $DefaultValue }
            }
        }
    }
    elseif ( $Variable.StartsWith('$request.body')) {
        if ($Variable -match '^[^.]*\.[^.]*#/(.*)') {
            $value =$WebEvent.data.$($Matches[1])
            if ($value) {
                return @{Key = $Matches[1]; Value = $value }
            }
            else {
                return @{Key = $Matches[1]; Value = $DefaultValue }
            }
        }
    }

    if (! [string]::IsNullOrEmpty( $DefaultValue)) {
        return  @{Key = $Variable; Value = $DefaultValue }
    }

    return @{Key = $Variable; Value = $Variable }
}
