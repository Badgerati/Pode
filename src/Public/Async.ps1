

function Add-PodeTaskRoute {
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

        [switch]
        $PassThru
    )

    $scriptBlock = {
        $id = $WebEvent.Query['taskId']
        $responseMediaType = Get-PodeHeader -Name 'Accept'
        if ($PodeContext.AsyncRoutes.Results.ContainsKey($id )) {
            $result = $PodeContext.AsyncRoutes.Results[$id]
            $taskSummary = @{
                ID           = $result.ID
                StartingTime = $result.StartingTime
                Task         = $result.Task
                State        = $result.State
            }

            if ($PodeContext.AsyncRoutes.Results[$id].Runspace.Handler.IsCompleted) {
                $taskSummary.CompletedTime = $result.CompletedTime
                if ($result.State -eq 'Failed') {
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

    $route = Add-PodeRoute -PassThru -Method Get -Path $Path -ScriptBlock $scriptBlock

    if (! $NoOpenAPI.IsPresent) {
        New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required |
            New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Example '07/02/2024 20:58:15' -Required |
            New-PodeOAStringProperty -Name 'Result'   -Example '@{s=7}' |
            New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Example '2024-07-02T20:59:23.2174712Z' |
            New-PodeOAStringProperty -Name 'State' -Description 'Order Status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
            New-PodeOAStringProperty -Name 'Error' |
            New-PodeOAStringProperty -Name 'Task' -Example 'Get:/path' -Required |
            New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name $OATypeName

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
                New-PodeOAStringProperty -Name 'taskId' -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In Query) |
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