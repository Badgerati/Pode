
<#
.SYNOPSIS
    Converts a provided script block into an enhanced script block for asynchronous execution in Pode.

.DESCRIPTION
    The `Get-PodeAsyncRouteScriptblock` function takes a given script block and wraps it with additional code
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

    $enhancedScriptBlock = Get-PodeAsyncRouteScriptblock -ScriptBlock $originalScriptBlock

    # Now you can use $enhancedScriptBlock for asynchronous execution in Pode.

.NOTES
    - The enhanced script block manages state transitions, error logging, and optional callback invocations.
    - It supports additional parameters for WebEvent and Async Id.
    - This is an internal function and may change in future releases of Pode.
#>

function Get-PodeAsyncRouteScriptblock {
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
        if (!$PodeContext.AsyncRoutes.Results.ContainsKey($___async___id___)) {
            try {
                throw ($PodeLocale.asyncIdDoesNotExistExceptionMessage -f $___async___id___)
            }
            catch {
                # Log the error
                $_ | Write-PodeErrorLog
            }
        }

        $asyncResult = $PodeContext.AsyncRoutes.Results[$___async___id___]
            ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = "$($asyncResult.Name)_$___async___id___"
        try {
            $asyncResult['StartingTime'] = [datetime]::UtcNow

            # Set the state to 'Running'
            $asyncResult['State'] = 'Running'

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
            Complete-PodeAsyncRouteOperation -AsyncResult $asyncResult
        }

    }

    # Convert the provided script block to a string
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
    if ($null -ne $paramLineIndex) {
        if ($paramLineIndex -eq 0) {
            $remainingLines = $lines[1..($lines.Length - 1)]
        }
        else {
            # include comments or empty lines
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
    Validates a ScriptBlock to ensure it does not contain disallowed Pode response commands.

.DESCRIPTION
    The Test-PodeAsyncRouteScriptblockInvalidCommand function checks a given ScriptBlock
    to ensure that it does not contain any disallowed Pode response commands, such as
    'Write-Pode...Response'. If such a command is found, the function throws an exception
    with a relevant error message.

.PARAMETER ScriptBlock
    The ScriptBlock that you want to validate. This parameter is mandatory.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeAsyncRouteScriptblockInvalidCommand {
    param(
        [Parameter(Mandatory = $true)]
        [ScriptBlock]
        $ScriptBlock
    )

    # Convert the ScriptBlock to a string and check if it contains disallowed commands
    if ($ScriptBlock.ToString() -imatch 'Write\-Pode.+Response') {
        # If a disallowed command is found, throw an exception with a relevant message
        throw ($PodeLocale.scriptContainsDisallowedCommandExceptionMessage -f $Matches[0].Trim())
    }
}
<#
.SYNOPSIS
    Closes an asynchronous script execution, setting its state to 'Completed' and handling callback invocations.

.DESCRIPTION
    The `Complete-PodeAsyncRouteOperation` function finalizes an asynchronous script's execution by setting its state to 'Completed' if it is still running and logs the completion time. It also manages callbacks by sending requests to a specified callback URL with appropriate headers and content types. If Server-Sent Events (SSE) are enabled, the function will send events based on the execution state.

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
    Complete-PodeAsyncRouteOperation -AsyncResult $asyncResult -WebEvent $webEvent

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Complete-PodeAsyncRouteOperation {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]
        $AsyncResult
    )
    # Set the completed time if not already set
    if (! $AsyncResult.ContainsKey('CompletedTime') -or ($null -eq $AsyncResult['CompletedTime'])) {
        $AsyncResult['CompletedTime'] = [datetime]::UtcNow
    }

    # Ensure state is set to 'Completed' if it was still 'Running'
    if ($AsyncResult['State'] -eq 'Running') {
        $AsyncResult['State'] = 'Completed'
    }


    if ($AsyncResult['Timer']) {
        # Closes and disposes of the timer
        Close-PodeAsyncRouteTimer -Operation $AsyncResult
    }

    # Ensure Progress is set to 100 if in use
    if ($AsyncResult.ContainsKey('Progress')) {
        $AsyncResult['Progress'] = 100
    }

    try {
        if ($AsyncResult['CallbackSettings']) {

            # Resolve the callback URL, method, content type, and headers
            $callbackUrl = (Convert-PodeAsyncRouteCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].UrlField).Value
            $method = (Convert-PodeAsyncRouteCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].Method -DefaultValue 'Post').Value
            $contentType = (Convert-PodeAsyncRouteCallBackRuntimeExpression -Variable $AsyncResult['CallbackSettings'].ContentType).Value
            $headers = @{}
            foreach ($key in $AsyncResult['CallbackSettings'].HeaderFields.Keys) {
                $value = Convert-PodeAsyncRouteCallBackRuntimeExpression -Variable $key -DefaultValue $AsyncResult['HeaderFields'][$key]
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
                    $null = Invoke-RestMethod -Uri $callbackUrl -Method $method -Headers $headers -Body $cBody -ContentType $contentType -ErrorAction Stop
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

}


<#
.SYNOPSIS
    Starts the housekeeper for Pode asynchronous routes.

.DESCRIPTION
    The `Start-PodeAsyncRoutesHousekeeper` function sets up a timer that periodically cleans up expired or completed asynchronous routes
    in Pode. It ensures that any expired or completed routes are properly handled and removed from the context.

.NOTES
    - The timer is named '__pode_asyncroutes_housekeeper__' and runs at an HousekeepingInterval of 30 seconds.
    - The timer checks for forced expiry, completion, and completion expiry of asynchronous routes.

    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeAsyncRoutesHousekeeper {

    # Check if the timer already exists
    if (Test-PodeTimer -Name '__pode_asyncroutes_housekeeper__') {
        return
    }

    # Add a new timer with the specified $Context.Server.AsyncRoute.TimerInterval and script block
    Add-PodeTimer -Name '__pode_asyncroutes_housekeeper__' -Interval  $PodeContext.AsyncRoutes.HouseKeeping.TimerInterval  -ScriptBlock {
        ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace).Name = '__pode_asyncroutes_housekeeper__'
        # Return if there are no async route results
        if ($PodeContext.AsyncRoutes.Results.Count -eq 0) {
            return
        }

        $now = [datetime]::UtcNow
        $RetentionMinutes = $PodeContext.AsyncRoutes.HouseKeeping.RetentionMinutes
        # Iterate over the keys of the async route results
        foreach ($key in $PodeContext.AsyncRoutes.Results.Keys.Clone()) {
            $result = $PodeContext.AsyncRoutes.Results[$key]

            if ($result) {
                # Check if the task is completed
                if ($result['Runspace'].Handler.IsCompleted) {
                    try {
                        # Remove the task if it is past the removal time
                        if ($result['CompletedTime'] -and $result['CompletedTime'].AddMinutes($RetentionMinutes) -le $now) {
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
                        Complete-PodeAsyncRouteOperation -AsyncResult $result
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
    Searches for asynchronous route Pode tasks based on specified query conditions.

.DESCRIPTION
    The Search-PodeAsyncRouteTask function searches the Pode context for asynchronous route tasks that match the specified query conditions.
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
    $results = Search-PodeAsyncRouteTask -Query $query

    This example searches for tasks that are in the 'Running' state and were created within the last hour.

.EXAMPLE
    $user = @{
        'Name' = 'AdminUser'
        'Roles' = @('Admin', 'User')
    }
    $query = @{
        'State' = @{ 'op' = 'EQ'; 'value' = 'Completed' }
    }
    $results = Search-PodeAsyncRouteTask -Query $query -User $user -CheckPermission

    This example searches for tasks that are in the 'Completed' state and checks if the specified user has permission to view them.

.OUTPUTS
    Returns an array of hashtables representing the matched tasks.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Search-PodeAsyncRouteTask {
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
                if ($result.Permission -and (! (Test-PodeAsyncRoutePermission -Permission $result.Permission.Read -User $User))) {
                    continue
                }
            }

            $match = $true

            # Iterate through each query condition
            foreach ($key in $Query.Keys) {
                # Check the variable name
                if (! (('Id', 'Name', 'StartingTime', 'CreationTime', 'CompletedTime', 'ExpireTime', 'State', 'Error', 'CallbackSettings', 'Cancellable',  'User', 'Url', 'Method', 'Progress') -contains $key)) {
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
                    throw $PodeLocale.invalidQueryFormatExceptionMessage
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
    The `Convert-PodeAsyncRouteCallBackRuntimeExpression` function processes runtime expressions
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
    $result = Convert-PodeAsyncRouteCallBackRuntimeExpression -Variable '$request.header.Content-Type' -DefaultValue 'application/json'
    Write-Output $result

.EXAMPLE
    # Convert a query parameter variable with a default value
    $result = Convert-PodeAsyncRouteCallBackRuntimeExpression -Variable '$request.query.userId' -DefaultValue 'unknown'
    Write-Output $result

.EXAMPLE
    # Convert a body field variable with a default value
    $result = Convert-PodeAsyncRouteCallBackRuntimeExpression -Variable '$request.body#/user/name' -DefaultValue 'anonymous'
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
function Convert-PodeAsyncRouteCallBackRuntimeExpression {
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
    The `Test-PodeAsyncRoutePermission` function checks if a user has the required permissions specified in the provided hashtable.
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

    $result = Test-PodeAsyncRoutePermission -Permission $permissions -User $user
    Write-Output $result

.NOTES
    This is an internal function and may change in future releases of Pode.
#>

function Test-PodeAsyncRoutePermission {
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
    It generates an Id for the async route task, invokes the internal async route task, and prepares the response based on the Accept header.
    The response includes details such as creation time, Id, state, name, and cancellable status. If the task involves a user,
    it adds default read and write permissions for the user.

.EXAMPLE
    $scriptBlock = Get-PodeAsyncRouteSetScriptBlock
    # Use the returned script block in an async route in Pode

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeAsyncRouteSetScriptBlock {
    # This function returns a script block that handles async route operations
    return [scriptblock] {
        try {
            # Get the 'Accept' header from the request to determine the response format
            $responseMediaType = Get-PodeHeader -Name 'Accept'

            # Retrieve the task to be executed asynchronously
            $asyncRouteTask = $PodeContext.AsyncRoutes.Items[$WebEvent.Route.AsyncPoolName]

            # Invoke the internal async route task
            #      $asyncOperation = Invoke-PodeAsyncRoute
            # Generate an Id for the async route task, using the provided IdGenerator or a new GUID
            $id = Invoke-PodeScriptBlock -ScriptBlock  $WebEvent.Route.AsyncRouteTaskIdGenerator -Return

            # Make a deepcopy of webEvent
            $webEvent_ToClone = @{Route = @{} }
            foreach ($key in $webEvent.Keys) {
                if (!('OnEnd', 'Middleware', 'Route', 'Response' -contains $key)) {
                    $webEvent_ToClone[$key] = $webEvent[$key]
                }
            }
            foreach ($key in $webEvent.Route.Keys) {
                if (!( 'AsyncRouteTaskIdGenerator', 'Middleware', 'Logic' -contains $key)) {
                    $webEvent_ToClone.Route[$key] = $webEvent.Route[$key]
                }
            }

            $webEvent_ToClone.Response = $webEvent.Response
            #     Write-PodeHost  $webEvent_ToClone.Response -explode -ShowType -Label 'webEvent_ToClone.Response'
            # Setup event parameters
            $parameters = @{
                Event            = @{
                    Lockable = $PodeContext.Threading.Lockables.Global
                    Sender   = $asyncRouteTask
                    Metadata = @{}
                }
                WebEvent         = Copy-PodeDeepClone -InputObject $webEvent_ToClone
                ___async___id___ = $id
            }
            # Add any task arguments
            foreach ($key in $asyncRouteTask.Arguments.Keys) {
                $parameters[$key] = $asyncRouteTask.Arguments[$key]
            }

            # Add any using variables
            if ($null -ne $asyncRouteTask.UsingVariables) {
                foreach ($usingVar in $asyncRouteTask.UsingVariables) {
                    $parameters[$usingVar.NewName] = $usingVar.Value
                }
            }

            # Set the creation time
            $creationTime = [datetime]::UtcNow

            # Initialize the result and runspace for the async route task
            $result = [System.Management.Automation.PSDataCollection[psobject]]::new()
            $runspace = Add-PodeRunspace -Type $asyncRouteTask.Name -ScriptBlock (($asyncRouteTask.Script).GetNewClosure()) -Parameters $parameters -OutputStream $result -PassThru

            # Set the expiration time based on the timeout value
            if ($asyncRouteTask.Timeout -ge 0) {
                $expireTime = [datetime]::UtcNow.AddSeconds($asyncRouteTask.Timeout)
            }
            else {
                $expireTime = [datetime]::MaxValue
            }

            # Initialize the result hashtable
            $asyncOperation = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
            $asyncOperation['Id'] = $Id
            $asyncOperation['Name'] = $asyncRouteTask.Name
            $asyncOperation['Runspace'] = $runspace
            $asyncOperation['Output'] = $result
            $asyncOperation['StartingTime'] = $null
            $asyncOperation['CreationTime'] = $creationTime
            $asyncOperation['CompletedTime'] = $null
            $asyncOperation['ExpireTime'] = $expireTime
            $asyncOperation['State'] = 'NotStarted'
            $asyncOperation['Error'] = $null
            $asyncOperation['CallbackSettings'] = $asyncRouteTask.CallbackSettings
            $asyncOperation['Cancellable'] = $asyncRouteTask.Cancellable
            $asyncOperation['Timeout'] = $asyncRouteTask.Timeout

            if ($asyncRouteTask.ContainsKey('Sse')) {
                $sseObject = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
                $sseObject['Name'] = $asyncRouteTask['Sse'].Name
                $sseObject['Group'] = $asyncRouteTask['Sse'].Group
                $sseObject['Url'] = "$($asyncRouteTask['Sse'].Name)?Id=$Id"
                $sseObject['State'] = 'NotStarted'
                $asyncOperation['Sse'] = $sseObject

                Write-PodeHost $asyncOperation['Sse'] -explode
            }

            # Add user information if available
            if ($WebEvent.Auth.User) {
                $asyncOperation['User'] = $WebEvent.Auth.User.Id
                # Make a deepcopy of the permission object
                $asyncOperation['Permission'] = ($asyncRouteTask.Permission | Copy-PodeDeepClone)
            }

            # Add the request URL and method
            $asyncOperation['Url'] = $WebEvent.Request.Url
            $asyncOperation['Method'] = $WebEvent.Method

            # If the task involves a user, include user information and add default permissions
            if ($asyncOperation['User']) {

                # Iterate over the permission types: 'Read' and 'Write'
                'Read', 'Write' | ForEach-Object {
                    # Check if the Permission hashtable contains the current permission type (e.g., 'Read' or 'Write')
                    if (! $asyncOperation['Permission'].ContainsKey($_)) {
                        # If not, initialize it as an empty hashtable
                        $asyncOperation['Permission'][$_] = @{}
                    }

                    # Check if the 'Users' array exists within the current permission type
                    if (! $asyncOperation['Permission'][$_].ContainsKey('Users')) {
                        # If not, initialize it as an empty array
                        $asyncOperation['Permission'][$_].Users = @()
                    }

                    # Add the user to the 'Users' array if they are not already present
                    if (! ($asyncOperation['Permission'][$_].Users -icontains $asyncOperation.User)) {
                        $asyncOperation['Permission'][$_].Users += $asyncOperation.User
                    }
                }
            }
            # Store the result in the Pode context
            $PodeContext.AsyncRoutes.Results[$Id] = $asyncOperation

            # Return the result of the asynchronous operation
            $res = Export-PodeAsyncRouteInfo -Async $asyncOperation
            # Send the response based on the requested media type
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $res -StatusCode 200; break }
                'application/json' { Write-PodeJsonResponse -Value $res -StatusCode 200 ; break }
                'application/yaml' { Write-PodeYamlResponse -Value $res -StatusCode 200 ; break }
                default { Write-PodeJsonResponse -Value $res -StatusCode 200 }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
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
                    $authorized = Test-PodeAsyncRoutePermission -Permission $async['Permission'].Read -User $WebEvent.Auth.User
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
                $export = Export-PodeAsyncRouteInfo -Async $async

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
                $errorMsg = @{Id = $id ; Error = 'User not entitled to view the Async Route operation' }
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
    Retrieves a script block for handling the stopping of asynchronous route tasks in Pode.

.DESCRIPTION
    This function returns a script block designed to stop asynchronous route tasks in a Pode web server.
    The script block checks for task identifiers in different parts of the request (cookies, headers, path parameters, query parameters)
    and retrieves the corresponding async route result. It handles authorization, cancels the task if it is cancellable and not completed,
    and formats the response based on the Accept header.

    PARAMETER In
        The source of the task identifier, such as 'Cookie', 'Header', 'Path', or 'Query'.

    PARAMETER TaskIdName
        The name of the task identifier to be retrieved from the specified source.

.EXAMPLE
    $scriptBlock = Get-PodeAsyncRouteStopScriptBlock
    # Use the returned script block in an async stop route in Pode

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeAsyncRouteStopScriptBlock {
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
                # If the task is cancellable
                if ($async['Cancellable']) {

                    if ($async['User'] -and ($null -eq $WebEvent.Auth.User)) {
                        # If the task is not cancellable, set an error message
                        $errorMsg = @{Id = $id ; Error = 'Async Route operation requires authentication.' }
                        $statusCode = 401 # Unauthorized
                    }
                    else {
                        if ((Test-PodeAsyncRoutePermission -Permission $async['Permission'].Write -User $WebEvent.Auth.User)) {
                            # Set the task state to 'Aborted' and log the error and completion time
                            $async['State'] = 'Aborted'
                            $async['Error'] = 'Aborted by the user'
                            $async['CompletedTime'] = [datetime]::UtcNow
                            $async['Runspace'].Pipeline.Dispose()
                            Complete-PodeAsyncRouteOperation -AsyncResult $async

                            # Create a summary of the task
                            $export = Export-PodeAsyncRouteInfo -Async $async

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
                            $errorMsg = @{Id = $id ; Error = 'User not entitled to stop the Async Route operation' }
                            $statusCode = 401 #'Unauthorized'
                        }
                    }
                }
                else {
                    # If the task is not cancellable, set an error message
                    $errorMsg = @{Id = $id ; Error = "The task has the 'NonCancellable' flag." }
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
    The `Export-PodeAsyncRouteInfo` function extracts and formats information from an asynchronous operation encapsulated in a [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] object. It includes details such as Id, creation time, state, user, permissions, and callback settings, among others. The function returns a hashtable with this information, suitable for logging or further processing.

.PARAMETER Async
    A [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] containing the asynchronous operation's details. This parameter is mandatory.

.PARAMETER Raw
    If specified, returns the raw [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] without any formatting.

.EXAMPLE
    $asyncInfo = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
    $exportedInfo = Export-PodeAsyncRouteInfo -Async $asyncInfo

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Export-PodeAsyncRouteInfo {
    param(
        [Parameter(Mandatory = $true )]
        [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]
        $Async,

        [switch]
        $Raw
    )
    if ($Raw.IsPresent) {
        return $Async
    }

    # Initialize a hashtable to store the exported information
    $export = @{
        Id           = $Async['Id']
        Cancellable  = $Async['Cancellable']
        # Format creation time in ISO 8601 UTC format
        CreationTime = Format-PodeDateToIso8601 -Date $Async['CreationTime']
        ExpireTime   = Format-PodeDateToIso8601 -Date $Async['ExpireTime']
        Name         = $Async['Name']
        State        = $Async['State']
    }

    # Include permission if it exists
    if ($Async.ContainsKey('Permission')) {
        $export.Permission = $Async['Permission']
    }

    # Include starting time if it exists
    if ($Async['StartingTime']) {
        $export.StartingTime = Format-PodeDateToIso8601 -Date $Async['StartingTime']
    }

    # Include callback settings if they exist
    if ($Async['CallbackSettings']) {
        $export.CallbackSettings = $Async['CallbackSettings']
    }

    # Include user if it exists
    if ($Async.ContainsKey('User')) {
        $export.User = $Async['User']
    }

    # Include SSE setting if it exists
    if ($Async.ContainsKey('Sse')) {
        $export.Sse = @{
            Name  = $Async['Sse'].Name
            State = $Async['Sse'].State
        }
        if ($Async['Sse'].ContainsKey('Group')) {
            $export.Sse['Group'] = $Async['Sse'].Group
        }
        if ($Async['Sse'].ContainsKey('Url')) {
            $export.Sse['Url'] = $Async['Sse'].Url
        }
    }

    # Include Progress setting if it exists
    if ($Async.ContainsKey('Progress')) {
        $export.Progress = [math]::Round($Async['Progress'], 2)
    }

    $export.IsCompleted = $Async['Runspace'].Handler.IsCompleted

    # If the task is completed, include the result or error based on the state
    if ($export.IsCompleted) {
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

        # Ensure completed time is set, retrying after a short delay if necessary
        if (! $Async.ContainsKey('CompletedTime')) {
            Start-Sleep 1
        }
        if ($Async.ContainsKey('CompletedTime')) {
            # Format completed time in ISO 8601 UTC format
            $export.CompletedTime = Format-PodeDateToIso8601 -Date $Async['CompletedTime']
        }

    }

    # Return the exported information
    return $export
}

<#
.SYNOPSIS
    Retrieves a script block for querying asynchronous route tasks in Pode.

.DESCRIPTION
    This function returns a script block designed to query asynchronous route tasks in a Pode web server.
    The script block processes the query from different parts of the request (body, query parameters, headers),
    searches for Async Route Tasks based on the query, checks permissions, and formats the response based on the Accept header.

.PARAMETER Payload
    The source of the query, such as 'Body', 'Query', or 'Header'.

.EXAMPLE
    $scriptBlock = Get-PodeAsyncRouteQueryScriptBlock
    # Use the returned script block in an async query route in Pode

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeAsyncRouteQueryScriptBlock {
    return [scriptblock] {
        param($Payload, $DefinitionTag)

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
            if ($PodeContext.Server.OpenAPI.Definitions[$DefinitionTag].hiddenComponents.schemaValidation) {
                $validation = Test-PodeOAJsonSchemaCompliance -Json $query -SchemaReference `
                    $PodeContext.Server.OpenApi.Definitions[$DefinitionTag].hiddenComponents.AsyncRoute.QueryRequestName
                $validated = $validation.result
            }
            else {
                $validated = $true
            }
            if ($validated) {
                # Search for Async Route Tasks based on the query and user, checking permissions
                $results = Search-PodeAsyncRouteTask -Query $query -User $WebEvent.Auth.User -CheckPermission

                # If results are found, export async route task information for each result
                if ($results) {
                    foreach ($async in $results) {
                        $response += Export-PodeAsyncRouteInfo -Async $async
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
            else {
                $response = @{'Error' = $validation.message }
                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $response -StatusCode 400; break }
                    'application/json' { Write-PodeJsonResponse -Value $response -StatusCode 400 ; break }
                    'application/yaml' { Write-PodeYamlResponse -Value $response -StatusCode 400 ; break }
                    default { Write-PodeJsonResponse -Value $response -StatusCode 400 }
                }
            }
        }
        catch {
            $response = @{'Error' = $_.tostring() }
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $response -StatusCode 500; break }
                'application/json' { Write-PodeJsonResponse -Value $response -StatusCode 500 ; break }
                'application/yaml' { Write-PodeYamlResponse -Value $response -StatusCode 500 ; break }
                default { Write-PodeJsonResponse -Value $response -StatusCode 500 }
            }
        }
    }
}


<#
.SYNOPSIS
    Retrieves the asynchronous route OpenAPI schema names.

.DESCRIPTION
    The Get-PodeAsyncRouteOAName function is used to fetch the schema names for asynchronous Pode route operations from the OpenAPI definitions.
    It checks for consistency across multiple OpenAPI definition tags and throws an exception if there are mismatches in the schema names.

.PARAMETER Tag
    An array of OpenAPI definition tags to be checked.

.THROWS
    An exception if there are mismatches in the schema names across different OpenAPI definitions.
#>
function Get-PodeAsyncRouteOAName {
    param (
        [string[]]
        $Tag,

        [switch]
        $ForEachOADefinition
    )
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $Tag

    if ($ForEachOADefinition.IsPresent) {
        $result = @{}
        if ( $DefinitionTag -is [string]) {
            $DefinitionTag = [string[]]@($DefinitionTag)
        }
        for ($i = 0; $i -lt $DefinitionTag.Count; $i++) {
            $result[$DefinitionTag[$i]] = $PodeContext.Server.OpenApi.Definitions[$DefinitionTag[$i]].hiddenComponents.AsyncRoute
        }
        return $result
    }
    if ($DefinitionTag.Count -gt 1) {
        for ( $i = 1 ; $i -lt $DefinitionTag.Count ; $i++) {

            if ($PodeContext.Server.OpenApi.Definitions[$DefinitionTag[0]].hiddenComponents.AsyncRoute.OATypeName -ne $PodeContext.Server.OpenApi.Definitions[$DefinitionTag[$i]].hiddenComponents.AsyncRoute.OATypeName) {
                # varies between different OpenAPI definitions.
                throw ($PodeLocale.openApiDefinitionsMismatchExceptionMessage -f 'OATypeName')
            }

            if ($PodeContext.Server.OpenApi.Definitions[$DefinitionTag[0]].hiddenComponents.AsyncRoute.QueryParameter -ne $PodeContext.Server.OpenApi.Definitions[$DefinitionTag[$i]].hiddenComponents.AsyncRoute.QueryParameter) {
                # varies between different OpenAPI definitions.
                throw ($PodeLocale.openApiDefinitionsMismatchExceptionMessage -f 'QueryParameter')
            }

            if ($PodeContext.Server.OpenApi.Definitions[$DefinitionTag[0]].hiddenComponents.AsyncRoute.QueryRequestName -ne $PodeContext.Server.OpenApi.Definitions[$DefinitionTag[$i]].hiddenComponents.AsyncRoute.QueryRequestName) {
                # varies between different OpenAPI definitions.
                throw ($PodeLocale.openApiDefinitionsMismatchExceptionMessage -f 'QueryRequestName')
            }

            if ($PodeContext.Server.OpenApi.Definitions[$DefinitionTag[0]].hiddenComponents.AsyncRoute.TaskIdName -ne $PodeContext.Server.OpenApi.Definitions[$DefinitionTag[$i]].hiddenComponents.AsyncRoute.TaskIdName) {
                # varies between different OpenAPI definitions.
                throw ($PodeLocale.openApiDefinitionsMismatchExceptionMessage -f 'TaskIdName')
            }

        }

        return $PodeContext.Server.OpenApi.Definitions[$DefinitionTag[0]].hiddenComponents.AsyncRoute
    }
    else {
        return $PodeContext.Server.OpenApi.Definitions[$DefinitionTag].hiddenComponents.AsyncRoute
    }
}



<#
.SYNOPSIS
    Retrieves the schema names for asynchronous Pode route operations.

.DESCRIPTION
    The Get-PodeAsyncRouteOASchemaNameInternal function is designed to return a hashtable containing schema names for asynchronous Pode route operations.
    It includes the type names and parameter names that are used for OpenAPI documentation.

.PARAMETER OATypeName
    The type name for OpenAPI documentation. The default is 'AsyncRouteTask'.

.PARAMETER TaskIdName
    The name of the parameter that contains the task Id. The default is 'id'.

.PARAMETER QueryRequestName
    The name of the Pode task query request in the OpenAPI schema. Defaults to 'AsyncRouteTaskQuery'.

.PARAMETER QueryParameterName
    The name of the query parameter in the OpenAPI schema. Defaults to 'AsyncRouteTaskQueryParameter'.
#>
function Get-PodeAsyncRouteOASchemaNameInternal {
    param (
        [string]
        $OATypeName = 'AsyncRouteTask',

        [Parameter()]
        [string]
        $TaskIdName = 'id',

        [Parameter()]
        [string]
        $QueryRequestName = 'AsyncRouteTaskQuery',

        [Parameter()]
        [string]
        $QueryParameterName = 'AsyncRouteTaskQueryParameter'
    )
    return @{
        # Store the OATypeName name
        OATypeName         = $OATypeName
        # Store the TaskIdName name
        TaskIdName         = $TaskIdName
        # Store the QueryRequestName name
        QueryRequestName   = $QueryRequestName
        # Store the QueryParameterName name
        QueryParameterName = $QueryParameterName
    }
}

<#
.SYNOPSIS
    Closes and disposes of the timer associated with a Pode asynchronous route operation.

.DESCRIPTION
    The `Close-PodeAsyncRouteTimer` function stops and disposes of a timer that is part of a
    Pode asynchronous route operation. It also unregisters any event associated with the timer
    and removes the timer from the operation's hashtable.

.PARAMETER Operation
    A hashtable representing the operation that contains the timer and event information. The
    function expects the hashtable to have a 'Timer' key and an 'eventName' key.

.EXAMPLE
    $operation = @{
        Timer = New-Object System.Timers.Timer
        eventName = 'AsyncRouteTimerEvent'
    }
    Close-PodeAsyncRouteTimer -Operation $operation

    This example stops and disposes of the timer in the `$operation` hashtable, unregistering the
    associated event and removing the timer from the hashtable.

.NOTES
    Ensure that the 'Timer' key and 'eventName' key are present in the hashtable passed to the
    function. If the 'Timer' key is not found, the function will return without performing any actions.

#>
function Close-PodeAsyncRouteTimer {
    param(
        [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]
        $Operation
    )
    try {
        if (!$Operation['Timer']) {
            return
        }

        $Operation['Timer'].Stop()
        $Operation['Timer'].Dispose()
        Unregister-Event -SourceIdentifier $Operation['eventName'] -Force
        $null = $Operation.Remove('Timer')
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}


<#
.SYNOPSIS
    Adds an OpenAPI component schema for Pode asynchronous route tasks.

.DESCRIPTION
    The Add-PodeAsyncRouteComponentSchema function creates an OpenAPI component schema for Pode asynchronous route tasks if it does not already exist.
    This schema includes properties such as Id, CreationTime, StartingTime, Result, CompletedTime, State, Error, and Task.

.PARAMETER Name
    The name of the OpenAPI component schema. Defaults to 'AsyncTask'.

.EXAMPLE
    Add-PodeAsyncRouteComponentSchema -Name 'CustomTask'

    This example creates an OpenAPI component schema named 'CustomTask' with the specified properties if it does not already exist.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Add-PodeAsyncRouteComponentSchema {
    param (
        [string]
        $Name = 'AsyncTask',

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
        New-PodeOAStringProperty -Name 'Id' -Format Uuid -Description 'The async route task unique identifier.' -Required |
            New-PodeOAStringProperty -Name 'User' -Description 'The async route task owner.' |
            New-PodeOAStringProperty -Name 'CreationTime' -Format Date-Time -Description 'The async route task creation time.' -Example '2024-07-02T20:58:15.2014422Z' -Required |
            New-PodeOAStringProperty -Name 'ExpireTime' -Format Date-Time -Description 'The async route task expiration.' -Example '2024-07-02T23:58:15.2014422Z' -Required |
            New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Description 'The async route task starting time.' -Example '2024-07-02T20:58:15.2014422Z' |
            New-PodeOAStringProperty -Name 'Result' -Example '{result ="Anything is good" , numOfIteration = 3 }' |
            New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Description 'The async route task completion time.' -Example '2024-07-02T20:59:23.2174712Z' |
            New-PodeOAStringProperty -Name 'State' -Description 'The async route task status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed', 'Aborted') |
            New-PodeOAStringProperty -Name 'Error' -Description 'The error message if any.' |
            New-PodeOAStringProperty -Name 'Name' -Example '__Get_path_endpoint1_' -Description 'The async route task name.' -Required |
            New-PodeOABoolProperty -Name 'Cancellable' -Description 'The async route task can be forcefully terminated' -Required |
            New-PodeOABoolProperty -Name 'IsCompleted' -Description 'The async route task is completed' -Required |
            New-PodeOAObjectProperty -Name 'Sse' -Description 'The async route task Sse details.'  -Properties (
                New-PodeOAStringProperty -Name 'Name' -Description 'The name of the Sse connection.' -Required |
                    New-PodeOAStringProperty -Name 'State' -Description 'The state of the Sse connection.' -Required -Enum @('NotStarted', 'Running', 'Failed', 'Completed', 'Aborted') |
                    New-PodeOAStringProperty -Name 'Group' -Description 'The group name for this Sse connection.' |
                    New-PodeOAStringProperty -Name 'Url' -Description 'The Sse url.'
                ) |
                New-PodeOANumberProperty -Name 'Progress' -Description 'The async route task percentage progress' -Minimum 0 -Maximum 100 |
                New-PodeOAObjectProperty -Name 'Permission' -Description 'The permission governing the async route task.' -Properties (
                ($permissionContent | New-PodeOAObjectProperty -Name 'Read'),
                ($permissionContent | New-PodeOAObjectProperty -Name 'Write')
                ) |
                New-PodeOAObjectProperty -Name 'CallbackInfo' -Description 'The Callback operation result' -Properties (
                    New-PodeOAStringProperty -Name 'State' -Description 'Operation status' -Example 'Completed' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
                        New-PodeOAIntProperty -Name 'Tentative' -Description 'Number of tentatives' |
                        New-PodeOAStringProperty -Name 'Url' -Format Uri -Description 'The callback URL' -Example 'Completed'
                    ) |
                    New-PodeOAObjectProperty -Name 'CallbackSettings' -Description 'Callback Configuration' -Properties (
                        New-PodeOAStringProperty -Name 'UrlField' -Description 'The URL Field.' -Example '$request.body#/callbackUrl' -Required |
                            New-PodeOABoolProperty -Name 'SendResult' -Description 'Send the result.' -Required |
                            New-PodeOAStringProperty -Name 'Method' -Description 'HTTP Method.' -Enum @('Post', 'Put') -Required |
                            New-PodeOAStringProperty -Name 'ContentType' -Description 'ContentType.' -Enum @('application/json' , 'application/xml', 'application/yaml') -Required |
                            New-PodeOAObjectProperty -Name 'HeaderFields' -AdditionalProperties (New-PodeOAStringProperty) -NoProperties
                        ) |
                        New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $Name -DefinitionTag $DefinitionTag
    }

}