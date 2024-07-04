

function Add-PodeGetTaskRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([System.Object])]
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

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $Tag,

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $OperationId,

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $Summary = 'Get Pode Task Info',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $Description = 'Get Pode Task Info',

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
        write-podehost "IN=$In"
        write-podehost "TaskIdName=$TaskIdName"
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
                StartingTime = $result.StartingTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                Task         = $result.Task
                State        = $result.State
            }

            if ($PodeContext.AsyncRoutes.Results[$id].Runspace.Handler.IsCompleted) {
                # ISO 8601 UTC format
                $taskSummary.CompletedTime = $result.CompletedTime.ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ')
                if ($result.Error) {
                    $taskSummary.Error = $result.Error
                }
                else {
                    if ($result.result.Count -gt 0) {
                        $taskSummary.Result = $result.result[0]
                    }
                    else {
                        $result.result = $null
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
        if (! (Test-PodeOAComponent -Field schemas -Name  $OATypeName)) {
            New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required |
                New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Example '2024-07-02T20:58:15.2014422Z' -Required |
                New-PodeOAStringProperty -Name 'Result'   -Example '@{s=7}' |
                New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Example '2024-07-02T20:59:23.2174712Z' |
                New-PodeOAStringProperty -Name 'State' -Description 'Order Status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
                New-PodeOAStringProperty -Name 'Error' -Description 'The Error message if any.' |
                New-PodeOAStringProperty -Name 'Task' -Example 'Get:/path' -Required |
                New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $OATypeName
        }
        $oARouteInfo = @{
            Summary     = $Summary
            Description = $Description

        }
        if ($Tag) {
            $oARouteInfo.Tags = $Tag
        }

        if ($OperationId) {
            $oARouteInfo.OperationId = $OperationId
        }

        $route | Set-PodeOARouteInfo @oARouteInfo -PassThru |
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



function Add-PodeStopTaskRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([System.Object])]
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

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $Tag,

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $OperationId,

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $Summary = 'Stop Pode Task',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $Description = 'Stop a PodeTask during its execution',

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
        write-podehost "IN=$In"
        write-podehost "TaskIdName=$TaskIdName"
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
            write-podehost $result -Explode
            $taskSummary = @{
                ID            = $id
                # ISO 8601 UTC format
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
        if (!(Test-PodeOAComponent -Field schemas -Name  $OATypeName)) {
            New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required |
                New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Example '2024-07-02T20:58:15.2014422Z' -Required |
                New-PodeOAStringProperty -Name 'Result'   -Example '@{s=7}' |
                New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Example '2024-07-02T20:59:23.2174712Z' |
                New-PodeOAStringProperty -Name 'State' -Description 'Order Status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
                New-PodeOAStringProperty -Name 'Error' -Description 'The Error message if any.' |
                New-PodeOAStringProperty -Name 'Task' -Example 'Get:/path' -Required |
                New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $OATypeName
        }
        $oARouteInfo = @{
            Summary     = $Summary
            Description = $Description

        }
        if ($Tag) {
            $oARouteInfo.Tags = $Tag
        }

        if ($OperationId) {
            $oARouteInfo.OperationId = $OperationId
        }

        $route | Set-PodeOARouteInfo @oARouteInfo -PassThru |
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