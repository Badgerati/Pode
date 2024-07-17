
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
        CallbackInfo = $null
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
        $dctResult['CallbackInfo'] = $Task.CallbackInfo
        $dctResult['Cancelable'] = $Task.Cancelable
        if ($WebEvent.Auth.User) {
            $dctResult['User'] = $WebEvent.Auth.User.ID
            $dctResult['Permission'] = Copy-PodeDeepClone $Task.Permission
        }
        $dctResult['EnableSse'] = $Task.EnableSse
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
        [ScriptBlock]$ScriptBlock
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

                if ($asyncResult.EnableSse) {
                    if ($asyncResult.SseGroup) {
                        ConvertTo-PodeSseConnection -Name $___async___id___ -Scope Local -Group $asyncResult.SseGroup
                    }
                    else {
                        ConvertTo-PodeSseConnection -Name $___async___id___ -Scope Local
                    }
                }

                $___result___ = & { # Original ScriptBlock Start
                    <# ScriptBlock #>
                    # Original ScriptBlock End
                }
                # return $___result___
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
                # Set the completed time
                if (! $asyncResult.ContainsKey('CompletedTime')) {
                    $asyncResult['CompletedTime'] = [datetime]::UtcNow
                }

                # Ensure state is set to 'Completed' if it was still 'Running'
                if ($asyncResult.State -eq 'Running') {
                    $asyncResult['State'] = 'Completed'
                }

                if ($___result___) {
                    $asyncResult['Result'] = $___result___
                }

                try {
                    if ($asyncResult.CallbackInfo) {

                        $asyncResult['CallbackTentative'] = 0

                        $callbackUrl = (Convert-PodeCallBackRuntimeExpression -Variable $asyncResult['CallbackInfo'].UrlField).Value
                        $method = (Convert-PodeCallBackRuntimeExpression -Variable $asyncResult['CallbackInfo'].Method -DefaultValue 'Post').Value
                        $contentType = (Convert-PodeCallBackRuntimeExpression -Variable $asyncResult['CallbackInfo'].ContentType).Value
                        $headers = @{}
                        foreach ($key in $asyncResult['CallbackInfo'].HeaderFields.Keys) {
                            $value = Convert-PodeCallBackRuntimeExpression -Variable $key -DefaultValue $asyncResult.HeaderFields[$key]
                            if ($value) {
                                $headers.$($value.key) = $value.value
                            }
                        }
                        $body = @{
                            Url       = $WebEvent.Request.Url
                            Method    = $WebEvent.Method
                            EventName = $asyncResult['CallbackInfo'].EventName
                            State     = $asyncResult['State']
                        }
                        switch ( $asyncResult['State'] ) {
                            'Failed' {
                                $body.Error = $asyncResult['Error']
                            }
                            'Completed' {
                                if ($asyncResult['CallbackInfo'].SendResult -and $___result___) {
                                    $body.Result = $___result___
                                }
                            }
                        }

                        switch ($contentType) {
                            'application/json' { $cBody = ($body | ConvertTo-Json -depth 10) }
                            'application/xml' { $cBody = ($body | ConvertTo-Xml -NoTypeInformation ) }
                            'application/yaml' { $cBody = ($body | ConvertTo-PodeYaml -depth 10) }
                        }

                        $asyncResult['callbackUrl'] = $callbackUrl
                        for ($i = 0; $i -le 3; $i++) {
                            try {
                                $asyncResult['CallbackTentative'] = $asyncResult['CallbackTentative'] + 1
                                $null = Invoke-RestMethod -Uri ($callbackUrl) -Method $method -Headers $headers -Body $cBody -ContentType $contentType
                                $asyncResult['CallbackInfoState'] = 'Completed'
                                break
                            }
                            catch {
                                $_ | Write-PodeErrorLog
                                $asyncResult['CallbackInfoState'] = 'Failed'
                            }
                        }
                    }
                }
                catch {
                    # Log the error
                    $_ | Write-PodeErrorLog
                    $asyncResult['CallbackInfoState'] = 'Failed'
                }

                if ($asyncResult.EnableSse) {
                    switch ( $asyncResult['State'] ) {
                        'Failed' {
                            Send-PodeSseEvent -FromEvent -Data @{State = 'Failed'; Error = $asyncResult['Error'] }
                        }
                        'Completed' {
                            if ($___result___) {
                                Send-PodeSseEvent -FromEvent -Data @{State = 'Completed'; Result = $___result___ }
                            }
                            else {
                                Send-PodeSseEvent -FromEvent -Data @{State = 'Completed' }
                            }
                        }
                        Default {}
                    }
                }
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

    [ScriptBlock]::Create($enhancedScriptBlockContent)
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
        Write-PodeHost "RemoveAfterMinutes=$RemoveAfterMinutes"
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
                    }
                    catch {
                        $_ | Write-PodeErrorLog
                    }
                    #   Close-PodeAsyncRoutesInternal -Result $result

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
            New-PodeOAStringProperty -Name 'CallbackInfoState' -Description 'The Callback operation status' -Example 'Completed' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
            New-PodeOAIntProperty -Name 'CallbackTentative' -Description 'The Callback tentative number' |
            New-PodeOAObjectProperty -Name 'CallbackInfo' -Description 'Callback information' -Properties (
                New-PodeOAStringProperty -Name 'UrlField' -Description 'The URL Field.'  -Example  '$request.body#/callbackUrl'
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
            $async = $PodeContext.AsyncRoutes.Results[$id]
            <#            if ($async['User']) {
                $authorized = Test-PodeAsyncPermission -Permission $async['Permission'].Read -User $WebEvent.Auth.User
            }
            else {
                $authorized = $true
            }
            if ($authorized) {
                $taskSummary = Get-PodeAsyncSummary -Async $async
#>
            $taskSummary = @{
                ID           = $async['ID']
                Cancelable   = $async['Cancelable']
                # ISO 8601 UTC format
                CreationTime = $async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                Name         = $async['Name']
                State        = $async['State']
            }
            if ( $async['Permission']) {
                $taskSummary.Permission = $async['Permission']
            }
            if ($async['StartingTime']) {
                $taskSummary.StartingTime = $async['StartingTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            }
            if ($async['CallbackInfo']) {
                $taskSummary.CallbackInfo = $async['CallbackInfo']
            }
            if ($async['User']) {
                if ($WebEvent.Auth.User) {
                    $taskSummary.User = $async['User']
                    $taskSummary.Permission = $async['Permission']
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
                if ($async['Runspace'].Handler.IsCompleted) {
                    switch ($async['State'].ToLowerInvariant() ) {
                        'failed' {
                            $taskSummary.Error = $async['Error']
                            if ($async['CallbackInfoState']) {
                                $taskSummary.CallbackTentative = $async['CallbackTentative']
                                $taskSummary.CallbackInfoState = $async['CallbackInfoState']
                                $taskSummary.CallbackUrl = $async['CallbackUrl']
                            }
                            break
                        }
                        'completed' {
                            $taskSummary.Result = $async['Result']
                            if ($async['CallbackInfoState']) {
                                $taskSummary.CallbackTentative = $async['CallbackTentative']
                                $taskSummary.CallbackInfoState = $async['CallbackInfoState']
                                $taskSummary.CallbackUrl = $async['CallbackUrl']
                            }
                            break
                        }
                        'aborted' {
                            $taskSummary.Error = $async['Error']
                            break
                        }
                    }
                    if (! $taskSummary.ContainsKey('CompletedTime')) {
                        Start-Sleep 1
                    }
                    # ISO 8601 UTC format
                    $taskSummary.CompletedTime = $async['CompletedTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
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

                            # Create a summary of the task
                            $taskSummary = @{
                                ID            = $id
                                CreationTime  = $async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                                Name          = $async['Name']
                                State         = $async['State']
                                CompletedTime = $async['CompletedTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                                Error         = $async['Error']
                                Cancelable    = $async['Cancelable']
                            }
                            if ( $async['Permission']) {
                                $taskSummary.Permission = $async['Permission']
                            }
                            if ($async['CallbackInfo']) {
                                $taskSummary.CallbackInfo = $async['CallbackInfo']
                            }
                            if ($async['User']) {
                                $taskSummary.User = $async['User']
                            }
                            # Include the starting time if available
                            if ($async['StartingTime']) {
                                $taskSummary.StartingTime = $async['StartingTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                            }

                            # Close any open resources associated with the task
                            Close-PodeDisposable -Disposable $async['Runspace'].Pipeline
                            Close-PodeDisposable -Disposable $async['Result']

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
    return [scriptblock] {
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
            foreach ($async in $results) {
                #    $response += Get-PodeAsyncSummary -Async $async
                $taskSummary = @{
                    ID           = $async['ID']
                    Cancelable   = $async['Cancelable']
                    # ISO 8601 UTC format
                    CreationTime = $async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    Name         = $async['Name']
                    State        = $async['State']
                }
                if ( $async['Permission']) {
                    $taskSummary.Permission = $async['Permission']
                }
                if ($async['StartingTime']) {
                    $taskSummary.StartingTime = $async['StartingTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                }
                if ($async['CallbackInfo']) {
                    $taskSummary.CallbackInfo = $async['CallbackInfo']
                }
                if ($async['User']) {
                    $taskSummary.User = $async['User']
                    $taskSummary.Permission = $async['Permission']
                }

                if ($async['Runspace'].Handler.IsCompleted) {
                    switch ($async['State'].ToLowerInvariant() ) {
                        'failed' {
                            $taskSummary.Error = $async['Error']
                            if ($async['CallbackInfoState']) {
                                $taskSummary.CallbackTentative = $async['CallbackTentative']
                                $taskSummary.CallbackInfoState = $async['CallbackInfoState']
                                $taskSummary.CallbackUrl = $async['CallbackUrl']
                            }
                            break
                        }
                        'completed' {
                            $taskSummary.Result = $async['Result']
                            if ($async['CallbackInfoState']) {
                                $taskSummary.CallbackTentative = $async['CallbackTentative']
                                $taskSummary.CallbackInfoState = $async['CallbackInfoState']
                                $taskSummary.CallbackUrl = $async['CallbackUrl']
                            }
                            break
                        }
                        'aborted' {
                            $taskSummary.Error = $async['Error']
                            break
                        }
                    }
                    if ($async['CompletedTime']) {
                        # ISO 8601 UTC format
                        $taskSummary.CompletedTime = $async['CompletedTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
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



function Get-PodeAsyncSummary {
    param(
        $Async
    )
    $asyncSummary = @{
        ID           = $Async['ID']
        Cancelable   = $Async['Cancelable']
        # ISO 8601 UTC format
        CreationTime = $Async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
        Name         = $Async['Name']
        State        = $Async['State']
    }
    if ( $Async['Permission']) {
        $asyncSummary.Permission = $Async['Permission']
    }
    if ($Async['StartingTime']) {
        $asyncSummary.StartingTime = $Async['StartingTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    }
    if ($Async['CallbackInfo']) {
        $asyncSummary.CallbackInfo = $Async['CallbackInfo']
    }
    if ($Async['User']) {
        $asyncSummary.User = $Async['User']
        $asyncSummary.Permission = $Async['Permission']
    }

    if ($Async['Runspace'].Handler.IsCompleted) {
        switch ($Async['State'].ToLowerInvariant() ) {
            'failed' {
                $asyncSummary.Error = $Async['Error']
                if ($Async['CallbackInfoState']) {
                    $asyncSummary.CallbackTentative = $Async['CallbackTentative']
                    $asyncSummary.CallbackInfoState = $Async['CallbackInfoState']
                    $asyncSummary.CallbackUrl = $Async['CallbackUrl']
                }
                break
            }
            'completed' {
                $asyncSummary.Result = $Async['Result']
                if ($Async['CallbackInfoState']) {
                    $asyncSummary.CallbackTentative = $Async['CallbackTentative']
                    $asyncSummary.CallbackInfoState = $Async['CallbackInfoState']
                    $asyncSummary.CallbackUrl = $Async['CallbackUrl']
                }
                break
            }
            'aborted' {
                $asyncSummary.Error = $Async['Error']
                break
            }
        }
        # ISO 8601 UTC format
        $asyncSummary.CompletedTime = $Async['CompletedTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
    }
}