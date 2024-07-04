
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

.PARAMETER ResponseType
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
        $ResponseType = 'JSON',

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
                Task         = $result.Task
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

    $MediaType = @()
    if ($ResponseType -icontains 'JSON') { $MediaType += 'application/json' }
    if ($ResponseType -icontains 'XML') { $MediaType += 'application/xml' }
    if ($ResponseType -icontains 'YAML') { $MediaType += 'text/yaml' }

    if ($In -eq 'Path') {
        $Path = "$Path/:$TaskIdName"
    }
    $route = Add-PodeRoute -PassThru -Method Get -Path $Path -ScriptBlock $scriptBlock -ArgumentList $In, $TaskIdName

    if (! $NoOpenAPI.IsPresent) {
        Add-PodeAsyncComponentSchema -Name $OATypeName

        $route | Set-PodeOARouteInfo -Summary 'Get Pode Task Info' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name $TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $MediaType  -Content $OATypeName ) -PassThru |
            Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                New-PodeOAContentMediaType -MediaType $MediaType -Content (
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

.PARAMETER ResponseType
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
        $ResponseType = 'JSON',

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
            $result.State = 'Aborted'
            $result.Error = 'User Aborted!'
            $result.CompletedTime = [datetime]::UtcNow
            $taskSummary = @{
                ID            = $id
                # ISO 8601 UTC format
                CreationTime  = $result.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                StartingTime  = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                Task          = $result.Task
                State         = $result.State
                # ISO 8601 UTC format
                CompletedTime = $result.CompletedTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                Error         = $result.Error
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

    $MediaType = @()
    if ($ResponseType -icontains 'JSON') { $MediaType += 'application/json' }
    if ($ResponseType -icontains 'XML') { $MediaType += 'application/xml' }
    if ($ResponseType -icontains 'YAML') { $MediaType += 'text/yaml' }

    if ($In -eq 'Path') {
        $Path = "$Path/:$TaskIdName"
    }

    $route = Add-PodeRoute -PassThru -Method Delete -Path $Path -ScriptBlock $scriptBlock -ArgumentList $In, $TaskIdName

    if (! $NoOpenAPI.IsPresent) {
        Add-PodeAsyncComponentSchema -Name $OATypeName

        $route | Set-PodeOARouteInfo -PassThru -Summary 'Stop Pode Task' |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name $TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $MediaType  -Content $OATypeName ) -PassThru |
            Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                New-PodeOAContentMediaType -MediaType $MediaType -Content (
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

.PARAMETER ResponseType
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
        $ResponseType = 'JSON',

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
        $NoOpenAPI

    )
    Begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()
        $MediaType = @()
        # Determine media types based on ResponseType
        if ($ResponseType -icontains 'JSON') { $MediaType += 'application/json' }
        if ($ResponseType -icontains 'XML') { $MediaType += 'application/xml' }
        if ($ResponseType -icontains 'YAML') { $MediaType += 'text/yaml' }

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
            $asyncName = "$($r.Method):$($r.Path)"
            # Store the route's async task definition in Pode context
            $PodeContext.AsyncRoutes.Items[$asyncName] = @{
                Name           = $asyncName
                Script         = ConvertTo-PodeEnhancedScriptBlock -ScriptBlock $r.Logic
                UsingVariables = $r.UsingVariables
                Arguments      = (Protect-PodeValue -Value $r.Arguments -Default @{})
            }
            # Replace the Route logic with this that allow to execute the original logic asynchronously
            $r.logic = [scriptblock] {
                param($Timeout, $IdGenerator)
                $responseMediaType = Get-PodeHeader -Name 'Accept'
                $id = (& $IdGenerator)
                $asyncName = "$($WebEvent.Method):$($WebEvent.Path)"

                # Invoke the internal async task
                $async = Invoke-PodeInternalAsync -Id $id -Task $PodeContext.AsyncRoutes.Items[$asyncName ] -Timeout $Timeout -ArgumentList @{ WebEvent = $WebEvent; ___async___id___ = $id }

                # Prepare the response
                $res = @{
                    CreationTime = $async.CreationTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                    Id           = $async.ID
                    State        = $async.State
                    Task         = $async.Task
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
            $r.Arguments = (  $AsyncTimeout, $AsyncIdGenerator )
            $r.UsingVariables = $null

            # Add OpenAPI documentation if not excluded
            if (! $NoOpenAPI.IsPresent) {
                Add-PodeAsyncComponentSchema -Name $OATypeName

                $route | Set-PodeOARouteInfo -PassThru  |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $MediaType  -Content $OATypeName )

            }
        }

        # Return the route information if PassThru is specified
        if ($PassThru) {
            return $Route
        }
    }
}

