
<#
.SYNOPSIS
    Adds a route to get the status and details of an asynchronous task in Pode.

.DESCRIPTION
    The `Add-PodeGetTaskRoute` function creates a route in Pode that allows retrieving the status
    and details of an asynchronous task. This function supports different methods for task ID
    retrieval (Cookie, Header, Path, Query) and various response types (JSON, XML, YAML). It
    integrates with OpenAPI documentation, providing detailed route information and response schemas.

.PARAMETER Path
    The URL path for the route. If the `In` parameter is set to 'Path', the `TaskIdName` will be
    appended to this path.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the route. Valid values are 'JSON', 'XML', and 'YAML'.
    You can specify multiple types. The default is 'JSON'.

.PARAMETER OATypeName
    The type name for OpenAPI documentation. The default is 'PodeTask'. This parameter is only used
    if the route is included in OpenAPI documentation.

.PARAMETER NoOpenAPI
    If specified, the route will not be included in the OpenAPI documentation.

.PARAMETER In
    Specifies where to retrieve the task ID from. Valid values are 'Cookie', 'Header', 'Path', and
    'Query'. The default is 'Query'.

.PARAMETER TaskIdName
    The name of the parameter that contains the task ID. The default is 'taskId'.

.PARAMETER PassThru
    If specified, the function returns the route information after processing.

.INPUTS
    None.

.OUTPUTS
    [hashtable]
#>
function Add-PodeGetTaskRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [string[]]
        [ValidateSet('JSON', 'XML', 'YAML')]
        $ResponseContentType = 'JSON',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $OATypeName = 'PodeTask',

        [Parameter(Mandatory = $true, ParameterSetName = 'NoOpenAPI')]
        [switch]
        $NoOpenAPI,

        [Parameter()]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In = 'Query',

        [Parameter()]
        $TaskIdName = 'taskId',

        [switch]
        $PassThru
    )

    $scriptBlock = {
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
                # ISO 8601 UTC format
                CreationTime = $result.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                StartingTime = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                Name         = $result.Name
                State        = $result.State
            }

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
        }
        else {
            $errorMsg = @{ID = $id ; Error = 'No Task Found' }
            $statusCode = 402
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode; break }
                'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
                'text/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
            }
        }
    }

    $MediaResponseType = @()
    if ($ResponseContentType -icontains 'JSON') { $MediaResponseType += 'application/json' }
    if ($ResponseContentType -icontains 'XML') { $MediaResponseType += 'application/xml' }
    if ($ResponseContentType -icontains 'YAML') { $MediaResponseType += 'text/yaml' }

    if ($In -eq 'Path') {
        $Path = "$Path/:$TaskIdName"
    }
    $route = Add-PodeRoute -PassThru -Method Get -Path $Path -ScriptBlock $scriptBlock -ArgumentList $In, $TaskIdName

    if (! $NoOpenAPI.IsPresent) {
        Add-PodeAsyncComponentSchema -Name $OATypeName

        $route | Set-PodeOARouteInfo -Summary 'Get Pode Task Info' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name $TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $MediaResponseType  -Content $OATypeName ) -PassThru |
            Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                New-PodeOAContentMediaType -MediaType $MediaResponseType -Content (
                    New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required | New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($OATypeName)Error"
                )
            )

    }
    # return the routes?
    if ($PassThru) {
        return $Route
    }
}


<#
.SYNOPSIS
    Adds a route to stop an asynchronous task in Pode.

.DESCRIPTION
    The `Add-PodeStopTaskRoute` function creates a route in Pode that allows the stopping of an
    asynchronous task. This function supports different methods for task ID retrieval (Cookie,
    Header, Path, Query) and various response types (JSON, XML, YAML). It integrates with OpenAPI
    documentation, providing detailed route information and response schemas.

.PARAMETER Path
    The URL path for the route. If the `In` parameter is set to 'Path', the `TaskIdName` will be
    appended to this path.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the route. Valid values are 'JSON', 'XML', and 'YAML'.
    You can specify multiple types. The default is 'JSON'.

.PARAMETER OATypeName
    The type name for OpenAPI documentation. The default is 'PodeTask'. This parameter is only used
    if the route is included in OpenAPI documentation.

.PARAMETER NoOpenAPI
    If specified, the route will not be included in the OpenAPI documentation.

.PARAMETER In
    Specifies where to retrieve the task ID from. Valid values are 'Cookie', 'Header', 'Path', and
    'Query'. The default is 'Query'.

.PARAMETER TaskIdName
    The name of the parameter that contains the task ID. The default is 'taskId'.

.PARAMETER PassThru
    If specified, the function returns the route information after processing.

.OUTPUTS
    [hashtable]

.EXAMPLE
    # Adding a route to stop an asynchronous task with the task ID in the query string
    Add-PodeStopTaskRoute -Path '/task/stop' -ResponseType YAML -In Query -TaskIdName 'taskId'

.EXAMPLE
    #  Adding a route to stop an asynchronous task with the task ID in the URL path
    Add-PodeStopTaskRoute -Path '/task/stop' -ResponseType JSON, YAML -In Path -TaskIdName 'taskId'
#>

function Add-PodeStopTaskRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [string[]]
        [ValidateSet('JSON', 'XML', 'YAML')]
        $ResponseContentType = 'JSON',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $OATypeName = 'PodeTask',

        [Parameter(Mandatory = $true, ParameterSetName = 'NoOpenAPI')]
        [switch]
        $NoOpenAPI,

        [Parameter()]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In = 'Query',

        [Parameter()]
        $TaskIdName = 'taskId',

        [switch]
        $PassThru
    )

    $scriptBlock = {
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
            if (!$result.Runspace.Handler.IsCompleted) {
                $result.State = 'Aborted'
                $result.Error = 'User Aborted!'
                $result.CompletedTime = [datetime]::UtcNow

                $taskSummary = @{
                    ID            = $id
                    # ISO 8601 UTC format
                    CreationTime  = $result.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    Name          = $result.Name
                    State         = $result.State
                    # ISO 8601 UTC format
                    CompletedTime = $result.CompletedTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    Error         = $result.Error
                }
                if ($result.StartingTime ) {
                    $taskSummary.StartingTime = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                }

                Close-PodeDisposable -Disposable $result.Runspace.Pipeline
                Close-PodeDisposable -Disposable $Result.Result

                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $taskSummary -StatusCode 200; break }
                    'application/json' { Write-PodeJsonResponse -Value $taskSummary -StatusCode 200 ; break }
                    'text/yaml' { Write-PodeYamlResponse -Value $taskSummary -StatusCode 200 ; break }
                    default { Write-PodeJsonResponse -Value $taskSummary -StatusCode 200 }
                }
            }
            else {
                $errorMsg = @{ID = $id ; Error = 'Task already completed.' }
                $statusCode = 402
                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode; break }
                    'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
                    'text/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                    default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
                }
            }
        }
        else {
            $errorMsg = @{ID = $id ; Error = 'No Task Found.' }
            $statusCode = 402
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $errorMsg -StatusCode $statusCode; break }
                'application/json' { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode ; break }
                'text/yaml' { Write-PodeYamlResponse -Value $errorMsg -StatusCode $statusCode ; break }
                default { Write-PodeJsonResponse -Value $errorMsg -StatusCode $statusCode }
            }
        }
    }

    $MediaResponseType = @()
    if ($ResponseContentType -icontains 'JSON') { $MediaResponseType += 'application/json' }
    if ($ResponseContentType -icontains 'XML') { $MediaResponseType += 'application/xml' }
    if ($ResponseContentType -icontains 'YAML') { $MediaResponseType += 'text/yaml' }

    if ($In -eq 'Path') {
        $Path = "$Path/:$TaskIdName"
    }

    $route = Add-PodeRoute -PassThru -Method Delete -Path $Path -ScriptBlock $scriptBlock -ArgumentList $In, $TaskIdName

    if (! $NoOpenAPI.IsPresent) {
        Add-PodeAsyncComponentSchema -Name $OATypeName

        $route | Set-PodeOARouteInfo -PassThru -Summary 'Stop Pode Task' |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name $TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $MediaResponseType  -Content $OATypeName ) -PassThru |
            Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                New-PodeOAContentMediaType -MediaType $MediaResponseType -Content (
                    New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required | New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($OATypeName)Error"
                )
            )
    }

    # return the routes?
    if ($PassThru) {
        return $Route
    }
}



<#
.SYNOPSIS
    Defines an asynchronous route in Pode with runspace management.

.DESCRIPTION
    The `Set-PodeRouteAsync` function enables you to define routes in Pode that execute asynchronously,
    leveraging runspace management for non-blocking operation. This function allows you to specify
    response types (JSON, XML, YAML) and manage asynchronous task parameters such as timeout and
    unique ID generation. It supports the use of arguments, `$using` variables, and state variables.

.PARAMETER Route
    A hashtable array that contains route definitions. Each hashtable should include
    the `Method`, `Path`, and `Logic` keys at a minimum.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the asynchronous route. Valid values are 'JSON', 'XML',
    and 'YAML'. You can specify multiple types. The default is 'JSON'.

.PARAMETER AsyncTimeout
    Defines the timeout period for the asynchronous task in seconds. The default value is -1,
    indicating no timeout.

.PARAMETER AsyncIdGenerator
    Specifies the function to generate unique IDs for asynchronous tasks. The default
    is 'New-PodeGuid'.

.PARAMETER OATypeName
    The type name for OpenAPI documentation. The default is 'PodeTask'. This parameter
    is only used if the route is included in OpenAPI documentation.

.PARAMETER PassThru
    If specified, the function returns the route information after processing.

.PARAMETER NoOpenAPI
    If specified, the route will not be included in the OpenAPI documentation.

.PARAMETER Threads
    Number of parallel threads for this specific route (Default 2)

.INPUTS
    [hashtable[]]

.OUTPUTS
    [hashtable[]]

.EXAMPLE
    # Using ArgumentList
    Add-PodeRoute -PassThru -Method Put -Path '/asyncParam' -ScriptBlock {
        param($sleepTime2, $Message)
        Write-PodeHost "sleepTime2=$sleepTime2"
        Write-PodeHost "Message=$Message"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $sleepTime2
        }
        return @{ InnerValue = $Message }
    } -ArgumentList @{sleepTime2 = 2; Message = 'coming as argument' } | Set-PodeRouteAsync -ResponseType JSON, XML

.EXAMPLE
    # Using $using variables
    $uSleepTime = 5
    $uMessage = 'coming from using'

    Add-PodeRoute -PassThru -Method Put -Path '/asyncUsing' -ScriptBlock {
        Write-PodeHost "sleepTime=$($using:uSleepTime)"
        Write-PodeHost "Message=$($using:uMessage)"
        Start-Sleep $using:uSleepTime
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeRouteAsync

#>
function Set-PodeRouteAsync {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [string[]]
        [ValidateSet('JSON', 'XML', 'YAML')]
        $ResponseContentType = 'JSON',

        [int]
        $AsyncTimeout = -1,

        [string]
        $AsyncIdGenerator = 'New-PodeGuid',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $OATypeName = 'PodeTask',

        [switch]
        $PassThru,

        [Parameter(Mandatory = $true, ParameterSetName = 'NoOpenAPI')]
        [switch]
        $NoOpenAPI,

        [int]
        $Threads = 2

    )
    Begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
        $MediaResponseType = @()
        # Determine media types based on ResponseType
        if ($ResponseContentType -icontains 'JSON') { $MediaResponseType += 'application/json' }
        if ($ResponseContentType -icontains 'XML') { $MediaResponseType += 'application/xml' }
        if ($ResponseContentType -icontains 'YAML') { $MediaResponseType += 'text/yaml' }

        # Start the housekeeper for async routes
        Start-PodeAsyncRoutesHousekeeper
    }

    process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    End {
        # Set Route to the array of values if multiple values are piped in
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }


        foreach ($r in $Route) {
            $r.IsAsync = $true
            $r.AsyncPoolName = "$($r.Method):$($r.Path)"
            # Store the route's async task definition in Pode context
            $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName] = @{
                Name           = $r.AsyncPoolName
                Script         = ConvertTo-PodeEnhancedScriptBlock -ScriptBlock $r.Logic
                UsingVariables = $r.UsingVariables
                Arguments      = (Protect-PodeValue -Value $r.Arguments -Default @{})
            }
            #Set thread count
            $PodeContext.Threads[$r.AsyncPoolName] = $Threads
            if (! $PodeContext.RunspacePools.AsyncRoutes.ContainsKey($r.AsyncPoolName)) {
                $PodeContext.RunspacePools.AsyncRoutes[$r.AsyncPoolName] = @{
                    Pool  = [runspacefactory]::CreateRunspacePool(1, $PodeContext.Threads[$r.AsyncPoolName] , $PodeContext.RunspaceState, $Host)
                    State = 'Waiting'
                }
            }
            # Replace the Route logic with this that allow to execute the original logic asynchronously
            $r.logic = [scriptblock] {
                param($Timeout, $IdGenerator, $AsyncPoolName)
                $responseMediaType = Get-PodeHeader -Name 'Accept'
                $id = (& $IdGenerator)

                write-podehost $WebEvent -Explode

                write-podehost $WebEvent.Auth -Explode

                # Invoke the internal async task
                $async = Invoke-PodeInternalAsync -Id $id -Task $PodeContext.AsyncRoutes.Items[$AsyncPoolName] -Timeout $Timeout -ArgumentList @{ WebEvent = $WebEvent; ___async___id___ = $id }

                # Prepare the response
                $res = @{
                    CreationTime = $async.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    Id           = $async.ID
                    State        = $async.State
                    Name         = $async.Name
                }

                # Send the response based on the requested media type
                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $res -StatusCode 200; break }
                    'application/json' { Write-PodeJsonResponse -Value $res -StatusCode 200 ; break }
                    'text/yaml' { Write-PodeYamlResponse -Value $res -StatusCode 200 ; break }
                    default { Write-PodeJsonResponse -Value $res -StatusCode 200 }
                }
            }

            # Set arguments and clear using variables
            $r.Arguments = (  $AsyncTimeout, $AsyncIdGenerator, $r.AsyncPoolName  )
            $r.UsingVariables = $null

            # Add OpenAPI documentation if not excluded
            if (! $NoOpenAPI.IsPresent) {
                Add-PodeAsyncComponentSchema -Name $OATypeName

                $route | Set-PodeOARouteInfo -PassThru |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $MediaResponseType  -Content $OATypeName )

            }
        }

        # Return the route information if PassThru is specified
        if ($PassThru) {
            return $Route
        }
    }
}


<#
.SYNOPSIS
    Retrieves user request data from a Pode web event.

.DESCRIPTION
    The Get-PodeUserRequest function retrieves data from different parts of a Pode web event based on the specified type.
    It supports retrieving data from the body, query parameters, headers, and request parameters.

.PARAMETER Type
    Specifies the type of data to retrieve. Acceptable values are 'Body', 'Query', 'Header', and 'Parameter'.

.PARAMETER Name
    The name of the query parameter, header, or request parameter to retrieve. This parameter is optional for 'Body' type.

.EXAMPLE
    Get-PodeUserRequest -Type 'Query' -Name 'username'

    This example retrieves the value of the 'username' query parameter from the Pode web event.

.EXAMPLE
    Get-PodeUserRequest -Type 'Header' -Name 'Authorization'

    This example retrieves the value of the 'Authorization' header from the Pode web event.

.OUTPUTS
    Returns the requested data from the Pode web event based on the specified type.
#>

function  Get-PodeUserRequest {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        [ValidateSet('Body', 'Query', 'Header', 'Parameter')]
        $Type,
        [string]
        $Name
    )
    switch ($Type) {
        'Body' { return $WebEvent.Data }
        'Query' { return $WebEvent.Query[$Name] }
        'Header' { return $WebEvent.Request.Headers[$Name] }
        'Parameter' { return $WebEvent.Parameters[$Name] }
    }
}


<#
.SYNOPSIS
    Adds a Pode route for querying task information.

.DESCRIPTION
    The Add-PodeQueryTaskRoute function creates a Pode route that allows querying task information based on specified parameters.
    The function supports multiple content types for both requests and responses, and can generate OpenAPI documentation if needed.

.PARAMETER Path
    The path for the Pode route.

.PARAMETER ResponseContentType
    Specifies the content type for the response. Acceptable values are 'JSON', 'XML', and 'YAML'. Defaults to 'JSON'.

.PARAMETER QueryContentType
    Specifies the content type for the query. Acceptable values are 'JSON', 'XML', and 'YAML'. Defaults to 'JSON'.

.PARAMETER OATypeName
    The OpenAPI type name. Defaults to 'PodeTask'. This parameter is used only if OpenAPI documentation is generated.

.PARAMETER NoOpenAPI
    Switch to indicate that no OpenAPI documentation should be generated. If this switch is set, OpenAPI parameters are ignored.

.PARAMETER PodeTaskQueryRequestName
    The name of the Pode task query request in the OpenAPI schema. Defaults to 'PodeTaskQueryRequest'.

.PARAMETER TaskIdName
    The name of the task ID parameter. Defaults to 'taskId'.

.PARAMETER Payload
    Specifies where the payload is located. Acceptable values are 'Body', 'Header', and 'Query'. Defaults to 'Body'.

.PARAMETER PassThru
    If set, the route will be returned from the function.

.PARAMETER Style
    Specifies the style of parameter serialization. Acceptable values are 'Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', and 'DeepObject'.

.EXAMPLE
    Add-PodeQueryTaskRoute -Path '/tasks/query' -ResponseContentType 'JSON' -QueryContentType 'JSON' -Payload 'Body'

    This example creates a Pode route at '/tasks/query' that processes query requests with JSON content types and expects the payload in the body.

.EXAMPLE
    Add-PodeQueryTaskRoute -Path '/tasks/query' -NoOpenAPI -Payload 'Header' -Style 'Simple'

    This example creates a Pode route at '/tasks/query' without generating OpenAPI documentation, expects the payload in the header, and uses simple serialization style.

.OUTPUTS
    [hashtable]
#>

function Add-PodeQueryTaskRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [string[]]
        [ValidateSet('JSON', 'XML', 'YAML')]
        $ResponseContentType = 'JSON',


        [string[] ]
        [ValidateSet('JSON', 'XML', 'YAML')]
        $QueryContentType = 'JSON',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $OATypeName = 'PodeTask',

        [Parameter(Mandatory = $true, ParameterSetName = 'NoOpenAPI')]
        [switch]
        $NoOpenAPI,
        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $PodeTaskQueryRequestName = 'PodeTaskQueryRequest',

        [Parameter()]
        $TaskIdName = 'taskId',
        [string]
        [ValidateSet('Body', 'Header', 'Query' )]
        $Payload = 'Body',

        [switch]
        $PassThru,

        [Parameter()]
        [ValidateSet('Simple', 'Label', 'Matrix', 'Query', 'Form', 'SpaceDelimited', 'PipeDelimited', 'DeepObject' )]
        [string]
        $Style
    )

    $scriptBlock = {
        param($Payload)
        switch ($Payload) {
            'Body' { $query = $WebEvent.Data }
            'Query' { $query = $WebEvent.Query[$Name] }
            'Header' { $query = $WebEvent.Request.Headers['query'] }
        }
        $responseMediaType = Get-PodeHeader -Name 'Accept'
        $response = @()
        $results = Search-PodeAsyncTask -Query $query
        if ($results) {
            foreach ($result in $results) {

                $taskSummary = @{
                    ID           = $result.ID
                    # ISO 8601 UTC format
                    CreationTime = $result.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    Name         = $result.Name
                    State        = $result.State
                }

                if ($result.StartingTime) {
                    $taskSummary.StartingTime = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
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
    $MediaResponseType = @()
    if ($ResponseContentType -icontains 'JSON') { $MediaResponseType += 'application/json' }
    if ($ResponseContentType -icontains 'XML') { $MediaResponseType += 'application/xml' }
    if ($ResponseContentType -icontains 'YAML') { $MediaResponseType += 'text/yaml' }

    $MediaQueryType = @()
    if ($QueryContentType -icontains 'JSON') { $MediaQueryType += 'application/json' }
    if ($QueryContentType -icontains 'XML') { $MediaQueryType += 'application/xml' }
    if ($QueryContentType -icontains 'YAML') { $MediaQueryType += 'text/yaml' }

    switch ($Payload) {
        'Body' { $route = Add-PodeRoute -PassThru -Method Post -Path $Path -ScriptBlock $scriptBlock -ArgumentList $Payload }
        'Header' {
            $route = Add-PodeRoute -PassThru -Method Get -Path $Path -ScriptBlock $scriptBlock -ArgumentList $Payload
        }
        'query' {
            $route = Add-PodeRoute -PassThru -Method Get -Path $Path -ScriptBlock $scriptBlock -ArgumentList $Payload
        }
    }


    if (! $NoOpenAPI.IsPresent) {
        Add-PodeAsyncComponentSchema -Name $OATypeName

        if (!(Test-PodeOAComponent -Field schemas -Name  $PodeTaskQueryRequestName)) {
            New-PodeOAObjectProperty  -AdditionalProperties  (
                New-PodeOAStringProperty -Name 'op' -Enum  'GT', 'LT', 'GE', 'LE', 'EQ', 'NE', 'LIKE', 'NOTLIKE' -Required |
                    New-PodeOAStringProperty -Name 'value'  -Description 'The value to compare against' -Required |
                    New-PodeOAObjectProperty
                ) | Add-PodeOAComponentSchema -Name $PodeTaskQueryRequestName
            }

            $exampleHashTable = @{
                'StartingTime' = @{
                    op    = 'GT'
                    value = get-date '2024-07-05 20:20:00Z'
                }
                'State'        = @{
                    op    = 'EQ'
                    value = 'Completed'
                }
                'Name'         = @{
                    op    = 'LIKE'
                    value = 'Get'
                }
            }

            $route | Set-PodeOARouteInfo -Summary 'Query Pode Task Info' -PassThru | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $MediaResponseType  -Content $OATypeName -Array) -PassThru |
                Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                    New-PodeOAContentMediaType -MediaType $MediaResponseType -Content (
                        New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required | New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($OATypeName)Error"
                    )
                )
        if ($MediaQueryType) {
            $example = [ordered]@{}

            foreach ($mt in   $MediaQueryType) {
                $example += New-PodeOAExample -MediaType $mt -Name $PodeTaskQueryRequestName -Value $exampleHashTable
            }
        }
        if ($Style) {
            $example = ConvertTo-PodeSerializedString -Hashtable $exampleHashTable -Style $Style -Explode
        }

        switch ($Payload.ToLowerInvariant()) {
            'body' {
                $requestBody = New-PodeOARequestBody -Content  (New-PodeOAContentMediaType -MediaType $MediaQueryType  -Content $PodeTaskQueryRequestName -Array ) -Examples $example
                $route | Set-PodeOARequest  -RequestBody $requestBody
                break
            }
            'header' {
                if ($Style) {
                    $requestParameter = ConvertTo-PodeOAParameter -In Header -Schema $PodeTaskQueryRequestName -array -Style $Style -Example $example -Explode
                }
                else {
                    $requestParameter = ConvertTo-PodeOAParameter -In Header -Schema $PodeTaskQueryRequestName -ContentType $MediaQueryType[0] -Example  $example[0]
                }

                $route | Set-PodeOARequest   -Parameters $requestParameter
                break
            }
            'query' {
                $requestParameter = ConvertTo-PodeOAParameter -In Query -Schema $PodeTaskQueryRequestName -Style $Style -Example $example -Explode
                $route | Set-PodeOARequest   -Parameters $requestParameter
            }
        }
    }
    # return the routes?
    if ($PassThru) {
        return $Route
    }
}