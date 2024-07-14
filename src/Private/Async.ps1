
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
            Cancelable    = $Task.Cancelable
        }

        if ($WebEvent.Auth.User) {
            $PodeContext.AsyncRoutes.Results[$Id].User = $WebEvent.Auth.User
            $PodeContext.AsyncRoutes.Results[$Id].Permission = Copy-PodeDeepClone $Task.Permission
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
                    $callbackUrl = (Convert-PodeCallBackRuntimeExpression -Variable $asyncResult.CallbackInfo.UrlField).Value
                    $method = (Convert-PodeCallBackRuntimeExpression -Variable $asyncResult.CallbackInfo.Method -DefaultValue 'Post').Value
                    $contentType = (Convert-PodeCallBackRuntimeExpression -Variable $asyncResult.CallbackInfo.ContentType).Value
                    $headers = @{}
                    foreach ($key in $asyncResult.HeaderFields.Keys) {
                        $value = Convert-PodeCallBackRuntimeExpression -Variable $key -DefaultValue $asyncResult.HeaderFields[$key]
                        if ($value) {
                            $headers.$($value.key) = $value.value
                        }
                    }
                    $body = @{
                        Url       = $WebEvent.Request.Url
                        Method    = $WebEvent.Method
                        EventName = $asyncResult.CallbackInfo.EventName
                    }
                    if ($asyncResult.CallbackInfo.SendResult) {
                        $body.Result = $___result___
                    }
                    switch ($contentType) {
                        'application/json' { $cBody = ($body | ConvertTo-Json -depth 10) }
                        'application/xml' { $cBody = ($body | ConvertTo-Xml -NoTypeInformation ) }
                        'application/yaml' { $cBody = ($body | ConvertTo-PodeYaml -depth 10) }
                    }

                    Invoke-RestMethod -Uri ($callbackUrl) -Method $method -Headers $headers -Body $cBody -ContentType $contentType
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
        $Name = 'PodeTask',

        [string[]]
        $DefinitionTag
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    if (!(Test-PodeOAComponent -Field schemas -Name  $Name -DefinitionTag $DefinitionTag)) {
        New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required |
            New-PodeOAStringProperty -Name 'CreationTime' -Format Date-Time -Example '2024-07-02T20:58:15.2014422Z' -Required |
            New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Example '2024-07-02T20:58:15.2014422Z' |
            New-PodeOAStringProperty -Name 'Result'   -Example '@{s=7}' |
            New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Example '2024-07-02T20:59:23.2174712Z' |
            New-PodeOAStringProperty -Name 'State' -Description 'Order Status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
            New-PodeOAStringProperty -Name 'Error' -Description 'The Error message if any.' |
            New-PodeOAStringProperty -Name 'Name' -Example 'Get:/path' -Required |
            New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $Name -DefinitionTag $DefinitionTag
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
        $Query,

        [Parameter( )]
        [hashtable]
        $User
    )

    $matchedElements = @()
    if ($PodeContext.AsyncRoutes.Results.count -gt 0) {
        foreach ( $rkey in $PodeContext.AsyncRoutes.Results.keys.Clone()) {
            $result = $PodeContext.AsyncRoutes.Results[$rkey]

            if ($result.User -and ($null -eq $User)) {
                continue
            }
            if (! (Test-PodeAsyncPermission -Permission $result.Permission.Read -User $User)) {
                continue
            }

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

<#
.SYNOPSIS
    Converts runtime expressions for Pode callback variables.

.DESCRIPTION
    The `Convert-PodeCallBackRuntimeExpression` function processes runtime expressions
    for Pode callback variables. It interprets variables in headers, query parameters,
    and body fields from the web event request, providing a default value if the variable
    is not resolvable. This function is used in the context of OpenAPI callback specifications
    to dynamically resolve values at runtime.

.PARAMETER Variable
    The variable expression to be converted. This can be a header, query parameter, or body field.
    Valid formats include:
    - $request.header.header-name
    - $request.query.param-name
    - $request.body#/field-name

.PARAMETER DefaultValue
    The default value to be used if the variable cannot be resolved from the request.

.INPUTS
    [string], [string]

.OUTPUTS
    [hashtable]
    The output is a hashtable containing the resolved key and value.

.EXAMPLE
    # Convert a header variable with a default value
    $result = Convert-PodeCallBackRuntimeExpression -Variable '$request.header.Content-Type' -DefaultValue 'application/json'
    Write-Output $result

.EXAMPLE
    # Convert a query parameter variable with a default value
    $result = Convert-PodeCallBackRuntimeExpression -Variable '$request.query.userId' -DefaultValue 'unknown'
    Write-Output $result

.EXAMPLE
    # Convert a body field variable with a default value
    $result = Convert-PodeCallBackRuntimeExpression -Variable '$request.body#/user/name' -DefaultValue 'anonymous'
    Write-Output $result

.NOTES
    This function is used in the context of OpenAPI callback specifications to dynamically resolve
    values at runtime. The parameters can accept the following meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl

    If the variable cannot be resolved from the request, the provided default value is used.
    If no default value is provided and the variable cannot be resolved, the variable itself is returned as the value.
#>
function Convert-PodeCallBackRuntimeExpression {
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
        $Value = $WebEvent.Query[ $Matches[1]]
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
            $value = $WebEvent.data.$($Matches[1])
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



function Test-PodeAsyncPermission {
    param(
        [hashtable]
        $Permission,
        [hashtable]
        $User
    )
    foreach ($key in $Permission.Keys) {
        Write-PodeHost "Permission Key=$key"

        if ($User.ContainsKey($key)) {
            Write-PodeHost "User Key=$key"
            if (  Test-PodeArraysHaveCommonElement -ReferenceArray $Permission[$key] -DifferenceArray $User[$key]) {
                return $true
            }
        }
        elseif ($key -eq 'Users') {
            write-podehost $Permission[$key] -Explode
            write-podehost $User.ID
            if (Test-PodeArraysHaveCommonElement -ReferenceArray $Permission[$key] -DifferenceArray  $User.ID) {
                return $true
                write-podehost $true
            }
        }
    }
    return $false
}


function Get-PodeAsyncSetScriptBlock{

    return [scriptblock] {
        param($Timeout, $IdGenerator, $AsyncPoolName)
        $responseMediaType = Get-PodeHeader -Name 'Accept'
        $id = (& $IdGenerator)

        # Invoke the internal async task
        $async = Invoke-PodeInternalAsync -Id $id -Task $PodeContext.AsyncRoutes.Items[$AsyncPoolName] -Timeout $Timeout -ArgumentList @{ WebEvent = $WebEvent; ___async___id___ = $id }

        # Prepare the response
        $res = @{
            CreationTime = $async.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            Id           = $async.ID
            State        = $async.State
            Name         = $async.Name
            Cancelable   = $async.Cancelable
        }

        if ($async.User) {
            $res.User = $async.User
            Write-PodeHost $async.Permission.Read -Explode
            # Add default permission
            if (! ($async.Permission.Read.Users -ccontains $async.User.ID)  ) {
                $async.Permission.Read.Users += $async.User.ID
            }
            if (! ($async.Permission.Write.Users -ccontains $async.User.ID)  ) {
                $async.Permission.Write.Users += $async.User.ID
            }
            $res.Permission = $async.Permission
        }

        # Send the response based on the requested media type
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $res -StatusCode 200; break }
            'application/json' { Write-PodeJsonResponse -Value $res -StatusCode 200 ; break }
            'text/yaml' { Write-PodeYamlResponse -Value $res -StatusCode 200 ; break }
            default { Write-PodeJsonResponse -Value $res -StatusCode 200 }
        }
    }
}

function Get-PodeAsyncGetScriptBlock {
return [scriptblock] {
    param($In, $TaskIdName)
    switch ($In) {
        'Cookie' { $id = Get-PodeCookie -Name $TaskIdName; break }
        'Header' { $id = Get-PodeHeader -Name $TaskIdName; break }
        'Path' { $id = $WebEvent.Parameters[$TaskIdName]; break }
        'Query' { $id = $WebEvent.Query[$TaskIdName]; break }
    }

    $responseMediaType = Get-PodeHeader -Name 'Accept'
    if ($PodeContext.AsyncRoutes.Results.ContainsKey($id )) {
        $result = $PodeContext.AsyncRoutes.Results[$id]

        $taskSummary = @{
            ID           = $result.ID
            User         = $result.User
            Cancelable   = $result.Cancelable
            Permission   = $result.Permission
            # ISO 8601 UTC format
            CreationTime = $result.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            Name         = $result.Name
            State        = $result.State
        }

        if ($result.StartingTime) {
            $taskSummary.StartingTime = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
        }
        if ($result.User) {
            if ($WebEvent.Auth.User) {
                $taskSummary.User = $result.User
                $taskSummary.Permission = $result.Permission
                $authorized = Test-PodeAsyncPermission -Permission $result.Permission.Read -User $WebEvent.Auth.User
            }
            else {
                $authorized = $false
            }
        }
        else {
            $authorized = $true
        }
        if ($authorized) {
            if ($PodeContext.AsyncRoutes.Results[$id].Runspace.Handler.IsCompleted) {
                # ISO 8601 UTC format
                $taskSummary.CompletedTime = $result.CompletedTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                switch ($result.State.ToLowerInvariant() ) {
                    'failed' {
                        $taskSummary.Error = $result.Error
                        break
                    }
                    'completed' {
                        if ($result.result.Count -gt 0) {
                            $taskSummary.Result = $result.result[0]
                        }
                        else {
                            $result.result = $null
                        }
                        break
                    }
                    'aborted' {
                        $taskSummary.Error = $result.Error
                        break
                    }
                }
            }

            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $taskSummary -StatusCode 200; break }
                'application/json' { Write-PodeJsonResponse -Value $taskSummary -StatusCode 200 ; break }
                'text/yaml' { Write-PodeYamlResponse -Value $taskSummary -StatusCode 200 ; break }
                default { Write-PodeJsonResponse -Value $taskSummary -StatusCode 200 }
            }
            return
        }
        else {
            $errorMsg = @{ID = $id ; Error = 'The User is not entitle to this operation' }
            $statusCode = 401 #'Unauthorized'
        }
    }
    else {
        $errorMsg = @{ID = $id ; Error = 'No Task Found' }
        $statusCode = 404 #'Not Found'
    }
    switch ($responseMediaType) {
        'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode; break }
        'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
        'text/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
        default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
    }
}
}

function Get-PodeAsyncStopScriptBlock {
    return [scriptblock]{
        param($In, $TaskIdName)

        # Determine the source of the task ID based on the input parameter
        switch ($In) {
            'Cookie' { $id = Get-PodeCookie -Name $TaskIdName; break }
            'Header' { $id = Get-PodeHeader -Name $TaskIdName; break }
            'Path' { $id = $WebEvent.Parameters[$TaskIdName]; break }
            'Query' { $id = $WebEvent.Query[$TaskIdName]; break }
        }

        # Get the 'Accept' header from the request to determine response format
        $responseMediaType = Get-PodeHeader -Name 'Accept'

        # Check if the task ID exists in the async routes results
        if ($PodeContext.AsyncRoutes.Results.ContainsKey($id)) {
            $result = $PodeContext.AsyncRoutes.Results[$id]

            # If the task is not completed
            if (!$result.Runspace.Handler.IsCompleted) {
                # If the task is cancelable
                if ($result.Cancelable) {

                    if ($result.User -and ($null -eq $WebEvent.Auth.User)) {
                        # If the task is not cancelable, set an error message
                        $errorMsg = @{ID = $id ; Error = 'This Async operation required authentication.' }
                        $statusCode = 203 #'Non-Authoritative Information'
                    }
                    else {
                        if ((Test-PodeAsyncPermission -Permission $result.Permission.Write -User $WebEvent.Auth.User)) {
                            # Set the task state to 'Aborted' and log the error and completion time
                            $result.State = 'Aborted'
                            $result.Error = 'User Aborted!'
                            $result.CompletedTime = [datetime]::UtcNow

                            # Create a summary of the task
                            $taskSummary = @{
                                ID            = $id
                                CreationTime  = $result.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                                Name          = $result.Name
                                State         = $result.State
                                CompletedTime = $result.CompletedTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                                Error         = $result.Error
                            }
                            # Include the starting time if available
                            if ($result.StartingTime) {
                                $taskSummary.StartingTime = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                            }

                            # Close any open resources associated with the task
                            Close-PodeDisposable -Disposable $result.Runspace.Pipeline
                            Close-PodeDisposable -Disposable $Result.Result

                            # Respond with the task summary in the appropriate format
                            switch ($responseMediaType) {
                                'application/xml' { Write-PodeXmlResponse -Value $taskSummary -StatusCode 200; break }
                                'application/json' { Write-PodeJsonResponse -Value $taskSummary -StatusCode 200 ; break }
                                'text/yaml' { Write-PodeYamlResponse -Value $taskSummary -StatusCode 200 ; break }
                                default { Write-PodeJsonResponse -Value $taskSummary -StatusCode 200 }
                            }
                            return
                        }
                        else {
                            $errorMsg = @{ID = $id ; Error = 'The User is not entitle to this operation' }
                            $statusCode = 401 #'Unauthorized'
                        }
                    }
                }
                else {
                    # If the task is not cancelable, set an error message
                    $errorMsg = @{ID = $id ; Error = "The task has the 'NonCancelable' flag." }
                    $statusCode = 423 #'Locked
                }
            }
            else {
                # If the task is already completed, set an error message
                $errorMsg = @{ID = $id ; Error = 'The Task is already completed.' }
                $statusCode = 410 #'Gone'
            }
        }
        else {
            # If no task is found, set an error message
            $errorMsg = @{ID = $id ; Error = 'No Task Found.' }
            $statusCode = 404 #'Not Found'
        }

        # Respond with the error message in the appropriate format
        if ($errorMsg) {
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
                'text/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
            }
        }
    }
}

function Get-PodeAsyncQueryScriptBlock {
    return [scriptblock]{
        param($Payload)
        switch ($Payload) {
            'Body' { $query = $WebEvent.Data }
            'Query' { $query = $WebEvent.Query[$Name] }
            'Header' { $query = $WebEvent.Request.Headers['query'] }
        }
        $responseMediaType = Get-PodeHeader -Name 'Accept'
        $response = @()
        $results = Search-PodeAsyncTask -Query $query -User $WebEvent.Auth.User
        if ($results) {
            foreach ($result in $results) {

                $taskSummary = @{
                    ID           = $result.ID
                    User         = $result.User
                    Cancelable   = $result.Cancelable
                    Permission   = $result.Permission
                    # ISO 8601 UTC format
                    CreationTime = $result.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    Name         = $result.Name
                    State        = $result.State
                }

                if ($result.StartingTime) {
                    $taskSummary.StartingTime = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                }
                if ($result.User) {
                    $taskSummary.User = $result.User
                    $taskSummary.Permission = $result.Permission
                }

                if ($result.Runspace.Handler.IsCompleted) {
                    # ISO 8601 UTC format
                    $taskSummary.CompletedTime = $result.CompletedTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    switch ($result.State.ToLowerInvariant() ) {
                        'failed' {
                            $taskSummary.Error = $result.Error
                            break
                        }
                        'completed' {
                            if ($result.result.Count -gt 0) {
                                $taskSummary.Result = $result.result[0]
                            }
                            else {
                                $result.result = $null
                            }
                            break
                        }
                        'aborted' {
                            $taskSummary.Error = $result.Error
                            break
                        }
                    }
                }
                $response += $taskSummary
            }
        }
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $response -StatusCode 200; break }
            'application/json' { Write-PodeJsonResponse -Value $response -StatusCode 200 ; break }
            'text/yaml' { Write-PodeYamlResponse -Value $response -StatusCode 200 ; break }
            default { Write-PodeJsonResponse -Value $response -StatusCode 200 }
        }
    }

}