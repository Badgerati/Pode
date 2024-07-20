
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


.PARAMETER Id
    A custom identifier for the task. If not provided, a new GUID will be generated. This parameter is optional.

.OUTPUTS
    [hashtable] - Returns a hashtable containing details about the asynchronous task, including its Id, runspace,
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

    $result = Invoke-PodeInternalAsync -Task $task -Id 73c6a5b3-2f7d-4b9e-a1ca-e8f87dd9d45

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

        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )
    try {
        # Setup event parameters
        $parameters = @{
            Event = @{
                Lockable = $PodeContext.Threading.Lockables.Global
                Sender   = $Task
                Metadata = @{}
            }
        }

        # Add any task arguments
        foreach ($key in $Task.Arguments.Keys) {
            $parameters[$key] = $Task.Arguments[$key]
        }

        # Add ad-hoc task invoke arguments
        if (($null -ne $ArgumentList) -and ($ArgumentList.Count -gt 0)) {
            foreach ($key in $ArgumentList.Keys) {
                $parameters[$key] = $ArgumentList[$key]
            }
        }

        # Add any using variables
        if ($null -ne $Task.UsingVariables) {
            foreach ($usingVar in $Task.UsingVariables) {
                $parameters[$usingVar.NewName] = $usingVar.Value
            }
        }

        # Set the creation time
        $creationTime = [datetime]::UtcNow

        # Initialize the result and runspace for the async task
        $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
        $runspace = Add-PodeRunspace -Type $Task.Name -ScriptBlock (($Task.Script).GetNewClosure()) -Parameters $parameters -OutputStream $result -PassThru

        # Set the expiration time based on the timeout value
        if ($Task.Timeout -ge 0) {
            $expireTime = [datetime]::UtcNow.AddSeconds($Task.Timeout)
        }
        else {
            $expireTime = [datetime]::MaxValue
        }

        # Initialize the result hashtable
        $dctResult = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $dctResult['Id'] = $Id
        $dctResult['Name'] = $Task.Name
        $dctResult['Runspace'] = $runspace
        $dctResult['Output'] = $result
        $dctResult['StartingTime'] = $null
        $dctResult['CreationTime'] = $creationTime
        $dctResult['CompletedTime'] = $null
        $dctResult['ExpireTime'] = $expireTime
        $dctResult['State'] = 'NotStarted'
        $dctResult['Error'] = $null
        $dctResult['CallbackSettings'] = $Task.CallbackSettings
        $dctResult['Cancelable'] = $Task.Cancelable
        $dctResult['EnableSse'] = $Task.EnableSse
        $dctResult['SseGroup'] = $Task.SseGroup
        $dctResult['Timeout'] = $Task.Timeout

        # Add user information if available
        if ($WebEvent.Auth.User) {
            $dctResult['User'] = $WebEvent.Auth.User.Id
            $dctResult['Permission'] = Copy-PodeDeepClone $Task.Permission
        }

        # Add the request URL and method
        $dctResult['Url'] = $WebEvent.Request.Url
        $dctResult['Method'] = $WebEvent.Method

        # Store the result in the Pode context
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

.OUTPUTS
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
    - It supports additional parameters for WebEvent and Async Id.
    - This is an internal function and may change in future releases of Pode.
#>

function ConvertTo-PodeEnhancedScriptBlock {
    param (
        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock
    )

    # Template for the enhanced script block
    $enhancedScriptBlockTemplate = {
        <# Param #>
        # Sometimes the key is not available when the process starts. Workaround: wait 2 seconds
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

    # Convert the provided script block to a string
    $sc = $ScriptBlock.ToString()

    # Split the string into lines
    $lines = $sc -split "`n"

    # Initialize variables
    $paramLineIndex = $null
    $parameters = ''
    $paramFound = $false
    # Find the line containing 'param' and extract parameters
    for ($i = 0; $i -lt $lines.Length; $i++) {
        # Check for the blocked commands using a single regex
        if ($lines[$i] -match 'Write-Pode.*Response') {
            throw  ($PodeLocale.scriptContainsDisallowedCommandExceptionMessage -f $matches[0].Trim())
        }
        if ((! $paramFound) -and ($lines[$i] -match '^\s*param\((.*)\)\s*$')) {
            $parameters = $matches[1].Trim()
            $paramLineIndex = $i
            $paramFound = $true
        }

    }

    # Remove the line containing 'param'
    if ($null -ne $paramLineIndex) {
        if ($paramLineIndex -eq 0) {
            $remainingLines = $lines[1..($lines.Length - 1)]
        }
        else {
            $remainingLines = $lines[0..($paramLineIndex - 1)] + $lines[($paramLineIndex + 1)..($lines.Length - 1)]
        }

        $remainingString = $remainingLines -join "`n"
        $param = 'param({0}, $WebEvent, $___async___id___)' -f $parameters
    }
    else {
        $remainingString = $sc
        $param = 'param($WebEvent, $___async___id___)'
    }

    # Replace placeholders in the template with actual script block content and parameters
    $enhancedScriptBlockContent = $enhancedScriptBlockTemplate.ToString().Replace('<# ScriptBlock #>', $remainingString.ToString()).Replace('<# Param #>', $param)

    # Return the enhanced script block
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

    # Set the completed time if not already set
    if (! $AsyncResult.ContainsKey('CompletedTime')) {
        $AsyncResult['CompletedTime'] = [datetime]::UtcNow
    }

    # Ensure state is set to 'Completed' if it was still 'Running'
    if ($AsyncResult['State'] -eq 'Running') {
        $AsyncResult['State'] = 'Completed'
    }


    if ($AsyncResult['Timer']) {
        $AsyncResult['Timer'].Stop()
        $AsyncResult['Timer'].Dispose()
        Unregister-Event -SourceIdentifier $asyncResult['eventName']
        $AsyncResult.Remove('Timer')
    }

    # Ensure Progress is set to 100 if in use
    if ($AsyncResult.ContainsKey('Progress')) {
        $AsyncResult['Progress'] = 100
    }

    try {
        if ($AsyncResult['CallbackSettings']) {

            # Resolve the callback URL, method, content type, and headers
            $callbackUrl = (Convert-PodeCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].UrlField).Value
            $method = (Convert-PodeCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].Method -DefaultValue 'Post').Value
            $contentType = (Convert-PodeCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].ContentType).Value
            $headers = @{}
            foreach ($key in $AsyncResult['CallbackSettings'].HeaderFields.Keys) {
                $value = Convert-PodeCallBackRuntimeExpression -Variable $key -DefaultValue $AsyncResult['HeaderFields'][$key]
                if ($value) {
                    $headers[$value.Key] = $value.Value
                }
            }

            # Prepare the body for the callback
            $body = @{
                Url       = $AsyncResult['Url']
                Method    = $AsyncResult['Method']
                EventName = $AsyncResult['CallbackSettings'].EventName
                State     = $AsyncResult['State']
            }
            switch ($AsyncResult['State']) {
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

            # Convert the body to the appropriate content type
            switch ($contentType) {
                'application/json' { $cBody = ($body | ConvertTo-Json -Depth 10) }
                'application/xml' { $cBody = ($body | ConvertTo-Xml -NoTypeInformation) }
                'application/yaml' { $cBody = ($body | ConvertTo-PodeYaml -Depth 10) }
            }

            # Store callback information in the async result
            $AsyncResult['CallbackUrl'] = $callbackUrl
            $AsyncResult['CallbackInfoState'] = 'Running'
            $AsyncResult['CallbackTentative'] = 0

            # Attempt to invoke the callback up to 3 times
            for ($i = 0; $i -le 3; $i++) {
                try {
                    $AsyncResult['CallbackTentative'] = $AsyncResult['CallbackTentative'] + 1
                    $null = Invoke-RestMethod -Uri $callbackUrl -Method $method -Headers $headers -Body $cBody -ContentType $contentType
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
        # Log any errors encountered during the callback process
        $_ | Write-PodeErrorLog
        $AsyncResult['CallbackInfoState'] = 'Failed'
    }

    # Handle Server-Sent Events (SSE) if enabled
    if ($AsyncResult['EnableSse']) {
        try {
            switch ($AsyncResult['State']) {
                'Failed' {
                    Send-PodeSseEvent -FromEvent -Data @{ State = $AsyncResult['State']; Error = $AsyncResult['Error'] }
                }
                'Completed' {
                    if ($AsyncResult['Result']) {
                        Send-PodeSseEvent -FromEvent -Data @{ State = $AsyncResult['State']; Result = $AsyncResult['Result'] }
                    }
                    else {
                        Send-PodeSseEvent -FromEvent -Data @{ State = 'Completed' }
                    }
                }
                'Aborted' {
                    Send-PodeSseEvent -FromEvent -Data @{ State = $AsyncResult['State']; Error = $AsyncResult['Error'] }
                }
            }
            $AsyncResult['SeeEventInfoState'] = 'Completed'
        }
        catch {
            # Log any errors encountered during SSE handling
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

    # Check if the timer already exists
    if (Test-PodeTimer -Name '__pode_asyncroutes_housekeeper__') {
        return
    }

    # Add a new timer with the specified interval and script block
    Add-PodeTimer -Name '__pode_asyncroutes_housekeeper__' -Interval $Interval -ArgumentList $RemoveAfterMinutes -ScriptBlock {
        param ($RemoveAfterMinutes)

        # Return if there are no async route results
        if ($PodeContext.AsyncRoutes.Results.Count -eq 0) {
            return
        }

        $now = [datetime]::UtcNow

        # Iterate over the keys of the async route results
        foreach ($key in $PodeContext.AsyncRoutes.Results.Keys.Clone()) {
            $result = $PodeContext.AsyncRoutes.Results[$key]

            if ($result) {
                # Check if the task is completed
                if ($result['Runspace'].Handler.IsCompleted) {
                    try {
                        # Remove the task if it is past the removal time
                        if ($result['CompletedTime'] -and $result['CompletedTime'].AddMinutes($RemoveAfterMinutes) -lt $now) {
                            $result['Runspace'].Pipeline.Dispose()
                            $v = 0
                            $removed = $PodeContext.AsyncRoutes.Results.TryRemove($key, [ref]$v)
                            Write-Verbose "Key $key Removed: $removed"
                        }
                    }
                    catch {
                        $_ | Write-PodeErrorLog
                    }
                }
                # Check if the task has force expired
                elseif ($result['ExpireTime'] -lt $now) {
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

        # Clear the result variable
        $result = $null
    }
}

<#
.SYNOPSIS
    Adds an OpenAPI component schema for Pode asynchronous tasks.

.DESCRIPTION
    The Add-PodeAsyncComponentSchema function creates an OpenAPI component schema for Pode asynchronous tasks if it does not already exist.
    This schema includes properties such as Id, CreationTime, StartingTime, Result, CompletedTime, State, Error, and Task.

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

    # Test and normalize the definition tag
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag

    # Check if the component schema already exists
    if (!(Test-PodeOAComponent -Field schemas -Name $Name -DefinitionTag $DefinitionTag)) {

        # Define permission content
        $permissionContent = New-PodeOAStringProperty -Name 'Groups' -Array -Example 'group1', 'group2' |
            New-PodeOAStringProperty -Name 'Roles' -Array -Example 'reviewer', 'taskadmin' |
            New-PodeOAStringProperty -Name 'Scopes' -Array -Example 'scope1', 'scope2', 'scope3' |
            New-PodeOAStringProperty -Name 'Users' -Array -Example 'id0001', 'id0005', 'id0231'

        # Create the component schema
        New-PodeOAStringProperty -Name 'Id' -Format Uuid -Description 'The async operation unique identifier.' -Required |
            New-PodeOAStringProperty -Name 'User' -Description 'The async operation owner.' |
            New-PodeOAStringProperty -Name 'CreationTime' -Format Date-Time -Description 'The async operation creation time.' -Example '2024-07-02T20:58:15.2014422Z' -Required |
            New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Description 'The async operation starting time.' -Example '2024-07-02T20:58:15.2014422Z' |
            New-PodeOAStringProperty -Name 'Result' -Example '{result = 7 , numOfIteration = 3 }' |
            New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Description 'The async operation completion time.' -Example '2024-07-02T20:59:23.2174712Z' |
            New-PodeOAStringProperty -Name 'State' -Description 'The async operation status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
            New-PodeOAStringProperty -Name 'Error' -Description 'The error message if any.' |
            New-PodeOAStringProperty -Name 'Name' -Example '__Get_path_endpoint1_' -Description 'The async operation name.' -Required |
            New-PodeOABoolProperty -Name 'Cancelable' -Description 'The async operation can be forcefully terminated' -Required |
            New-PodeOAObjectProperty -Name 'Permission' -Description 'The permission governing the async operation.' -Properties (
                ($permissionContent | New-PodeOAObjectProperty -Name 'Read'),
                ($permissionContent | New-PodeOAObjectProperty -Name 'Write')
            ) |
            New-PodeOAObjectProperty -Name 'CallbackInfo' -Description 'The Callback operation result' -Properties (
                New-PodeOAStringProperty -Name 'State' -Description 'Operation status' -Example 'Completed' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
                    New-PodeOAIntProperty -Name 'Tentative' -Description 'Number of tentatives' |
                    New-PodeOAStringProperty -Name 'Url' -Format Uri -Description 'The callback URL' -Example 'Completed'
                ) |
                New-PodeOAObjectProperty -Name 'CallbackSettings' -Description 'Callback Configuration' -Properties (
                    New-PodeOAStringProperty -Name 'UrlField' -Description 'The URL Field.' -Example '$request.body#/callbackUrl' |
                        New-PodeOABoolProperty -Name 'SendResult' -Description 'Send the result.' |
                        New-PodeOAStringProperty -Name 'Method' -Description 'HTTP Method.' -Enum @('Post', 'Put')
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

        [Parameter()]
        [hashtable]
        $User,

        [switch]
        $CheckPermission
    )

    # Initialize an array to store the matched elements
    $matchedElements = @()

    # Check if there are any async route results to search
    if ($PodeContext.AsyncRoutes.Results.count -gt 0) {
        # Clone the keys of the results to iterate over them
        foreach ($rkey in $PodeContext.AsyncRoutes.Results.keys.Clone()) {
            $result = $PodeContext.AsyncRoutes.Results[$rkey]

            # If permission checking is enabled, validate the user's permissions
            if ($CheckPermission.IsPresent) {
                if ($result.User -and ($null -eq $User)) {
                    continue
                }
                if ($result.Permission -and (! (Test-PodeAsyncPermission -Permission $result.Permission.Read -User $User))) {
                    continue
                }
            }

            $match = $true

            # Iterate through each query condition
            foreach ($key in $Query.Keys) {
                # Check the variable name
                if (! (('Id', 'Name', 'Runspace', 'Output', 'StartingTime', 'CreationTime', 'CompletedTime', 'ExpireTime', 'State', 'Error', 'CallbackSettings', 'Cancelable', 'EnableSse', 'SseGroup', 'Timeout', 'User', 'Url', 'Method', 'Progress') -contains $key)) {
                    # The query provided is invalid.{0} is not a valid element for a query.
                    throw ($PodeLocale.invalidQueryElementExceptionMessage -f $key)
                }
                $queryCondition = $Query[$key]

                # Ensure the query condition has both 'op' and 'value' keys
                if ($queryCondition.ContainsKey('op') -and $queryCondition.ContainsKey('value')) {
                    # Check if the result contains the key and it is not null
                    if ($result.ContainsKey($key) -and ($null -ne $result[$key])) {

                        $operator = $queryCondition['op']
                        $value = $queryCondition['value']

                        # Evaluate the condition based on the specified operator
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

            # If the result matches all conditions, add it to the matched elements
            if ($match) {
                $matchedElements += $result
            }
        }
    }

    # Return the array of matched elements
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
    param(
        [string]$Variable,
        [string]$DefaultValue
    )

    # Check if the variable starts with '$request.header'
    if ($Variable.StartsWith('$request.header')) {
        # Match the header key
        if ($Variable -match '^[^.]*\.[^.]*\.(.*)') {
            $Value = $WebEvent.Request.Headers[$Matches[1]]
            if ($Value) {
                return @{Key = $Matches[1]; Value = $Value }
            }
            else {
                return @{Key = $Matches[1]; Value = $DefaultValue }
            }
        }
    }
    # Check if the variable starts with '$request.query'
    elseif ($Variable.StartsWith('$request.query')) {
        # Match the query parameter key
        if ($Variable -match '^[^.]*\.[^.]*\.(.*)') {
            $Value = $WebEvent.Query[$Matches[1]]
            if ($Value) {
                return @{Key = $Matches[1]; Value = $Value }
            }
            else {
                return @{Key = $Matches[1]; Value = $DefaultValue }
            }
        }
    }
    # Check if the variable starts with '$request.body'
    elseif ($Variable.StartsWith('$request.body')) {
        # Match the body data key
        if ($Variable -match '^[^.]*\.[^.]*#/(.*)') {
            $Value = $WebEvent.data.$($Matches[1])
            if ($Value) {
                return @{Key = $Matches[1]; Value = $Value }
            }
            else {
                return @{Key = $Matches[1]; Value = $DefaultValue }
            }
        }
    }

    # Return the default value if no match was found and default value is not null or empty
    if (![string]::IsNullOrEmpty($DefaultValue)) {
        return @{Key = $Variable; Value = $DefaultValue }
    }

    # Return the variable itself as the value if no match was found and no default value is provided
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
        Id = 'user002'
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
    # If the user information is provided
    if ($User) {
        # Iterate through each key in the Permission hashtable
        foreach ($key in $Permission.Keys) {

            # Check if the user's attributes contain the current permission key
            if ($User.ContainsKey($key)) {
                # Check if there is a common element between the user's attributes and the required permissions
                if (Test-PodeArraysHaveCommonElement -ReferenceArray $Permission[$key] -DifferenceArray $User[$key]) {
                    return $true
                }
            }
            # Special case for 'Users' key, checking if the user's Id is in the permission list
            elseif ($key -eq 'Users') {
                if (Test-PodeArraysHaveCommonElement -ReferenceArray $Permission[$key] -DifferenceArray $User.Id) {
                    return $true
                }
            }
        }
        # Return false if no common elements are found for any permission key
        return $false
    }
    # If no user information is provided, assume permission is granted
    return $true
}


<#
.SYNOPSIS
    Retrieves a script block for handling asynchronous route operations in Pode.

.DESCRIPTION
    This function returns a script block designed to handle asynchronous route operations in a Pode web server.
    It generates an Id for the async task, invokes the internal async task, and prepares the response based on the Accept header.
    The response includes details such as creation time, Id, state, name, and cancelable status. If the task involves a user,
    it adds default read and write permissions for the user.

.PARAMETER Timeout
    The timeout value for the asynchronous task.

.PARAMETER IdGenerator
    A script block that generates a custom Id for the asynchronous task. If not provided, a new GUID is generated.

.PARAMETER AsyncPoolName
    The name of the async pool containing the task to be invoked.

.EXAMPLE
    $scriptBlock = Get-PodeAsyncSetScriptBlock
    # Use the returned script block in an async route in Pode

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeAsyncSetScriptBlock {
    # This function returns a script block that handles async route operations
    return [scriptblock] {
        param( $IdGenerator, $AsyncPoolName)

        # Get the 'Accept' header from the request to determine the response format
        $responseMediaType = Get-PodeHeader -Name 'Accept'

        # Generate an Id for the async task, using the provided IdGenerator or a new GUID
        if ($IdGenerator) {
            $id = (& $IdGenerator)
        }
        else {
            $id = New-PodeGuid
        }

        # Invoke the internal async task
        $async = Invoke-PodeInternalAsync -Id $id -Task $PodeContext.AsyncRoutes.Items[$AsyncPoolName] -ArgumentList @{ WebEvent = $WebEvent; ___async___id___ = $id }

        # Prepare the response
        $res = @{
            CreationTime = $async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')  # Format creation time in ISO 8601 UTC format
            Id           = $async['Id']                                                    # Task Id
            State        = $async['State']                                                 # Task state
            Name         = $async['Name']                                                  # Task name
            Cancelable   = $async['Cancelable']                                            # Task cancelable status
        }

        # If the task involves a user, include user information and add default permissions
        if ($async['User']) {
            $res.User = $async['User']
            # Add default read permission for the user if not already present
            if (! ($async['Permission'].Read.Users -ccontains $async.User)) {
                $async['Permission'].Read.Users += $async.User
            }
            # Add default write permission for the user if not already present
            if (! ($async['Permission'].Write.Users -ccontains $async.User)) {
                $async['Permission'].Write.Users += $async.User
            }
            $res.Permission = $async['Permission']
        }

        # Send the response based on the requested media type
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $res -StatusCode 200; break }
            'application/json' { Write-PodeJsonResponse -Value $res -StatusCode 200 ; break }
            'application/yaml' { Write-PodeYamlResponse -Value $res -StatusCode 200 ; break }
            default { Write-PodeJsonResponse -Value $res -StatusCode 200 }
        }
    }
}

<#
.SYNOPSIS
    Retrieves a script block for handling asynchronous GET requests in Pode.

.DESCRIPTION
    This function returns a script block designed to process asynchronous GET requests in a Pode web server.
    The script block checks for task identifiers in different parts of the request (cookies, headers, path parameters, query parameters)
    and retrieves the corresponding async route result. It handles authorization, formats the response based on the Accept header,
    and returns the appropriate response.

    PARAMETER In
        The source of the task identifier, such as 'Cookie', 'Header', 'Path', or 'Query'.

    PARAMETER TaskIdName
        The name of the task identifier to be retrieved from the specified source.

.EXAMPLE
    $scriptBlock = Get-PodeAsyncGetScriptBlock
    # Use the returned script block in an async GET route in Pode

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeAsyncGetScriptBlock {
    # This function returns a script block that handles async route operations
    return [scriptblock] {
        param($In, $TaskIdName)

        # Determine which type of input we have (Cookie, Header, Path or Query)
        switch ($In) {
            'Cookie' { $id = Get-PodeCookie -Name $TaskIdName; break }
            'Header' { $id = Get-PodeHeader -Name $TaskIdName; break }
            'Path' { $id = $WebEvent.Parameters[$TaskIdName]; break }
            'Query' { $id = $WebEvent.Query[$TaskIdName]; break }
        }

        # Get the Accept header to determine the response format
        $responseMediaType = Get-PodeHeader -Name 'Accept'

        # Check if we have a result for this async route operation
        if ($PodeContext.AsyncRoutes.Results.ContainsKey($id)) {
            $async = $PodeContext.AsyncRoutes.Results[$id]
            # Check if the user is authorized to perform this operation
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

            # If authorized, export the task info and return a response
            if ($authorized) {
                # Create a summary of the task for export
                $export = Export-PodeAsyncInfo -Async $async

                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $export -StatusCode 200; break }
                    'application/json' { Write-PodeJsonResponse -Value $export -StatusCode 200 ; break }
                    'application/yaml' { Write-PodeYamlResponse -Value $export -StatusCode 200 ; break }
                    default { Write-PodeJsonResponse -Value $export -StatusCode 200 }
                }
                return
            }
            else {
                # If not authorized, return an error response
                $errorMsg = @{Id = $id ; Error = 'The User is not entitle to this operation' }
                $statusCode = 401 #'Unauthorized'
            }
        }
        else {
            # If no async route operation is found, return a not found error response
            $errorMsg = @{Id = $id ; Error = 'No Async Route operation Found' }
            $statusCode = 404 #'Not Found'
        }
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode; break }
            'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
            'application/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
            default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
        }
    }
}


<#
.SYNOPSIS
    Retrieves a script block for handling the stopping of asynchronous tasks in Pode.

.DESCRIPTION
    This function returns a script block designed to stop asynchronous tasks in a Pode web server.
    The script block checks for task identifiers in different parts of the request (cookies, headers, path parameters, query parameters)
    and retrieves the corresponding async route result. It handles authorization, cancels the task if it is cancelable and not completed,
    and formats the response based on the Accept header.

    PARAMETER In
        The source of the task identifier, such as 'Cookie', 'Header', 'Path', or 'Query'.

    PARAMETER TaskIdName
        The name of the task identifier to be retrieved from the specified source.

.EXAMPLE
    $scriptBlock = Get-PodeAsyncStopScriptBlock
    # Use the returned script block in an async stop route in Pode

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeAsyncStopScriptBlock {
    # This function returns a script block that handles async route operations
    return [scriptblock] {
        param($In, $TaskIdName)

        # Determine the source of the task Id based on the input parameter
        switch ($In) {
            'Cookie' { $id = Get-PodeCookie -Name $TaskIdName; break }
            'Header' { $id = Get-PodeHeader -Name $TaskIdName; break }
            'Path' { $id = $WebEvent.Parameters[$TaskIdName]; break }
            'Query' { $id = $WebEvent.Query[$TaskIdName]; break }
        }

        # Get the 'Accept' header from the request to determine response format
        $responseMediaType = Get-PodeHeader -Name 'Accept'

        # Check if the task Id exists in the async routes results
        if ($PodeContext.AsyncRoutes.Results.ContainsKey($id)) {
            $async = $PodeContext.AsyncRoutes.Results[$id]

            # If the task is not completed
            if (!$async['Runspace'].Handler.IsCompleted) {
                # If the task is cancelable
                if ($async['Cancelable']) {

                    if ($async['User'] -and ($null -eq $WebEvent.Auth.User)) {
                        # If the task is not cancelable, set an error message
                        $errorMsg = @{Id = $id ; Error = 'This Async operation required authentication.' }
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
                                'application/yaml' { Write-PodeYamlResponse -Value $export -StatusCode 200 ; break }
                                default { Write-PodeJsonResponse -Value $export -StatusCode 200 }
                            }
                            return
                        }
                        else {
                            $errorMsg = @{Id = $id ; Error = 'The User is not entitle to this operation' }
                            $statusCode = 401 #'Unauthorized'
                        }
                    }
                }
                else {
                    # If the task is not cancelable, set an error message
                    $errorMsg = @{Id = $id ; Error = "The task has the 'NonCancelable' flag." }
                    $statusCode = 423 #'Locked
                }
            }
            else {
                # If the task is already completed, set an error message
                $errorMsg = @{Id = $id ; Error = 'The Task is already completed.' }
                $statusCode = 410 #'Gone'
            }
        }
        else {
            # If no task is found, set an error message
            $errorMsg = @{Id = $id ; Error = 'No Task Found.' }
            $statusCode = 404 #'Not Found'
        }

        # Respond with the error message in the appropriate format
        if ($errorMsg) {
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
                'application/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
            }
        }
    }
}

<#
.SYNOPSIS
    Exports the detailed information of an asynchronous operation to a hashtable.

.DESCRIPTION
    The `Export-PodeAsyncInfo` function extracts and formats information from an asynchronous operation encapsulated in a [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] object. It includes details such as Id, creation time, state, user, permissions, and callback settings, among others. The function returns a hashtable with this information, suitable for logging or further processing.

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
        # Initialize a hashtable to store the exported information
        $export = @{
            Id           = $Async['Id']
            Cancelable   = $Async['Cancelable']
            # Format creation time in ISO 8601 UTC format
            CreationTime = $Async['CreationTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            Name         = $Async['Name']
            State        = $Async['State']
        }

        # Include permission if it exists
        if ($Async.ContainsKey('Permission')) {
            $export.Permission = $Async['Permission']
        }

        # Include starting time if it exists
        if ($Async['StartingTime']) {
            $export.StartingTime = $Async['StartingTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
        }

        # Include callback settings if they exist
        if ($Async['CallbackSettings']) {
            $export.CallbackSettings = $Async['CallbackSettings']
        }

        # Include user if it exists
        if ($Async.ContainsKey('User')) {
            $export.User = $Async['User']
        }

        # Include permission if it exists (redundant check)
        if ($Async.ContainsKey('Permission')) {
            $export.Permission = $Async['Permission']
        }

        # Include SSE setting if it exists
        if ($Async['EnableSse']) {
            $export.EnableSse = $Async['EnableSse']
        }

        # Include Progress setting if it exists
        if ($Async.ContainsKey('Progress')) {
            $export.Progress = [math]::Round($Async['Progress'], 2)
        }

        # If the task is completed, include the result or error based on the state
        if ($Async['Runspace'].Handler.IsCompleted) {
            switch ($Async['State'] ) {
                'Failed' {
                    $export.Error = $Async['Error']
                    break
                }
                'Completed' {
                    if ($Async['Result']) {
                        $export.Result = $Async['Result']
                    }
                    break
                }
                'Aborted' {
                    $export.Error = $Async['Error']
                    break
                }
            }

            # Include callback information if it exists
            if ($Async.ContainsKey('CallbackTentative') -and $Async['CallbackTentative'] -gt 0) {
                $export.CallbackInfo = @{
                    Tentative = $Async['CallbackTentative']
                    State     = $Async['CallbackInfoState']
                    Url       = $Async['CallbackUrl']
                }
            }

            # Include SSE event info state if it exists
            if ($Async.ContainsKey('SeeEventInfoState')) {
                $export.SeeEventInfoState = $Async['SeeEventInfoState']
            }

            # Ensure completed time is set, retrying after a short delay if necessary
            if (-not $Async.ContainsKey('CompletedTime')) {
                Start-Sleep 1
            }
            if ($Async.ContainsKey('CompletedTime')) {
                # Format completed time in ISO 8601 UTC format
                $export.CompletedTime = $Async['CompletedTime'].ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
            }
        }

        # Return the exported information
        return $export
    }
}

<#
.SYNOPSIS
    Retrieves a script block for querying asynchronous tasks in Pode.

.DESCRIPTION
    This function returns a script block designed to query asynchronous tasks in a Pode web server.
    The script block processes the query from different parts of the request (body, query parameters, headers),
    searches for async tasks based on the query, checks permissions, and formats the response based on the Accept header.

.PARAMETER Payload
    The source of the query, such as 'Body', 'Query', or 'Header'.

.EXAMPLE
    $scriptBlock = Get-PodeAsyncQueryScriptBlock
    # Use the returned script block in an async query route in Pode

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeAsyncQueryScriptBlock {
    return [scriptblock] {
        param($Payload)

        # Determine the source of the query based on the payload parameter
        switch ($Payload) {
            'Body' { $query = $WebEvent.Data }                          # Retrieve the query from the body
            'Query' { $query = $WebEvent.Query[$Name] }                 # Retrieve the query from query parameters
            'Header' { $query = $WebEvent.Request.Headers['query'] }    # Retrieve the query from headers
        }

        # Get the 'Accept' header from the request to determine the response format
        $responseMediaType = Get-PodeHeader -Name 'Accept'
        $response = @()  # Initialize an empty array to hold the response
        try {
            # Search for async tasks based on the query and user, checking permissions
            $results = Search-PodeAsyncTask -Query $query -User $WebEvent.Auth.User -CheckPermission

            # If results are found, export async task information for each result
            if ($results) {
                foreach ($async in $results) {
                    $response += Export-PodeAsyncInfo -Async $async
                }
            }

            # Respond with the results in the appropriate format
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $response -StatusCode 200; break }
                'application/json' { Write-PodeJsonResponse -Value $response -StatusCode 200 ; break }
                'application/yaml' { Write-PodeYamlResponse -Value $response -StatusCode 200 ; break }
                default { Write-PodeJsonResponse -Value $response -StatusCode 200 }
            }
        }
        catch {
            $response = @{'Error' = $_.tostring() }
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $response -StatusCode 402; break }
                'application/json' { Write-PodeJsonResponse -Value $response -StatusCode 402 ; break }
                'application/yaml' { Write-PodeYamlResponse -Value $response -StatusCode 402 ; break }
                default { Write-PodeJsonResponse -Value $response -StatusCode 402 }
            }
        }
    }
}

