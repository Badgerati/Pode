

function Add-PodeTaskRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([System.Object])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [string]
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




    $scriptBlockTemplate = @'
$id = $WebEvent.Query['taskId']
write-podehost $id
write-podehost $WebEvent -explode
if($PodeContext.AsyncRoutes.Results.ContainsKey($id )){
    $result=$PodeContext.AsyncRoutes.Results[$id]
    $taskSummary = @{
        ID            = $result.ID
        StartingTime  = $result.StartingTime
        Result        = $null
        CompletedTime = $result.CompletedTime
        Task          = $result.Task
        State         = $result.State
        Error         = $null

    }

    if ($PodeContext.AsyncRoutes.Results[$id].Runspace.Handler.IsCompleted) {
        $taskSummary.Result =$result.result
    }
    <# WriteResponse #> -StatusCode 200 -Value $taskSummary
}else{
    <# WriteResponse #> -StatusCode 402 -Value @{ID=$id ; Error= 'No Task Found'}
}
'@

    switch ($ResponseType) {
        'JSON' {
            $scriptBlock = [scriptblock]::Create(($scriptBlockTemplate -replace '<# WriteResponse #>', 'Write-PodeJsonResponse'))
            $MediaType = 'application/json'
        }
        'XML' {
            $scriptBlock = [scriptblock]::Create(($scriptBlockTemplate -replace '<# WriteResponse #>', 'Write-PodeXmlResponse'))
            $MediaType = 'application/xml'
        }
        'YAML' {
            $scriptBlock = [scriptblock]::Create(($scriptBlockTemplate -replace '<# WriteResponse #>', 'Write-PodeYamlResponse'))
            $MediaType = 'text/yaml'
        }
    }

    $route = Add-PodeRoute -PassThru -Method Get -Path $Path -ScriptBlock $scriptBlock

    if (! $NoOpenAPI.IsPresent) {
        New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required |
            New-PodeOAStringProperty -Name 'StartingTime' -Format Date-Time -Example '07/02/2024 20:58:15' -Required |
            New-PodeOAStringProperty -Name 'Result'   -Example '@{s=7}' -Required |
            New-PodeOAStringProperty -Name 'CompletedTime' -Format Date-Time -Example '2024-07-02T20:59:23.2174712Z' |
            New-PodeOAStringProperty -Name 'State' -Description 'Order Status' -Required -Example 'Running' -Enum @('NotStarted', 'Running', 'Failed', 'Completed') |
            New-PodeOAStringProperty -Name 'Error' |
            New-PodeOAStringProperty -Name 'Task' |
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
            Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied'
    }
    # return the routes?
    if ($PassThru) {
        return $Route
    }
}