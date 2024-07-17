
<#
.SYNOPSIS
    Adds a route to get the status and details of an asynchronous task in Pode.

.DESCRIPTION
    The `Add-PodeAsyncGetRoute` function creates a route in Pode that allows retrieving the status
    and details of an asynchronous task. This function supports different methods for task ID
    retrieval (Cookie, Header, Path, Query) and various response types (JSON, XML, YAML). It
    integrates with OpenAPI documentation, providing detailed route information and response schemas.

.PARAMETER Path
    The URL path for the route. If the `In` parameter is set to 'Path', the `TaskIdName` will be
    appended to this path.

.PARAMETER Middleware
    An array of ScriptBlocks for optional Middleware.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) this Route should be bound against.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the route. Valid values are 'application/json' , 'application/xml', 'application/yaml'.
    You can specify multiple types. The default is 'application/json'.

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

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER AllowAnon
    If supplied, the Route will allow anonymous access for non-authenticated users.

.PARAMETER IfExists
    Specifies what action to take when a Route already exists. (Default: Default)

.PARAMETER OADefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.OUTPUTS
    [hashtable]
#>
function Add-PodeAsyncGetRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter( )]
        [AllowNull()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [string[]]
        [ValidateSet('application/json' , 'application/xml', 'application/yaml')]
        $ResponseContentType = 'application/json',

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
        $PassThru,

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string[]]
        $OADefinitionTag

    )

    if ($In -eq 'Path') {
        $Path = "$Path/:$TaskIdName"
    }

    $param = @{
        Method           = 'Get'
        Path             = $Path
        ScriptBlock      = Get-PodeAsyncGetScriptBlock
        ArgumentList     = ($In, $TaskIdName)
        ErrorContentType = $ResponseContentType[0]
        PassThru         = $true
    }
    if ($Middleware) {
        $param.Middleware = $Middleware
    }
    if ($EndpointName) {
        $param.$EndpointName = $EndpointName
    }
    if ($Authentication) {
        $param.Authentication = $Authentication
    }
    if ($Access) {
        $param.Access = $Access
    }
    if ($Role) {
        $param.Role = $Role
    }
    if ($Group) {
        $param.Group = $Group
    }
    if ($Scope) {
        $param.Scope = $Scope
    }
    if ($User) {
        $param.User = $User
    }
    if ($AllowAnon.IsPresent) {
        $param.AllowAnon = $AllowAnon
    }
    if ($IfExists.IsPresent) {
        $param.IfExists = $IfExists
    }

    $route = Add-PodeRoute @param

    if (! $NoOpenAPI.IsPresent) {
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $OADefinitionTag
        Add-PodeAsyncComponentSchema -Name $OATypeName -DefinitionTag $DefinitionTag

        $route | Set-PodeOARouteInfo -Summary 'Get Pode Task Info' -DefinitionTag $DefinitionTag -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name $TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $ResponseContentType  -Content $OATypeName ) -PassThru |
            Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                New-PodeOAContentMediaType -MediaType $ResponseContentType -Content (
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
    The `Add-PodeAsyncStopRoute` function creates a route in Pode that allows the stopping of an
    asynchronous task. This function supports different methods for task ID retrieval (Cookie,
    Header, Path, Query) and various response types (JSON, XML, YAML). It integrates with OpenAPI
    documentation, providing detailed route information and response schemas.

.PARAMETER Path
    The URL path for the route. If the `In` parameter is set to 'Path', the `TaskIdName` will be
    appended to this path.

.PARAMETER Middleware
    An array of ScriptBlocks for optional Middleware.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) this Route should be bound against.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the route. Valid values are 'application/json' , 'application/xml', 'application/yaml'.
    You can specify multiple types. The default is 'application/json'.

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

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER AllowAnon
    If supplied, the Route will allow anonymous access for non-authenticated users.

.PARAMETER IfExists
    Specifies what action to take when a Route already exists. (Default: Default)

.PARAMETER OADefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.OUTPUTS
    [hashtable]

.EXAMPLE
    # Adding a route to stop an asynchronous task with the task ID in the query string
    Add-PodeAsyncStopRoute -Path '/task/stop' -ResponseType YAML -In Query -TaskIdName 'taskId'

.EXAMPLE
    #  Adding a route to stop an asynchronous task with the task ID in the URL path
    Add-PodeAsyncStopRoute -Path '/task/stop' -ResponseType JSON, YAML -In Path -TaskIdName 'taskId'
#>

function Add-PodeAsyncStopRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter( )]
        [AllowNull()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [string[]]
        [ValidateSet('application/json' , 'application/xml', 'application/yaml')]
        $ResponseContentType = 'application/json',

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
        $PassThru,

        [Parameter()]
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string[]]
        $OADefinitionTag
    )

    if ($In -eq 'Path') {
        $Path = "$Path/:$TaskIdName"
    }
    $param = @{
        Method           = 'Delete'
        Path             = $Path
        ScriptBlock      = Get-PodeAsyncStopScriptBlock
        ArgumentList     = ($In, $TaskIdName)
        ErrorContentType = $ResponseContentType[0]
        PassThru         = $true
    }
    if ($Middleware) {
        $param.Middleware = $Middleware
    }
    if ($EndpointName) {
        $param.$EndpointName = $EndpointName
    }
    if ($Authentication) {
        $param.Authentication = $Authentication
    }
    if ($Access) {
        $param.Access = $Access
    }
    if ($Role) {
        $param.Role = $Role
    }
    if ($Group) {
        $param.Group = $Group
    }
    if ($Scope) {
        $param.Scope = $Scope
    }
    if ($User) {
        $param.User = $User
    }
    if ($AllowAnon.IsPresent) {
        $param.AllowAnon = $AllowAnon
    }
    if ($IfExists.IsPresent) {
        $param.IfExists = $IfExists
    }

    $route = Add-PodeRoute @param

    if (! $NoOpenAPI.IsPresent) {
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $OADefinitionTag
        Add-PodeAsyncComponentSchema -Name $OATypeName -DefinitionTag $DefinitionTag

        $route | Set-PodeOARouteInfo -Summary 'Stop Pode Task' -DefinitionTag $DefinitionTag -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name $TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $ResponseContentType  -Content $OATypeName ) -PassThru |
            Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                New-PodeOAContentMediaType -MediaType $ResponseContentType -Content (
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
    Adds a Pode route for querying task information.

.DESCRIPTION
    The Add-PodeAsyncQueryRoute function creates a Pode route that allows querying task information based on specified parameters.
    The function supports multiple content types for both requests and responses, and can generate OpenAPI documentation if needed.

.PARAMETER Path
    The path for the Pode route.

.PARAMETER Middleware
    An array of ScriptBlocks for optional Middleware.

.PARAMETER EndpointName
    The EndpointName of an Endpoint(s) this Route should be bound against.

.PARAMETER Authentication
    The name of an Authentication method which should be used as middleware on this Route.

.PARAMETER Access
    The name of an Access method which should be used as middleware on this Route.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the route. Valid values are 'application/json' , 'application/xml', 'application/yaml'.
    You can specify multiple types. The default is 'application/json'.

.PARAMETER QueryContentType
    Specifies the response type(s) for the query. Valid values are 'application/json' , 'application/xml', 'application/yaml'.
    You can specify multiple types. The default is 'application/json'.

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

.PARAMETER Role
    One or more optional Roles that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Group
    One or more optional Groups that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER Scope
    One or more optional Scopes that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER User
    One or more optional Users that will be authorised to access this Route, when using Authentication with an Access method.

.PARAMETER AllowAnon
    If supplied, the Route will allow anonymous access for non-authenticated users.

.PARAMETER IfExists
    Specifies what action to take when a Route already exists. (Default: Default)

.PARAMETER OADefinitionTag
    An Array of strings representing the unique tag for the API specification.
    This tag helps in distinguishing between different versions or types of API specifications within the application.
    You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.EXAMPLE
    Add-PodeAsyncQueryRoute -Path '/tasks/query' -ResponseContentType 'application/json' -QueryContentType 'application/json','application/yaml' -Payload 'Body'

    This example creates a Pode route at '/tasks/query' that processes query requests with JSON content types and expects the payload in the body.

.OUTPUTS
    [hashtable]
#>

function Add-PodeAsyncQueryRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter( )]
        [AllowNull()]
        [string[]]
        $EndpointName,

        [Parameter()]
        [Alias('Auth')]
        [string]
        $Authentication,

        [Parameter()]
        [string]
        $Access,

        [string[]]
        [ValidateSet('application/json' , 'application/xml', 'application/yaml')]
        $ResponseContentType = 'application/json',

        [string[] ]
        [ValidateSet('application/json' , 'application/xml', 'application/yaml')]
        $QueryContentType = 'application/json',

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
        [string[]]
        $Role,

        [Parameter()]
        [string[]]
        $Group,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [string[]]
        $User,

        [switch]
        $AllowAnon,

        [Parameter()]
        [ValidateSet('Default', 'Error', 'Overwrite', 'Skip')]
        [string]
        $IfExists = 'Default',

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string[]]
        $OADefinitionTag

    )

    $param = @{
        Path             = $Path
        ScriptBlock      = Get-PodeAsyncQueryScriptBlock
        ArgumentList     = $Payload
        ErrorContentType = $ResponseContentType[0]
        ContentType      = $QueryContentType[0]
        PassThru         = $true
    }

    if ($Middleware) {
        $param.Middleware = $Middleware
    }
    if ($EndpointName) {
        $param.$EndpointName = $EndpointName
    }
    if ($Authentication) {
        $param.Authentication = $Authentication
    }
    if ($Access) {
        $param.Access = $Access
    }
    if ($Role) {
        $param.Role = $Role
    }
    if ($Group) {
        $param.Group = $Group
    }
    if ($Scope) {
        $param.Scope = $Scope
    }
    if ($User) {
        $param.User = $User
    }
    if ($AllowAnon.IsPresent) {
        $param.AllowAnon = $AllowAnon
    }
    if ($IfExists.IsPresent) {
        $param.IfExists = $IfExists
    }

    switch ($Payload) {
        'Body' {
            $param.Method = 'Post'
        }
        'Header' {
            $param.Method = 'Get'
        }
        'query' {
            $param.Method = 'Get'
        }
    }

    $route = Add-PodeRoute @param

    if (! $NoOpenAPI.IsPresent) {
        $DefinitionTag = Test-PodeOADefinitionTag -Tag $OADefinitionTag
        Add-PodeAsyncComponentSchema -Name $OATypeName -DefinitionTag $DefinitionTag

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
                'CreationTime' = @{
                    op    = 'LE'
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
                'ID'           = @{
                    op    = 'EQ'
                    value = 'b143660f-ebeb-49d9-9f92-cd21f3ff559c'
                }
                'Cancelable'   = @{
                    op    = 'EQ'
                    value = $true
                }
            }

            $route | Set-PodeOARouteInfo -Summary 'Query Pode Task Info' -DefinitionTag $DefinitionTag -PassThru | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $ResponseContentType  -Content $OATypeName -Array) -PassThru |
                Add-PodeOAResponse -StatusCode 402 -Description 'Invalid ID supplied' -Content (
                    New-PodeOAContentMediaType -MediaType $ResponseContentType -Content (
                        New-PodeOAStringProperty -Name 'ID' -Format Uuid -Required | New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($OATypeName)Error"
                    )
                )
        $example = [ordered]@{}

        foreach ($mt in   $QueryContentType) {
            $example += New-PodeOAExample -MediaType $mt -Name $PodeTaskQueryRequestName -Value $exampleHashTable
        }

        switch ($Payload.ToLowerInvariant()) {
            'body' {
                $route | Set-PodeOARequest  -RequestBody (
                    New-PodeOARequestBody -Content  (New-PodeOAContentMediaType -MediaType $QueryContentType  -Content $PodeTaskQueryRequestName   ) -Examples $example
                )
                break
            }
            'header' {
                $route | Set-PodeOARequest   -Parameters (ConvertTo-PodeOAParameter -In Header -Schema $PodeTaskQueryRequestName -ContentType $QueryContentType[0] -Example  $example[0])
                break
            }
            'query' {
                $route | Set-PodeOARequest   -Parameters (ConvertTo-PodeOAParameter -In Query  -Schema $PodeTaskQueryRequestName -ContentType $QueryContentType[0] -Example  $example[0])
            }
        }
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
    The `Set-PodeAsyncRoute` function enables you to define routes in Pode that execute asynchronously,
    leveraging runspace management for non-blocking operation. This function allows you to specify
    response types (JSON, XML, YAML) and manage asynchronous task parameters such as timeout and
    unique ID generation. It supports the use of arguments, `$using` variables, and state variables.

.PARAMETER Route
    A hashtable array that contains route definitions. Each hashtable should include
    the `Method`, `Path`, and `Logic` keys at a minimum.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the route. Valid values are 'application/json' , 'application/xml', 'application/yaml'.
    You can specify multiple types. The default is 'application/json'.

.PARAMETER Timeout
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

.PARAMETER MaxRunspaces
    The maximum number of Runspaces that can exist in this route. The default is 2.

.PARAMETER MinRunspaces
    The minimum number of Runspaces that exist in this route. The default is 1.

.PARAMETER Callback
    Specifies whether to include callback functionality for the route.

.PARAMETER CallbackUrl
    Specifies the URL field for the callback. Default is '$request.body#/callbackUrl'.
    Can accept the following meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl

.PARAMETER CallbackSendResult
    If specified, sends the result of the callback.

.PARAMETER EventName
    Specifies the event name for the callback.

.PARAMETER CallbackContentType
    Specifies the content type for the callback. The default is 'application/json'.
    Can accept the following meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl

.PARAMETER CallbackMethod
    Specifies the HTTP method for the callback. The default is 'Post'.
    Can accept the following meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl

.PARAMETER CallbackHeaderFields
    Specifies the header fields for the callback as a hashtable. The key can be a string representing
    the header key or one of the meta values. The value is the header value if it's a standard key or
    the default value if the meta value is not resolvable.
    Can accept the following meta values as keys:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl

.PARAMETER Permission
    Access list
    Permission object structure
    @{
        Read  = @{
            Groups = @()
            Roles      = @()
            Scopes     = @()
            Users      = @()
        }
        Write = @{
            Groups      = @()
            Roles       = @()
            Scopes      = @()
            Users       = @()
        }
    }

.PARAMETER NotCancelable
    The Async operation cannot be forcefully terminated

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
    } -ArgumentList @{sleepTime2 = 2; Message = 'coming as argument' } | Set-PodeAsyncRoute -ResponseType JSON, XML

.EXAMPLE
    # Using $using variables
    $uSleepTime = 5
    $uMessage = 'coming from using'

    Add-PodeRoute -PassThru -Method Put -Path '/asyncUsing' -ScriptBlock {
    Write-PodeHost "sleepTime=$($using:uSleepTime)"
    Write-PodeHost "Message=$($using:uMessage)"
    Start-Sleep $using:uSleepTime
    return @{ InnerValue = $using:uMessage }
    } | Set-PodeAsyncRoute

.NOTES
    The parameters CallbackHeaderFields, CallbackMethod, CallbackContentType, and CallbackUrl can accept these meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl
#>
function Set-PodeAsyncRoute {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [string[]]
        [ValidateSet('application/json' , 'application/xml', 'application/yaml')]
        $ResponseContentType = 'application/json',

        [int]
        $Timeout = -1,

        [Parameter()]
        [string]
        $AsyncIdGenerator,

        [Parameter(ParameterSetName = 'OpenAPI')]
        [string]
        $OATypeName = 'PodeTask',

        [switch]
        $PassThru,

        [Parameter(Mandatory = $true, ParameterSetName = 'NoOpenAPI')]
        [switch]
        $NoOpenAPI,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $MaxRunspaces = 2,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $MinRunspaces = 1,

        [switch]
        $Callback,

        [string]
        $CallbackUrl = '$request.body#/callbackUrl',

        [switch]
        $CallbackSendResult,

        [string]
        $EventName,

        [string]
        $CallbackContentType = 'application/json',

        [string]
        $CallbackMethod = 'Post',

        [hashtable]
        $CallbackHeaderFields = @{},

        [hashtable]
        $Permission = @{},

        [switch]
        $NotCancelable

    )
    Begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()

        if ( $Callback.IsPresent) {
            $CallbackInfo = @{
                UrlField     = $CallbackUrl
                ContentType  = $CallbackContentType
                SendResult   = $CallbackSendResult.ToBool()
                Method       = $CallbackMethod
                HeaderFields = $CallbackHeaderFields
            }
        }

        # Set permission hashtable
        if ( $Permission.ContainsKey('Read')) {
            if (! $Permission.Read.ContainsKey('Users')) {
                $Permission.Read['Users'] = @()
            }
        }
        else {
            $Permission['Read'] = @{Users = @() }
        }

        if ( $Permission.ContainsKey('Write')) {
            if (! $Permission.Write.ContainsKey('Users')) {
                $Permission.Write['Users'] = @()
            }
        }
        else {
            $Permission['Write'] = @{Users = @() }
        }

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
            if ( $Callback.IsPresent) {
                if ([string]::IsNullOrEmpty($EventName)) {
                    $CallbackInfo.EventName = $r.Path.Replace('/', '_') + '_Callback'
                }
                else {
                    if ($Route.Count -gt 1) {
                        $CallbackInfo.EventName = "$EventName_$($r.Path.Replace('/', '_'))"
                    }
                    else {
                        $CallbackInfo.EventName = $EventName
                    }
                }
            }
            # Store the route's async task definition in Pode context
            $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName] = @{
                Name           = $r.AsyncPoolName
                Script         = ConvertTo-PodeEnhancedScriptBlock -ScriptBlock $r.Logic
                UsingVariables = $r.UsingVariables
                Arguments      = (Protect-PodeValue -Value $r.Arguments -Default @{})
                CallbackInfo   = $CallbackInfo
                Cancelable     = -not ($NotCancelable.IsPresent)
                Permission     = $Permission
                MinRunspaces   = $MinRunspaces
                MaxRunspaces   = $MaxRunspaces
            }

            #Set thread count
            $PodeContext.Threads.AsyncRoutes += $MaxRunspaces
            if (! $PodeContext.RunspacePools.ContainsKey($r.AsyncPoolName)) {
                $PodeContext.RunspacePools[$r.AsyncPoolName] = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()

                $PodeContext.RunspacePools[$r.AsyncPoolName]['Pool'] = [runspacefactory]::CreateRunspacePool($MinRunspaces, $MaxRunspaces, $PodeContext.RunspaceState, $Host)
                $PodeContext.RunspacePools[$r.AsyncPoolName]['State'] = 'Waiting'

            }
            # Replace the Route logic with this that allow to execute the original logic asynchronously
            $r.logic = Get-PodeAsyncSetScriptBlock

            # Set arguments and clear using variables
            $r.Arguments = (  $Timeout, $AsyncIdGenerator, $r.AsyncPoolName  )
            $r.UsingVariables = $null

            # Add OpenAPI documentation if not excluded
            if (! $NoOpenAPI.IsPresent) {
                Add-PodeAsyncComponentSchema -Name $OATypeName

                $route |
                    Set-PodeOARouteInfo -PassThru |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $ResponseContentType  -Content $OATypeName )
                if ($Callback) {
                    $route |
                        Add-PodeOACallBack -Name $CallbackInfo.EventName -Path $CallbackUrl -Method $CallbackMethod -RequestBody (
                            New-PodeOARequestBody -Content @{ $CallbackContentType = (
                                    New-PodeOAObjectProperty -Name 'Result' |
                                        New-PodeOAStringProperty -Name 'EventName' -Description 'The event name.' |
                                        New-PodeOAStringProperty -Name 'Url' -Format Uri -Example 'http://localhost/callback' |
                                        New-PodeOAStringProperty -Name 'Method' -Example 'Post' |
                                        New-PodeOAObjectProperty
                                    )
                                }
                            ) -Response (
                                New-PodeOAResponse -StatusCode 200 -Description  'Successful operation'
                            )
                }
            }
        }

        # Return the route information if PassThru is specified
        if ($PassThru) {
            return $Route
        }
    }
}