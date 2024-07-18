
<#
.SYNOPSIS
    Invokes an asynchronous task within the Pode framework.

.DESCRIPTION
    The `Invoke-PodeInternalAsync` function sets up and starts an asynchronous task in Pode. It handles the creation
    of parameters, initialization of runspaces, and tracking of task execution state, results, and errors.

.PARAMETER Task
    The task to be executed asynchronously. This parameter is mandatory.

.PARAMETER ArgumentList
    A hashtable of additional arguments to pass to the task. This parameter is optional.

.PARAMETER Timeout
    The timeout period in seconds for the task. If set to -1, the task will not expire. This parameter is optional.

.PARAMETER Id
    A custom identifier for the task. If not provided, a new GUID will be generated. This parameter is optional.

.OUTPUTS
    [hashtable] - Returns a hashtable containing details about the asynchronous task, including its ID, runspace,
    result, state, and any errors.

.EXAMPLE
    $task = @{
        Name = "ExampleTask"
        Script = {
            param($param1, $param2)
            # Task code here
        }
        Arguments = @{
            param1 = "value1"
            param2 = "value2"
        }
        UsingVariables = @()
        CallbackSettings = $null
        Cancelable = $false
    }

    $result = Invoke-PodeInternalAsync -Task $task -Timeout 300

.NOTES
    - The function handles the creation and management of asynchronous tasks in Pode.
    - It sets up the parameters, initializes the runspace, and tracks the task's state, results, and any errors.
    - This is an internal function and may change in future releases of Pode.
#>
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

        $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $runspace = Add-PodeRunspace -Type $Task.name -ScriptBlock (($Task.Script).GetNewClosure()) -Parameters $parameters -OutputStream $result -PassThru

        if ($Timeout -ge 0) {
            $expireTime = [datetime]::UtcNow.AddSeconds($Timeout)
        }
        else {
            $expireTime = [datetime]::MaxValue
        }

        $dctResult = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        #  $dctResult = @{}
        $dctResult['ID'] = $Id
        $dctResult['Name'] = $Task.Name
        $dctResult['Runspace'] = $runspace
        $dctResult['Output'] = $result
        $dctResult['StartingTime'] = $null
        $dctResult['CreationTime'] = $creationTime
        $dctResult['CompletedTime'] = $null
        $dctResult['ExpireTime'] = $expireTime
        $dctResult['Timeout'] = $Timeout
        $dctResult['State'] = 'NotStarted'
        $dctResult['Error'] = $null
        $dctResult['CallbackSettings'] = $Task.CallbackSettings
        $dctResult['Cancelable'] = $Task.Cancelable
        $dctResult['EnableSse'] = $Task.EnableSse
        $dctResult['SseGroup'] = $Task.SseGroup

        if ($WebEvent.Auth.User) {
            $dctResult['User'] = $WebEvent.Auth.User.ID
            $dctResult['Permission'] = Copy-PodeDeepClone $Task.Permission
        }
        $dctResult['Url'] = $WebEvent.Request.Url
        $dctResult['Method'] = $WebEvent.Method
        $PodeContext.AsyncRoutes.Results[$Id] = $dctResult
        return $dctResult
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}

<#
.SYNOPSIS
    Converts a provided script block into an enhanced script block for asynchronous execution in Pode.

.DESCRIPTION
    The `ConvertTo-PodeEnhancedScriptBlock` function takes a given script block and wraps it with additional code
    to manage asynchronous execution within the Pode framework. It handles setting up the execution state,
    logging errors, and invoking callback URLs with results.

.PARAMETER ScriptBlock
    The original script block to be converted into an enhanced script block.

.RETURNS
    [ScriptBlock] - Returns the enhanced script block suitable for asynchronous execution in Pode.

.EXAMPLE
    $originalScriptBlock = {
        param($param1, $param2)
        # Script block code here
    }

    $enhancedScriptBlock = ConvertTo-PodeEnhancedScriptBlock -ScriptBlock $originalScriptBlock

    # Now you can use $enhancedScriptBlock for asynchronous execution in Pode.

.NOTES
    - The enhanced script block manages state transitions, error logging, and optional callback invocations.
    - It supports additional parameters for WebEvent and Async ID.
    - This is an internal function and may change in future releases of Pode.
#>

function ConvertTo-PodeEnhancedScriptBlock {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock
    )

    $enhancedScriptBlockTemplate = {
        <# Param #>
        # sometime the key is not available when the process start. workaround wait 2 secs
        if (!$PodeContext.AsyncRoutes.Results.ContainsKey($___async___id___)) {
            Start-Sleep 2
        }
        if ($PodeContext.AsyncRoutes.Results.ContainsKey($___async___id___)) {
            $asyncResult = $PodeContext.AsyncRoutes.Results[$___async___id___]
            try {
                $asyncResult['StartingTime'] = [datetime]::UtcNow

                # Set the state to 'Running'
                $asyncResult['State'] = 'Running'

                if ($asyncResult['EnableSse']) {
                    if ($asyncResult.ContainsKey('SseGroup')) {
                        ConvertTo-PodeSseConnection -Name $___async___id___ -Scope Local -Group $asyncResult['SseGroup']
                    }
                    else {
                        ConvertTo-PodeSseConnection -Name $___async___id___ -Scope Local
                    }
                }

                $___result___ = & { # Original ScriptBlock Start
                    <# ScriptBlock #>
                    # Original ScriptBlock End
                }
                if ($___result___) {
                    $asyncResult['Result'] = $___result___
                }
                # Set the completed time
                $asyncResult['CompletedTime'] = [datetime]::UtcNow
            }
            catch {
                if (! $asyncResult.ContainsKey('CompletedTime')) {
                    $asyncResult['CompletedTime'] = [datetime]::UtcNow
                }
                # Set the state to 'Failed' in case of error
                $asyncResult['State'] = 'Failed'

                # Log the error
                $_ | Write-PodeErrorLog

                # Store the error in the AsyncRoutes results
                $asyncResult['Error'] = $_.ToString()

            }
            finally {
                Complete-PodeAsyncScriptFinally -AsyncResult $asyncResult
            }
        }
        else {
            try {
                throw ($PodeLocale.asyncIdDoesNotExistExceptionMessage -f $___async___id___)
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

    return [ScriptBlock]::Create($enhancedScriptBlockContent)
}


<#
.SYNOPSIS
    Closes an asynchronous script execution, setting its state to 'Completed' and handling callback invocations.

.DESCRIPTION
    The `Complete-PodeAsyncScriptFinally` function finalizes an asynchronous script's execution by setting its state to 'Completed' if it is still running and logs the completion time. It also manages callbacks by sending requests to a specified callback URL with appropriate headers and content types. If Server-Sent Events (SSE) are enabled, the function will send events based on the execution state.

.PARAMETER AsyncResult
    A [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] that contains the results and state information of the asynchronous script.

.EXAMPLE
    $asyncResult = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
    $webEvent = @{
        Request = @{
            Url = 'http://example.com/request'
        }
        Method = 'GET'
    }
    Complete-PodeAsyncScriptFinally -AsyncResult $asyncResult -WebEvent $webEvent

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Complete-PodeAsyncScriptFinally {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]
        $AsyncResult
    )
    # Set the completed time
    if (! $AsyncResult.ContainsKey('CompletedTime')) {
        $AsyncResult['CompletedTime'] = [datetime]::UtcNow
    }

    # Ensure state is set to 'Completed' if it was still 'Running'
    if ($AsyncResult.State -eq 'Running') {
        $AsyncResult['State'] = 'Completed'
    }

    try {
        if ($AsyncResult.CallbackSettings) {

            $callbackUrl = (Convert-PodeCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].UrlField).Value
            $method = (Convert-PodeCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].Method -DefaultValue 'Post').Value
            $contentType = (Convert-PodeCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].ContentType).Value
            $headers = @{}
            foreach ($key in $AsyncResult['CallbackSettings'].HeaderFields.Keys) {
                $value = Convert-PodeCallBackRuntimeExpression -Variable $key -DefaultValue $AsyncResult.HeaderFields[$key]
                if ($value) {
                    $headers.$($value.key) = $value.value
                }
            }

            $body = @{
                Url       = $AsyncResult['Url']
                Method    = $AsyncResult['Method']
                EventName = $AsyncResult['CallbackSettings'].EventName
                State     = $AsyncResult['State']
            }
            switch ( $AsyncResult['State'] ) {
                'Failed' {
                    $body.Error = $AsyncResult['Error']
                }
                'Completed' {
                    if ($AsyncResult['CallbackSettings'].SendResult -and $AsyncResult['Result']) {
                        $body.Result = $AsyncResult['Result']
                    }
                }
                'Aborted' {
                    $body.Error = $AsyncResult['Error']
                }
            }

            switch ($contentType) {
                'application/json' { $cBody = ($body | ConvertTo-Json -depth 10) }
                'application/xml' { $cBody = ($body | ConvertTo-Xml -NoTypeInformation ) }
                'application/yaml' { $cBody = ($body | ConvertTo-PodeYaml -depth 10) }
            }
            $AsyncResult['CallbackUrl'] = $callbackUrl
            $AsyncResult['CallbackInfoState'] = 'Running'
            $AsyncResult['CallbackTentative'] = 0
            for ($i = 0; $i -le 3; $i++) {
                try {
                    $AsyncResult['CallbackTentative'] = $AsyncResult['CallbackTentative'] + 1
                    $null = Invoke-RestMethod -Uri ($callbackUrl) -Method $method -Headers $headers -Body $cBody -ContentType $contentType
                    $AsyncResult['CallbackInfoState'] = 'Completed'
                    break
                }
                catch {
                    $_ | Write-PodeErrorLog
                    $AsyncResult['CallbackInfoState'] = 'Failed'
                    Start-Sleep -Seconds 2
                }
            }
        }
    }
    catch {
        # Log the error
        $_ | Write-PodeErrorLog
        $AsyncResult['CallbackInfoState'] = 'Failed'
    }

    if ($AsyncResult.EnableSse) {
        try {
            switch ( $AsyncResult['State'] ) {
                'Failed' {
                    Send-PodeSseEvent -FromEvent -Data @{State = $AsyncResult['State'] ; Error = $AsyncResult['Error'] }
                }
                'Completed' {
                    if ($AsyncResult['Result']) {
                        Send-PodeSseEvent -FromEvent -Data @{State = $AsyncResult['State'] ; Result = $AsyncResult['Result'] }
                    }
                    else {
                        Send-PodeSseEvent -FromEvent -Data @{State = 'Completed' }
                    }
                }
                'Aborted' {
                    Send-PodeSseEvent -FromEvent -Data @{State = $AsyncResult['State'] ; Error = $AsyncResult['Error'] }
                }
            }
            $AsyncResult['SeeEventInfoState'] = 'Completed'
        }
        catch {
            # Log the error
            $_ | Write-PodeErrorLog
            $AsyncResult['SeeEventInfoState'] = 'Failed'
        }
    }
}


<#
.SYNOPSIS
    Starts the housekeeper for Pode asynchronous routes.

.DESCRIPTION
    The `Start-PodeAsyncRoutesHousekeeper` function sets up a timer that periodically cleans up expired or completed asynchronous routes
    in Pode. It ensures that any expired or completed routes are properly handled and removed from the context.

.PARAMETER Interval
    Specifies the frequence of the scheduler

.PARAMETER RemoveAfterMinutes
    Specifies the number of minutes after completion when the route should be removed from the context. Default is 60 minutes.

.NOTES
    - The timer is named '__pode_asyncroutes_housekeeper__' and runs at an interval of 30 seconds.
    - The timer checks for forced expiry, completion, and completion expiry of asynchronous routes.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeAsyncRoutesHousekeeper {
    param(
        [Parameter()]
        [int]
        $RemoveAfterMinutes = 5,

        [Parameter()]
        [int]
        $Interval = 30
    )

    if (Test-PodeTimer -Name '__pode_asyncroutes_housekeeper__') {
        return
    }
    Add-PodeTimer -Name '__pode_asyncroutes_housekeeper__' -Interval $Interval -ArgumentList $RemoveAfterMinutes -ScriptBlock {
        param ( $RemoveAfterMinutes)
        if ($PodeContext.AsyncRoutes.Results.Count -eq 0) {
            return
        }

        $now = [datetime]::UtcNow
        foreach ($key in $PodeContext.AsyncRoutes.Results.Keys.Clone()) {
            $result = $PodeContext.AsyncRoutes.Results[$key]
            if ($result) {
                if ( $result['Runspace'].Handler.IsCompleted) {
                    try {
                        if ($result['CompletedTime'] -and $result['CompletedTime'].AddMinutes($RemoveAfterMinutes) -lt $now) {
                            $result['Runspace'].Pipeline.Dispose()
                            $v = 0
                            $removed = $PodeContext.AsyncRoutes.Results.TryRemove($key, [ref]$v)
                            Write-Verbose "Key $key Removed:$removed"
                        }
                    }
                    catch {
                        $_ | Write-PodeErrorLog
                    }
                }
                # has it force expired?
                elseif ($result['ExpireTime'] -lt $now  ) {
                    try {
                        $result['CompletedTime'] = $now
                        $result['State'] = 'Aborted'
                        $result['Error'] = 'Timeout'
                        $result['Runspace'].Pipeline.Dispose()
                        Complete-PodeAsyncScriptFinally -AsyncResult $result
                    }
                    catch {
                        $_ | Write-PodeErrorLog
                    }

                }
            }
        }
        $result = $null
    }
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

.NOTES
    This is an internal function and may change in future releases of Pode.
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

        $permissionContent = New-PodeOAStringProperty -Name 'Groups' -Array -Example 'group1', 'group2' |
            New-PodeOAStringProperty -Name 'Roles' -Array -Example 'reviewer', 'taskadmin' |
            New-PodeOAStringProperty -Name 'Scopes' -Array -Example 'scope1', 'scope2', 'scope3' |
            New-PodeOAStringProperty -Name 'Users' -Array -Example 'id0001', 'id0005', 'id0231'

        New-PodeOAStringProperty -Name 'ID' -Format Uuid  -Description 'The async operation unique inentifier.'  -Required |
            New-PodeOAStringProperty -Name 'User' -Description 'The async operation owner.' |
            New-PodeOAStringProperty -Name 'CreationTime' -Format Date-Time -Description 'The async operation creation time.' -Example '2024-07-02T20:58:15.2014422Z' -Required |
            New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Description 'The async operation starting time.' -Example '2024-07-02T20:58:15.2014422Z' |
            New-PodeOAStringProperty -Name 'Result'   -Example '{result = 7 , numOfIteration = 3 }' |
            New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Description 'The async operation completition time.' -Example '2024-07-02T20:59:23.2174712Z' |
            New-PodeOAStringProperty -Name 'State' -Description 'The async operation status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
            New-PodeOAStringProperty -Name 'Error' -Description 'The Error message if any.' |
            New-PodeOAStringProperty -Name 'Name' -Example '__Get_path_endpoint1_' -Description 'The async operation name.' -Required |
            New-PodeOABoolProperty -Name 'Cancelable'  -Description 'The async operation can be forcefully terminated' -Required |
            New-PodeOAObjectProperty -Name 'Permission' -Description 'The permission governing the async operation.' -Properties (
                ($permissionContent | New-PodeOAObjectProperty -Name 'Read'),
                ($permissionContent | New-PodeOAObjectProperty -Name 'Write')
            ) |
            New-PodeOAObjectProperty -Name 'Permission' -Description 'The Callback operation result' -Properties (
                New-PodeOAStringProperty -Name 'State' -Description 'Operation status' -Example 'Completed' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
                    New-PodeOAIntProperty -Name 'Tentative' -Description 'Number of tentatives' |
                    New-PodeOAStringProperty -Name 'Url' -Format Uri -Description 'The callback URL' -Example 'Completed'
                ) |
                New-PodeOAObjectProperty -Name 'CallbackSettings' -Description 'Callback Configuration' -Properties (
                    New-PodeOAStringProperty -Name 'UrlField' -Description 'The URL Field.'  -Example  '$request.body#/callbackUrl' |
                        New-PodeOABoolProperty -Name 'SendResult' -Description 'Send the result.' |
                        New-PodeOAStringProperty -Name 'Method' -Description 'Http Method.' -Enum @('Post', 'Put')
                    ) |
                    New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $Name -DefinitionTag $DefinitionTag
    }

}

<#
.SYNOPSIS
    Searches for asynchronous Pode tasks based on specified query conditions.

.DESCRIPTION
    The Search-PodeAsyncTask function searches the Pode context for asynchronous tasks that match the specified query conditions.
    It supports comparison operators such as greater than (GT), less than (LT), greater than or equal (GE), less than or equal (LE),
    equal (EQ), not equal (NE), like (LIKE), and not like (NOTLIKE). Additionally, it can check user permissions if specified.

.PARAMETER Query
    A hashtable containing the query conditions. Each key in the hashtable represents a field to search on,
    and the value is another hashtable containing 'op' (operator) and 'value' (comparison value).

.PARAMETER User
    An optional hashtable representing the user details. This is used when checking permissions on tasks.

.PARAMETER CheckPermission
    A switch to indicate whether to check permissions on tasks. If specified, the function will filter tasks based on the user's permissions.

.EXAMPLE
    $query = @{
        'State' = @{ 'op' = 'EQ'; 'value' = 'Running' }
        'CreationTime' = @{ 'op' = 'GT'; 'value' = (Get-Date).AddHours(-1) }
    }
    $results = Search-PodeAsyncTask -Query $query

    This example searches for tasks that are in the 'Running' state and were created within the last hour.

.EXAMPLE
    $user = @{
        'Name' = 'AdminUser'
        'Roles' = @('Admin', 'User')
    }
    $query = @{
        'State' = @{ 'op' = 'EQ'; 'value' = 'Completed' }
    }
    $results = Search-PodeAsyncTask -Query $query -User $user -CheckPermission

    This example searches for tasks that are in the 'Completed' state and checks if the specified user has permission to view them.

.OUTPUTS
    Returns an array of hashtables representing the matched tasks.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Search-PodeAsyncTask {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Query,

        [Parameter( )]
        [hashtable]
        $User,

        [switch]
        $CheckPermission
    )

    $matchedElements = @()
    if ($PodeContext.AsyncRoutes.Results.count -gt 0) {
        foreach ( $rkey in $PodeContext.AsyncRoutes.Results.keys.Clone()) {
            $result = $PodeContext.AsyncRoutes.Results[$rkey]

            if ($CheckPermission.IsPresent) {
                if ($result.User -and ($null -eq $User)) {
                    continue
                }
                if (! (Test-PodeAsyncPermission -Permission $result.Permission.Read -User $User)) {
                    continue
                }
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


<#
.SYNOPSIS
    Tests if a user has the required asynchronous permissions based on provided permissions hashtable.

.DESCRIPTION
    The `Test-PodeAsyncPermission` function checks if a user has the required permissions specified in the provided hashtable.
    It iterates through the keys in the permission hashtable and checks if the user has the necessary permissions.

.PARAMETER Permission
    A hashtable containing the permissions to be checked.

.PARAMETER User
    A hashtable containing the user information and their permissions.

.OUTPUTS
    [Boolean] - Returns $true if the user has the required permissions, otherwise $false.

.EXAMPLE

    $user = @{
        ID = 'user002'
        Groups = @('group3')
        Roles = @{'taskadmin'}
    }

    $permissions = @{
        Read  = @{
            Groups     = @('group1','group2')
            Roles      = @('reviewer','taskadmin')
            Scopes     = @()
            Users      = @('user001')
        }
        Write = @{
            Groups      = @()
            Roles       = @('taskadmin')
            Scopes      = @()
            Users       = @('user001')
        }
    }

    $result = Test-PodeAsyncPermission -Permission $permissions -User $user
    Write-Output $result

.NOTES
    This is an internal function and may change in future releases of Pode.
#>

function Test-PodeAsyncPermission {
    param(
        [hashtable]
        $Permission,
        [hashtable]
        $User
    )
    if ($User) {
        foreach ($key in $Permission.Keys) {

            if ($User.ContainsKey($key)) {
                if (  Test-PodeArraysHaveCommonElement -ReferenceArray $Permission[$key] -DifferenceArray $User[$key]) {
                    return $true
                }
            }
            elseif ($key -eq 'Users') {
                if (Test-PodeArraysHaveCommonElement -ReferenceArray $Permission[$key] -DifferenceArray  $User.ID) {
                    return $true
                }
            }
        }
        return $false
    }
    return $true
}


function Get-PodeAsyncSetScriptBlock {

    return [scriptblock] {
        param($Timeout, $IdGenerator, $AsyncPoolName)
        $responseMediaType = Get-PodeHeader -Name 'Accept'
        if ($IdGenerator) {
            $id = (& $IdGenerator)
        }
        else {
            $id = New-PodeGuid
        }
        # Invoke the internal async task
        $async = Invoke-PodeInternalAsync -Id $id -Task $PodeContext.AsyncRoutes.Items[$AsyncPoolName] -Timeout $Timeout -ArgumentList @{ WebEvent = $WebEvent; ___async___id___ = $id }

        # Prepare the response
        $res = @{
            CreationTime = $async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            Id           = $async['ID']
            State        = $async['State']
            Name         = $async['Name']
            Cancelable   = $async['Cancelable']
        }

        if ($async['User']) {
            $res.User = $async['User']
            # Add default permission
            if (! ($async['Permission'].Read.Users -ccontains $async.User)  ) {
                $async['Permission'].Read.Users += $async.User
            }
            if (! ($async['Permission'].Write.Users -ccontains $async.User)  ) {
                $async['Permission'].Write.Users += $async.User
            }
            $res.Permission = $async['Permission']
        }

        # Send the response based on the requested media type
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $res -StatusCode 200; break }
            'application/json' { Write-PodeJsonResponse -Value $res -StatusCode 200 ; break }
            'appication/yaml' { Write-PodeYamlResponse -Value $res -StatusCode 200 ; break }
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
            $async = $PodeContext.AsyncRoutes.Results[$id]
            if ($async['User']) {
                if ($WebEvent.Auth.User) {
                    $authorized = Test-PodeAsyncPermission -Permission $async['Permission'].Read -User $WebEvent.Auth.User
                }
                else {
                    $authorized = $false
                }
            }
            else {
                $authorized = $true
            }
            if ($authorized) {
                # Create a summary of the task for export
                $export = Export-PodeAsyncInfo -Async $async

                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $export -StatusCode 200; break }
                    'application/json' { Write-PodeJsonResponse -Value $export -StatusCode 200 ; break }
                    'appication/yaml' { Write-PodeYamlResponse -Value $export -StatusCode 200 ; break }
                    default { Write-PodeJsonResponse -Value $export -StatusCode 200 }
                }
                return
            }
            else {
                $errorMsg = @{ID = $id ; Error = 'The User is not entitle to this operation' }
                $statusCode = 401 #'Unauthorized'
            }
        }
        else {
            $errorMsg = @{ID = $id ; Error = 'No Async Route operation Found' }
            $statusCode = 404 #'Not Found'
        }
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode; break }
            'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
            'appication/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
            default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
        }
    }
}

function Get-PodeAsyncStopScriptBlock {
    return [scriptblock] {
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
            $async = $PodeContext.AsyncRoutes.Results[$id]

            # If the task is not completed
            if (!$async['Runspace'].Handler.IsCompleted) {
                # If the task is cancelable
                if ($async['Cancelable']) {

                    if ($async['User'] -and ($null -eq $WebEvent.Auth.User)) {
                        # If the task is not cancelable, set an error message
                        $errorMsg = @{ID = $id ; Error = 'This Async operation required authentication.' }
                        $statusCode = 203 #'Non-Authoritative Information'
                    }
                    else {
                        if ((Test-PodeAsyncPermission -Permission $async['Permission'].Write -User $WebEvent.Auth.User)) {
                            # Set the task state to 'Aborted' and log the error and completion time
                            $async['State'] = 'Aborted'
                            $async['Error'] = 'User Aborted!'
                            $async['CompletedTime'] = [datetime]::UtcNow
                            $async['Runspace'].Pipeline.Dispose()
                            Complete-PodeAsyncScriptFinally -AsyncResult $async

                            # Create a summary of the task
                            $export = Export-PodeAsyncInfo -Async $async

                            # Respond with the task summary in the appropriate format
                            switch ($responseMediaType) {
                                'application/xml' { Write-PodeXmlResponse -Value $export -StatusCode 200; break }
                                'application/json' { Write-PodeJsonResponse -Value $export -StatusCode 200 ; break }
                                'appication/yaml' { Write-PodeYamlResponse -Value $export -StatusCode 200 ; break }
                                default { Write-PodeJsonResponse -Value $export -StatusCode 200 }
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
                'appication/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
            }
        }
    }
}

<#
.SYNOPSIS
    Exports the detailed information of an asynchronous operation to a hashtable.

.DESCRIPTION
    The `Export-PodeAsyncInfo` function extracts and formats information from an asynchronous operation encapsulated in a [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] object. It includes details such as ID, creation time, state, user, permissions, and callback settings, among others. The function returns a hashtable with this information, suitable for logging or further processing.

.PARAMETER Async
    A [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] containing the asynchronous operation's details. This parameter is mandatory.

.EXAMPLE
    $asyncInfo = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
    $exportedInfo = Export-PodeAsyncInfo -Async $asyncInfo

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Export-PodeAsyncInfo {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]
        $Async
    )
    process {
        $export = @{
            ID           = $Async['ID']
            Cancelable   = $Async['Cancelable']
            # ISO 8601 UTC format
            CreationTime = $Async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            Name         = $Async['Name']
            State        = $Async['State']
        }
        if ( $Async.ContainsKey('Permission')) {
            $export.Permission = $Async['Permission']
        }
        if ($Async['StartingTime']) {
            $export.StartingTime = $Async['StartingTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
        }
        if ( $Async['CallbackSettings']) {
            $export.CallbackSettings = $Async['CallbackSettings']
        }
        if ($Async.ContainsKey('User')) {
            $export.User = $Async['User']
        }
        if ($Async.ContainsKey('Permission')) {
            $export.Permission = $Async['Permission']
        }
        if ( $Async['EnableSse']) {
            $export.EnableSse = $Async['EnableSse']
        }
        if ($Async['Runspace'].Handler.IsCompleted) {
            switch ($Async['State'].ToLowerInvariant() ) {
                'failed' {
                    $export.Error = $Async['Error']
                    break
                }
                'completed' {
                    $export.Result = $Async['Result']
                    break
                }
                'aborted' {
                    $export.Error = $Async['Error']
                    break
                }
            }
            if ($Async.ContainsKey('CallbackTentative') -and $Async['CallbackTentative'] -gt 0) {
                $export.CallbackInfo = @{
                    Tentative = $Async['CallbackTentative']
                    State     = $Async['CallbackInfoState']
                    Url       = $Async['CallbackUrl']
                }
            }
            if ($Async.ContainsKey('SeeEventInfoState')) {
                $export.SeeEventInfoState = $Async['SeeEventInfoState']
            }
            if (! $Async.ContainsKey('CompletedTime')) {
                Start-Sleep 1
            }
            if ($Async.ContainsKey('CompletedTime')) {
                # ISO 8601 UTC format
                $export.CompletedTime = $Async['CompletedTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            }
        }
        return $export
    }
}

function Get-PodeAsyncQueryScriptBlock {
    return [scriptblock] {
        param($Payload)
        switch ($Payload) {
            'Body' { $query = $WebEvent.Data }
            'Query' { $query = $WebEvent.Query[$Name] }
            'Header' { $query = $WebEvent.Request.Headers['query'] }
        }
        $responseMediaType = Get-PodeHeader -Name 'Accept'
        $response = @()

        $results = Search-PodeAsyncTask -Query $query -User $WebEvent.Auth.User -CheckPermission

        if ($results) {
            foreach ($async in $results) {
                $response += Export-PodeAsyncInfo -Async $async
            }
        }
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $response -StatusCode 200; break }
            'application/json' { Write-PodeJsonResponse -Value $response -StatusCode 200 ; break }
            'appication/yaml' { Write-PodeYamlResponse -Value $response -StatusCode 200 ; break }
            default { Write-PodeJsonResponse -Value $response -StatusCode 200 }
        }
    }
}
