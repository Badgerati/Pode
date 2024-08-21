
<#
.SYNOPSIS
    Adds a route to get the status and details of an asynchronous task in Pode.

.DESCRIPTION
    The `Add-PodeAsyncRouteGet` function creates a route in Pode that allows retrieving the status
    and details of an asynchronous task. This function supports different methods for task Id
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

.PARAMETER In
    Specifies where to retrieve the task Id from. Valid values are 'Cookie', 'Header', 'Path', and
    'Query'. The default is 'Query'.

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
function Add-PodeAsyncRouteGet {
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

        [Parameter()]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In = 'Query',

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
    # Check if a Definition exists
    $oaName = Get-PodeAsyncRouteOAName -Tag $OADefinitionTag

    # Remove any trailing '/'
    $Path = $Path.TrimEnd('/')

    # Append task Id to path if the task Id is in the path
    if ($In -eq 'Path') {
        $Path = "$Path/:$($oaName.TaskIdName)"
    }

    # Define the parameters for the route
    $param = @{
        Method           = 'Get'
        Path             = $Path
        ScriptBlock      = Get-PodeAsyncGetScriptBlock
        ArgumentList     = ($In, $oaName.TaskIdName)
        ErrorContentType = $ResponseContentType[0]
        PassThru         = $true
    }

    # Add optional parameters to the route
    if ($Middleware) {
        $param.Middleware = $Middleware
    }
    if ($EndpointName) {
        $param.EndpointName = $EndpointName
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
    if ($IfExists) {
        $param.IfExists = $IfExists
    }

    # Add the route to Pode
    $route = Add-PodeRoute @param

    # Add OpenAPI documentation postponed script
    $route.OpenApi.Postponed = {
        param($params )
        $r | Set-PodeOARequest -PassThru -Parameters (
            New-PodeOAStringProperty -Name $params.Name.TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $params.In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $params.ResponseContentType -Content $params.Name.OATypeName) -PassThru |
            Add-PodeOAResponse -StatusCode 4XX -Description 'Client error. The request contains bad syntax or cannot be fulfilled.' -Content (
                New-PodeOAContentMediaType -MediaType $params.ResponseContentType -Content (
                    New-PodeOAStringProperty -Name 'Id' -Format Uuid -Required | New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($params.Name.OATypeName)Error"
                ))
    }

    $route.OpenApi.PostponedArgumentList = @{
        Name                = $oaName
        In                  = $In
        ResponseContentType = $ResponseContentType
    }

    # Return the route if PassThru is specified
    if ($PassThru) {
        return $route
    }
}

<#
.SYNOPSIS
    Adds a route to stop an asynchronous task in Pode.

.DESCRIPTION
    The `Add-PodeAsyncRouteStop` function creates a route in Pode that allows the stopping of an
    asynchronous task. This function supports different methods for task Id retrieval (Cookie,
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

.PARAMETER In
    Specifies where to retrieve the task Id from. Valid values are 'Cookie', 'Header', 'Path', and
    'Query'. The default is 'Query'.

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
    # Adding a route to stop an asynchronous task with the task Id in the query string
    Add-PodeAsyncRouteStop -Path '/task/stop' -ResponseType YAML -In Query

.EXAMPLE
    #  Adding a route to stop an asynchronous task with the task Id in the URL path
    Add-PodeAsyncRouteStop -Path '/task/stop' -ResponseType JSON, YAML -In Path
#>

function Add-PodeAsyncRouteStop {
    [CmdletBinding(DefaultParameterSetName = 'OpenAPI')]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
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
        [ValidateSet('application/json', 'application/xml', 'application/yaml')]
        $ResponseContentType = 'application/json',

        [Parameter()]
        [ValidateSet('Cookie', 'Header', 'Path', 'Query')]
        [string]
        $In = 'Query',

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

    # Check if a Definition exists
    $oaName = Get-PodeAsyncRouteOAName -Tag $OADefinitionTag

    # Append task Id to path if the task Id is in the path
    if ($In -eq 'Path') {
        $Path = "$Path/:$($oaName.TaskIdName)"
    }

    # Define the parameters for the route
    $param = @{
        Method           = 'Delete'
        Path             = $Path
        ScriptBlock      = Get-PodeAsyncRouteStopScriptBlock
        ArgumentList     = ($In, $oaName.TaskIdName)
        ErrorContentType = $ResponseContentType[0]
        PassThru         = $true
    }

    # Add optional parameters to the route
    if ($Middleware) {
        $param.Middleware = $Middleware
    }
    if ($EndpointName) {
        $param.EndpointName = $EndpointName
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

    if ($OADefinitionTag) {
        $param.OADefinitionTag = $OADefinitionTag
    }

    # Add the route to Pode
    $route = Add-PodeRoute @param

    # Add OpenAPI documentation postponed script
    $route.OpenApi.Postponed = {
        param($params)
        $r | Set-PodeOARequest -PassThru -Parameters (
            New-PodeOAStringProperty -Name $params.Name.TaskIdName -Format Uuid -Description 'Task Id' -Required | ConvertTo-PodeOAParameter -In $params.In) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $params.ResponseContentType -Content $params.Name.OATypeName) -PassThru |
            Add-PodeOAResponse -StatusCode 4XX -Description 'Client error. The request contains bad syntax or cannot be fulfilled.' -Content (
                New-PodeOAContentMediaType -MediaType $params.ResponseContentType -Content (
                    New-PodeOAStringProperty -Name 'Id' -Format Uuid -Required | New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($params.Name.OATypeName)Error"
                )
            )
    }
    $route.OpenApi.PostponedArgumentList = @{
        Name                = $oaName
        In                  = $In
        ResponseContentType = $ResponseContentType
    }

    # Return the route if PassThru is specified
    if ($PassThru) {
        return $route
    }
}


<#
.SYNOPSIS
    Adds a Pode route for querying task information.

.DESCRIPTION
    The Add-PodeAsyncRouteQuery function creates a Pode route that allows querying task information based on specified parameters.
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
    Add-PodeAsyncRouteQuery -Path '/tasks/query' -ResponseContentType 'application/json' -QueryContentType 'application/json','application/yaml' -Payload 'Body'

    This example creates a Pode route at '/tasks/query' that processes query requests with JSON content types and expects the payload in the body.

.OUTPUTS
    [hashtable]
#>

function Add-PodeAsyncRouteQuery {
    [CmdletBinding()]
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

        [Parameter()]
        [string[]]
        $OADefinitionTag

    )
    # Check if a Definition exists
    $oaName = Get-PodeAsyncRouteOAName -Tag $OADefinitionTag

    # Define the parameters for the route
    $param = @{
        Path             = $Path
        ScriptBlock      = Get-PodeAsyncRouteQueryScriptBlock
        ArgumentList     = @($Payload, ( Test-PodeOADefinitionTag -Tag $Tag))
        ErrorContentType = $ResponseContentType[0]
        ContentType      = $QueryContentType[0]
        PassThru         = $true
    }

    # Add optional parameters to the route
    if ($Middleware) {
        $param.Middleware = $Middleware
    }
    if ($EndpointName) {
        $param.EndpointName = $EndpointName
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

    # Determine the HTTP method based on the payload location
    $param.Method = (@{
            'Body'   = 'Post'
            'Header' = 'Get'
            'Query'  = 'Get'
        })[$Payload]

    # Add the route to Pode
    $route = Add-PodeRoute @param

    # Add OpenAPI documentation postponed script
    $route.OpenApi.Postponed = {
        param($params )
        if (!(Test-PodeOAComponent -Field schemas -Name $params.Name.QueryRequestName )) {

            New-PodeOAStringProperty -Name 'op' -Enum 'GT', 'LT', 'GE', 'LE', 'EQ', 'NE', 'LIKE', 'NOTLIKE' -Required |
                New-PodeOAStringProperty -Name 'value' -Description 'The value to compare against' -Required |
                New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name "String$($params.Name.QueryParameterName)"


            New-PodeOAStringProperty -Name 'op' -Enum   'EQ', 'NE'  -Required |
                New-PodeOAStringProperty -Name 'value' -Description 'The value to compare against' -Required |
                New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name "Boolean$($params.Name.QueryParameterName)"

            New-PodeOAStringProperty -Name 'op' -Enum 'GT', 'LT', 'GE', 'LE', 'EQ', 'NE'  -Required |
                New-PodeOAStringProperty -Name 'value' -format Date-Time -Description 'The value to compare against' -Required |
                New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name "DateTime$($params.Name.QueryParameterName)"


            New-PodeOAStringProperty -Name 'op' -Enum 'GT', 'LT', 'GE', 'LE', 'EQ', 'NE'  -Required |
                New-PodeOANumberProperty -Name 'value' -Description 'The value to compare against' -Required |
                New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name "Number$($params.Name.QueryParameterName)"

            # Define AsyncTaskQueryRequest using pipelining
            New-PodeOASchemaProperty -Name 'Id' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'Name' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'StartingTime' -Reference "DateTime$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'CreationTime' -Reference "DateTime$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'CompletedTime' -Reference "DateTime$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'ExpireTime' -Reference "DateTime$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'State' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'Error' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'CallbackSettings' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'Cancellable' -Reference "Boolean$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'SseEnabled' -Reference "Boolean$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'SseGroup' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'User' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'Url' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'Method' -Reference "String$($params.Name.QueryParameterName)" |
                New-PodeOASchemaProperty -Name 'Progress' -Reference "Number$($params.Name.QueryParameterName)" |
                New-PodeOAObjectProperty |
                Add-PodeOAComponentSchema -Name $params.Name.QueryRequestName
        }

        # Define an example hashtable for the OpenAPI request
        $exampleHashTable = @{
            'StartingTime' = @{
                op    = 'GT'
                value = (Get-Date '2024-07-05T20:20:00Z')
            }
            'CreationTime' = @{
                op    = 'LE'
                value = (Get-Date '2024-07-05T20:20:00Z')
            }
            'State'        = @{
                op    = 'EQ'
                value = 'Completed'
            }
            'Name'         = @{
                op    = 'LIKE'
                value = 'Get'
            }
            'Id'           = @{
                op    = 'EQ'
                value = 'b143660f-ebeb-49d9-9f92-cd21f3ff559c'
            }
            'Cancellable'  = @{
                op    = 'EQ'
                value = $true
            }
        }

        # Add OpenAPI route information and responses
        $r |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType $params.ResponseContentType -Content $params.Name.OATypeName -Array) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid filter supplied' -Content (
                New-PodeOAContentMediaType -MediaType $params.ResponseContentType -Content (
                    New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($params.Name.OATypeName)Error"
                )
            ) -PassThru | Add-PodeOAResponse -StatusCode 500 -Content (
                New-PodeOAContentMediaType -MediaType $params.ResponseContentType -Content (
                    New-PodeOAStringProperty -Name 'Error' -Required | New-PodeOAObjectProperty -XmlName "$($params.Name.OATypeName)Error"
                )
            )


        # Define examples for different media types
        $example = [ordered]@{}
        foreach ($mt in $params.QueryContentType) {
            $example += New-PodeOAExample -MediaType $mt -Name $params.Name.QueryRequestName -Value $exampleHashTable
        }

        # Set the OpenAPI request based on the payload location
        switch ($params.Payload.ToLowerInvariant()) {
            'body' {
                $r | Set-PodeOARequest -RequestBody (
                    New-PodeOARequestBody -Content (New-PodeOAContentMediaType -MediaType $params.QueryContentType -Content $params.Name.QueryRequestName) -Examples $example
                )
            }
            'header' {
                $r | Set-PodeOARequest -Parameters (ConvertTo-PodeOAParameter -In Header -Schema $params.Name.QueryRequestName -ContentType $params.QueryContentType[0] -Example $example[0])
            }
            'query' {
                $r | Set-PodeOARequest -Parameters (ConvertTo-PodeOAParameter -In Query -Schema $params.Name.QueryRequestName -ContentType $params.QueryContentType[0] -Example $example[0])
            }
        }
    }

    $route.OpenApi.PostponedArgumentList = @{
        Name                = $oaName
        In                  = $In
        ResponseContentType = $ResponseContentType
        QueryContentType    = $QueryContentType
        Payload             = $Payload
    }

    # Return the route if PassThru is specified
    if ($PassThru) {
        return $route
    }
}
<#
.SYNOPSIS
    Assigns or removes permissions to/from an asynchronous route in Pode based on specified criteria such as users, groups, roles, and scopes.

.DESCRIPTION
    The `Set-PodeAsyncRoutePermission` function allows you to define and assign or remove specific permissions to/from an async route.
    You can control access to the route by specifying which users, groups, roles, or scopes have `Read` or `Write` permissions.

.PARAMETER Route
    A hashtable array representing the async route(s) to which permissions will be assigned or from which they will be removed. This parameter is mandatory.

.PARAMETER Type
    Specifies the type of permission to assign or remove. Acceptable values are 'Read' or 'Write'. This parameter is mandatory.

.PARAMETER Groups
    Specifies the groups that will be granted or removed from the specified permission type.

.PARAMETER Users
    Specifies the users that will be granted or removed from the specified permission type.

.PARAMETER Roles
    Specifies the roles that will be granted or removed from the specified permission type.

.PARAMETER Scopes
    Specifies the scopes that will be granted or removed from the specified permission type.

.PARAMETER Remove
    If specified, the function will remove the specified users, groups, roles, or scopes from the permissions instead of adding them.

.PARAMETER PassThru
    If specified, the function will return the modified route object(s) after assigning or removing permissions.

.EXAMPLE
    Add-PodeRoute -PassThru -Method Put -Path '/asyncState' -Authentication 'Validate' -Group 'Support' `
    -ScriptBlock {
        $data = Get-PodeState -Name 'data'
        Write-PodeHost 'data:'
        Write-PodeHost $data -Explode -ShowType
        Start-Sleep $data.sleepTime
        return @{ InnerValue = $data.Message }
    } | Set-PodeAsyncRoute `
        -ResponseContentType 'application/json', 'application/yaml' -Timeout 300 -PassThru |
        Set-PodeAsyncRoutePermission -Type Read -Groups 'Developer'

    This example creates an async route that requires authentication and assigns 'Read' permission to the 'Developer' group.

.EXAMPLE
    # Removing 'Developer' group from Read permissions
    Set-PodeAsyncRoutePermission -Route $route -Type Read -Groups 'Developer' -Remove

    This example removes the 'Developer' group from the 'Read' permissions of the specified async route.

.OUTPUTS
    [hashtable]
#>
function Set-PodeAsyncRoutePermission {
    param(
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [ValidateSet('Read', 'Write')]
        [string]
        $Type,

        [Parameter()]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users,

        [Parameter()]
        [string[]]
        $Roles,

        [Parameter()]
        [string[]]
        $Scopes,

        [switch]
        $Remove,

        [switch]
        $PassThru
    )

    Begin {
        $pipelineValue = @()
    }

    Process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    End {
        # Helper function to add or remove items from a permission list
        function Update-PermissionList {
            param (
                [Parameter(Mandatory = $true)]
                [AllowEmptyCollection()]
                [string[]]$List,

                [string[]]$Items,

                [switch]$Remove
            )
            # Initialize $List if it's null
            if (! $List) {
                $List = @()
            }

            if ($Remove) {
                return $List | Where-Object { $_ -notin $Items }
            }
            else {
                return $List + $Items
            }
        }

        # Handle multiple piped-in routes
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }

        # Validate that the Route parameter is not null
        if ($null -eq $Route) {
            # The parameter 'Route' cannot be null
            throw ($PodeLocale.routeParameterCannotBeNullExceptionMessage)
        }

        foreach ($r in $Route) {
            # Check if the route is marked as an Async Route
            if (! $PodeContext.AsyncRoutes.Items.ContainsKey($r.AsyncPoolName) -or ! $r.IsAsync) {
                # The route '{0}' is not marked as an Async Route.
                throw ($PodeLocale.routeNotMarkedAsAsyncExceptionMessage -f $r.Path)
            }

            # Initialize the permission type hashtable if not already present
            if (! $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission.ContainsKey($Type)) {
                $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type] = @{}
            }

            # Assign or remove users from the specified permission type
            if ($Users) {
                if (!$PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].ContainsKey('Users')) {
                    $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Users = @()
                }
                $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Users = Update-PermissionList -List $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Users -Items $Users -Remove:$Remove
            }

            # Assign or remove groups from the specified permission type
            if ($Groups) {
                if (!$PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].ContainsKey('Groups')) {
                    $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Groups = @()
                }
                $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Groups = Update-PermissionList -List $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Groups -Items $Groups -Remove:$Remove
            }

            # Assign or remove roles from the specified permission type
            if ($Roles) {
                if (!$PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].ContainsKey('Roles')) {
                    $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Roles = @()
                }
                $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Roles = Update-PermissionList -List $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Roles -Items $Roles -Remove:$Remove
            }

            # Assign or remove scopes from the specified permission type
            if ($Scopes) {
                if (!$PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].ContainsKey('Scopes')) {
                    $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Scopes = @()
                }
                $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Scopes = Update-PermissionList -List $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].Permission[$Type].Scopes -Items $Scopes -Remove:$Remove
            }
        }

        # Return the route object(s) if PassThru is specified
        if ($PassThru) {
            return $Route
        }
    }
}



<#
.SYNOPSIS
    Adds a callback to an asynchronous route in Pode.

.DESCRIPTION
    The Add-PodeAsyncRouteCallback function allows you to attach a callback to an existing asynchronous route in Pode.
    This function takes various parameters to configure the callback URL, method, headers, and more.

.PARAMETER Route
    The route(s) to which the callback should be added. This parameter is mandatory and accepts hashtable arrays.

.PARAMETER CallbackUrl
    Specifies the URL field for the callback. Default is '$request.body#/callbackUrl'.
    Can accept the following meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl
    Can accept static values for example:
    - 'http://example.com/callback'
    - 'https://api.example.com/callback

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
    Can accept static values for example:
    - 'application/json'
    - 'application/xml'
    - 'text/plain'

.PARAMETER CallbackMethod
    Specifies the HTTP method for the callback. The default is 'Post'.
    Can accept the following meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl
    Can accept static values for example:
    - `GET`
    - `POST`
    - `PUT`
    - `DELETE`
.PARAMETER CallbackHeaderFields
    Specifies the header fields for the callback as a hashtable. The key can be a string representing
    the header key or one of the meta values. The value is the header value if it's a standard key or
    the default value if the meta value is not resolvable.
    Can accept the following meta values as keys:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl
    Can accept static values for example:
    - `@{ 'Content-Type' = 'application/json' }`
    - `@{ 'Authorization' = 'Bearer token' }`
    - `@{ 'Custom-Header' = 'value' }`

.PARAMETER PassThru
    If specified, the route information is returned.

.EXAMPLE
      Add-PodeRoute -PassThru -Method Put -Path '/example' |
      Add-PodeAsyncRouteCallback -Route $route -CallbackUrl '$request.body#/callbackUrl'

.NOTES
    This function should only be used with routes that have been marked as asynchronous using the Set-PodeAsyncRoute function.

.NOTES
    The parameters CallbackHeaderFields, CallbackMethod, CallbackContentType, and CallbackUrl can accept these meta values:
    - $request.query.param-name  : query-param-value
    - $request.header.header-name: application/json
    - $request.body#/field-name  : callbackUrl
#>
function  Add-PodeAsyncRouteCallback {
    param (
        [Parameter(Mandatory = $true , ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [string]
        $CallbackUrl = '$request.body#/callbackUrl',

        [Parameter()]
        [switch]
        $CallbackSendResult,

        [Parameter()]
        [string]
        $EventName,

        [Parameter()]
        [string]
        $CallbackContentType = 'application/json',

        [Parameter()]
        [string]
        $CallbackMethod = 'Post',

        [Parameter()]
        [hashtable]
        $CallbackHeaderFields = @{},

        [switch]
        $PassThru
    )

    Begin {
        $pipelineValue = @()
        $CallbackSettings = @{
            UrlField     = $CallbackUrl
            ContentType  = $CallbackContentType
            SendResult   = $CallbackSendResult.ToBool()
            Method       = $CallbackMethod
            HeaderFields = $CallbackHeaderFields
        }
    }

    Process {
        # Add the current piped-in value to the array
        $pipelineValue += $_
    }

    End {
        # Handle multiple piped-in routes
        if ($pipelineValue.Count -gt 1) {
            $Route = $pipelineValue
        }

        # Validate that the Route parameter is not null
        if ($null -eq $Route) {
            # The parameter 'Route' cannot be null
            throw ($PodeLocale.routeParameterCannotBeNullExceptionMessage)
        }

        foreach ($r in $Route) {
            # Check if the route is marked as an Async Route
            if (! $PodeContext.AsyncRoutes.Items.ContainsKey($r.AsyncPoolName) -or ! $r.IsAsync) {
                # The route '{0}' is not marked as an Async Route.
                throw ($PodeLocale.routeNotMarkedAsAsyncExceptionMessage -f $r.Path)
            }

            # Generate or use the provided event name for the callback
            if ([string]::IsNullOrEmpty($EventName)) {
                $CallbackSettings.EventName = $r.Path.Replace('/', '_') + '_Callback'
            }
            else {
                if ($Route.Count -gt 1) {
                    $CallbackSettings.EventName = "$EventName_$($r.Path.Replace('/', '_'))"
                }
                else {
                    $CallbackSettings.EventName = $EventName
                }
            }

            # Attach the callback settings to the Async Route
            $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName].CallbackSettings = $CallbackSettings

            # Add OpenAPI callback documentation if applicable
            if ( $r.OpenApi.Swagger) {
                $r |
                    Add-PodeOACallBack -Name $CallbackSettings.EventName -Path $CallbackUrl -Method $CallbackMethod -DefinitionTag $r.OpenApi.DefinitionTag -RequestBody (
                        New-PodeOARequestBody -Content @{ $CallbackContentType = (
                                New-PodeOAObjectProperty -Name 'Result' |
                                    New-PodeOAStringProperty -Name 'EventName' -Description 'The event name.' -Required |
                                    New-PodeOAStringProperty -Name 'Url' -Format Uri -Example 'http://localhost/callback' -Required |
                                    New-PodeOAStringProperty -Name 'Method' -Example 'Post' -Required |
                                    New-PodeOAStringProperty -Name 'State' -Description 'The parent async route task status' -Required -Example 'Complete' -Enum @('NotStarted', 'Running', 'Failed', 'Completed', 'Aborted') |
                                    New-PodeOAObjectProperty -Name 'Result' -Description 'The parent result' -NoProperties |
                                    New-PodeOAStringProperty -Name 'Error' -Description 'The parent error' |
                                    New-PodeOAObjectProperty
                                )
                            }
                        ) -Response (
                            New-PodeOAResponse -StatusCode 200 -Description  'Successful operation'
                        )
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
    Defines an asynchronous route in Pode with runspace management.

.DESCRIPTION
    The `Set-PodeAsyncRoute` function enables you to define routes in Pode that execute asynchronously,
    leveraging runspace management for non-blocking operation. This function allows you to specify
    response types (JSON, XML, YAML) and manage asynchronous task parameters such as timeout and
    unique Id generation. It supports the use of arguments, `$using` variables, and state variables.

.PARAMETER Route
    A hashtable array that contains route definitions. Each hashtable should include
    the `Method`, `Path`, and `Logic` keys at a minimum.

.PARAMETER ResponseContentType
    Specifies the response type(s) for the route. Valid values are 'application/json' , 'application/xml', 'application/yaml'.
    You can specify multiple types. The default is 'application/json'.

.PARAMETER Timeout
    Defines the timeout period for the asynchronous task in seconds.
    The default value is 28800 (8 hours).
    -1 indicating no timeout.

.PARAMETER IdGenerator
    A custom ScriptBlock to generate a random unique Ids for asynchronous route tasks. The default
    is '{ return New-PodeGuid }'.

.PARAMETER PassThru
    If specified, the function returns the route information after processing.

.PARAMETER MaxRunspaces
    The maximum number of Runspaces that can exist in this route. The default is 2.

.PARAMETER MinRunspaces
    The minimum number of Runspaces that exist in this route. The default is 1.

.PARAMETER NotCancellable
    The async route task cannot be forcefully terminated

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

#>
function Set-PodeAsyncRoute {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [string[]]
        [ValidateSet('application/json' , 'application/xml', 'application/yaml')]
        $ResponseContentType = 'application/json',

        [Parameter()]
        [int]
        $Timeout = 28800,

        [Parameter()]
        [scriptblock]
        $IdGenerator,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $MaxRunspaces = 2,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $MinRunspaces = 1,

        [Parameter()]
        [switch]
        $NotCancellable

    )
    Begin {

        # Initialize an array to hold piped-in values
        $pipelineValue = @()

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

        if ($null -eq $Route) {
            # The parameter 'Route' cannot be null
            throw ($PodeLocale.routeParameterCannotBeNullExceptionMessage)
        }

        foreach ($r in $Route) {
            # Check if the route is already marked as an Async Route
            if ( $PodeContext.AsyncRoutes.Items.ContainsKey($r.AsyncPoolName) -or $r.IsAsync) {
                # The function cannot be invoked multiple times for the same route
                throw ($PodeLocale.functionCannotBeInvokedMultipleTimesExceptionMessage -f $MyInvocation.MyCommand.Name, $r.Path)
            }

            # Validates $r.Logic for disallowed Pode commands
            Test-PodeAsyncRouteScriptblockInvalidCommand -ScriptBlock $r.Logic

            # Set the Route as Async
            $r.IsAsync = $true

            # Assign the Id generator
            if ($IdGenerator) {
                $r.AsyncRouteTaskIdGenerator = $IdGenerator
            }
            else {
                $r.AsyncRouteTaskIdGenerator = { return (New-PodeGuid) }
            }

            # Store the route's async route task definition in Pode context
            $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName] = @{
                Name             = $r.AsyncPoolName
                Script           = Get-PodeAsyncRouteScriptblock -ScriptBlock $r.Logic
                UsingVariables   = $r.UsingVariables
                Arguments        = (Protect-PodeValue -Value $r.Arguments -Default @{})
                CallbackSettings = $null
                Cancellable      = !($NotCancellable.IsPresent)
                MinRunspaces     = $MinRunspaces
                MaxRunspaces     = $MaxRunspaces
                Timeout          = $Timeout
                Permission       = @{}
            }

            #Set thread count
            $PodeContext.Threads.AsyncRoutes += $MaxRunspaces
            if (! $PodeContext.RunspacePools.ContainsKey($r.AsyncPoolName)) {
                $PodeContext.RunspacePools[$r.AsyncPoolName] = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()

                $PodeContext.RunspacePools[$r.AsyncPoolName]['Pool'] = New-PodeRunspacePoolNetWrapper -MinRunspaces $MinRunspaces -MaxRunspaces $MaxRunspaces -RunspaceState $PodeContext.RunspaceState
                $PodeContext.RunspacePools[$r.AsyncPoolName]['State'] = 'Waiting'

            }
            # Replace the Route logic with this that allow to execute the original logic asynchronously
            $r.logic = Get-PodeAsyncRouteSetScriptBlock

            # Set arguments and clear using variables
            $r.Arguments = @()
            $r.UsingVariables = $null

            # Add OpenAPI documentation if not excluded
            if ( $r.OpenApi.Swagger) {
                $oaName = Get-PodeAsyncRouteOAName -Tag $r.OpenApi.DefinitionTag -ForEachOADefinition
                foreach ($key in $oaName.Keys) {
                    Add-PodeAsyncRouteComponentSchema -Name $oaName[$key].oATypeName -DefinitionTag $key
                    $r |
                        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' `
                            -DefinitionTag $key `
                            -Content (New-PodeOAContentMediaType -MediaType $ResponseContentType  -Content $oaName[$key].OATypeName )
                }
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
    Adds a Server-Sent Events (SSE) route to an existing Pode async route.

.DESCRIPTION
    The `Add-PodeAsyncRouteSse` function registers a new SSE route associated with an existing Pode async route.
    This allows the server to push updates to the client for the specified route.
    The function accepts a hashtable array of routes and sets up the SSE route for each. The response content type can be specified, and you can choose to pass through the modified route object with the `-PassThru` switch.

    The function also ensures that the specified routes are marked as async routes. If a route is not marked as async, an exception will be thrown.

.PARAMETER Route
    A hashtable array representing the route(s) to which the SSE route will be added.
    This parameter is mandatory and supports pipeline input. Each route must be marked as an async route, or an exception will be thrown.

.PARAMETER PassThru
    If specified, the function will return the route object after adding the SSE route.

.PARAMETER SseGroup
    Specifies the group for the SSE connection. If not provided, the group will be set to the path of the route.

.OUTPUTS
    Hashtable[]

.NOTES
    The function creates a new route with the `_events` suffix appended to the original route's path.
    The new route handles SSE connections and manages the async results from the original route.

    If the route is not marked as an async route, an exception will be thrown.

.EXAMPLE
    Add-PodeRoute -PassThru -Method Get -Path '/events' -ScriptBlock {
        return @{'message' = 'Done' }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json' -MaxRunspaces 2 -PassThru  |
        Add-PodeAsyncRouteSse -SseGroup 'Test events'

    This example demonstrates creating a new GET route at the path '/events' and setting it as an async route with a maximum of 2 runspaces. The async route is enabled for Server-Sent Events (SSE) and is grouped under 'Test events'.
    The `Add-PodeAsyncRouteSse` function is then used to add an SSE route to the async route, ensuring that updates from the server are pushed to the client.
#>
function Add-PodeAsyncRouteSse {
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [switch]
        $PassThru,

        [Parameter()]
        [string]
        $SseGroup
    )

    Begin {
        # Initialize an array to hold piped-in values
        $pipelineValue = @()

        $sseScriptBlock = {
            param($SseGroup)

            if ([string]::IsNullOrEmpty($SseGroup)) {
                write-podehost "webEvent.Route.Path=$($webEvent.Route.Path)"
                ConvertTo-PodeSseConnection -Name $webEvent.Route.Path -Scope Local -Group $SseGroup
            }
            else {
                ConvertTo-PodeSseConnection -Name $webEvent.Route.Path -Scope Local
            }

            $id = $WebEvent.Query['Id']
            if (!$PodeContext.AsyncRoutes.Results.ContainsKey($id)) {
                try {
                    throw ($PodeLocale.asyncIdDoesNotExistExceptionMessage -f $id)
                }
                catch {
                    # Log the error
                    $_ | Write-PodeErrorLog
                    return
                }
            }
            $AsyncResult = $PodeContext.AsyncRoutes.Results[$Id]

            $AsyncResult['Sse']['State'] = 'Waiting'

            while (!$AsyncResult['Runspace'].Handler.IsCompleted) {
                start-sleep 1
            }

            try {
                switch ($AsyncResult['State']) {
                    'Failed' {
                        $null = Send-PodeSseEvent -FromEvent -Data @{ State = $AsyncResult['State']; Error = $AsyncResult['Error'] }
                    }
                    'Completed' {
                        if ($AsyncResult['Result']) {
                            $null = Send-PodeSseEvent -FromEvent -Data @{ State = $AsyncResult['State']; Result = $AsyncResult['Result'] }
                        }
                        else {
                            $null = Send-PodeSseEvent -FromEvent -Data @{ State = 'Completed' }
                        }
                    }
                    'Aborted' {
                        $null = Send-PodeSseEvent -FromEvent -Data @{ State = $AsyncResult['State']; Error = $AsyncResult['Error'] }
                    }
                }
                $AsyncResult['Sse']['State'] = 'Completed'
            }
            catch {
                # Log any errors encountered during SSE handling
                $_ | Write-PodeErrorLog
                $AsyncResult['Sse']['State'] = 'Failed'
            }

        }
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

        if ($null -eq $Route) {
            # The parameter 'Route' cannot be null
            throw ($PodeLocale.routeParameterCannotBeNullExceptionMessage)
        }

        foreach ($r in $Route) {
            # Check if the route is marked as an Async Route
            if (! $PodeContext.AsyncRoutes.Items.ContainsKey($r.AsyncPoolName) -or ! $r.IsAsync) {
                # The route '{0}' is not marked as an Async Route.
                throw ($PodeLocale.routeNotMarkedAsAsyncExceptionMessage -f $r.Path)
            }

            $sseRoute = Add-PodeRoute -PassThru -method Get -Path "$($r.Path)_events" -ArgumentList $SseGroup `
                -ScriptBlock $sseScriptBlock

            $PodeContext.AsyncRoutes.Items[$r.AsyncPoolName]['Sse'] = @{
                Group = $SseGroup
                Name  = "$($r.Path)_events"
                Route = $sseRoute
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
    Retrieves asynchronous Pode route operations based on specified query conditions.

.DESCRIPTION
    The   Get-PodeAsyncRouteOperationByFilter function acts as a public interface for searching asynchronous Pode route operations.
    It utilizes the Search-PodeAsyncRouteTask function to perform the search based on the specified query conditions.

.PARAMETER Filter
    A hashtable containing the query conditions. Each key in the hashtable represents a field to search on,
    and the value is another hashtable containing 'op' (operator) and 'value' (comparison value).

.PARAMETER Raw
    If specified, returns the raw [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] without any formatting.

.EXAMPLE
    $filter = @{
        'State' = @{ 'op' = 'EQ'; 'value' = 'Running' }
        'CreationTime' = @{ 'op' = 'GT'; 'value' = (Get-Date).AddHours(-1) }
    }
    $results =   Get-PodeAsyncRouteOperationByFilter -Filter $filter

    This example retrieves route operations that are in the 'Running' state and were created within the last hour.

.OUTPUTS
    Returns an array of hashtables or [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] representing the matched route operations.
#>
function   Get-PodeAsyncRouteOperationByFilter {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Filter,

        [switch]
        $Raw
    )
    $async = Search-PodeAsyncRouteTask -Query $Filter
    if ($async -is [System.Object[]]) {
        $result = @()
        foreach ($item in $async) {
            $result += Export-PodeAsyncRouteInfo -Raw:$Raw -Async $item
        }
    }
    else {
        $result = Export-PodeAsyncRouteInfo -Raw:$Raw -Async $async
    }
    return $result
}

<#
.SYNOPSIS
    Retrieves and filters async routes from Pode's async route context.

.DESCRIPTION
    The `Get-PodeAsyncRouteOperation` function allows you to filter Pode async routes based on the `Id` and `Name` properties.
    If either `Id` or `Name` is not specified (or `$null`), those fields will not be used for filtering.
    The filtered results can be optionally exported in raw format using the `-Raw` switch.

.PARAMETER Id
    The unique identifier of the async route to filter on.
    If not specified or `$null`, this parameter is ignored.

.PARAMETER Name
    The name of the async route to filter on.
    If not specified or `$null`, this parameter is ignored.

.PARAMETER Raw
    A switch that, if specified, exports the results in raw format.

.EXAMPLE
    Get-PodeAsyncRouteOperation -Id "12345" -Raw

    Retrieves the async route with the Id "12345" and exports it in raw format.

.EXAMPLE
    Get-PodeAsyncRouteOperation -Name "RouteName"

    Retrieves the async routes with the name "RouteName".
#>

function Get-PodeAsyncRouteOperation {
    param (
        [Parameter()]
        [string]
        $Id,

        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [switch]
        $Raw
    )

    # Filter the async routes based on Id and Name
    if (![string]::IsNullOrEmpty($Id)) {
        $result = $PodeContext.AsyncRoutes.Results[$Id]
    }
    elseif (! [string]::IsNullOrEmpty($Name)) {
        foreach ($key in $PodeContext.AsyncRoutes.Results.Keys) {
            if ($PodeContext.AsyncRoutes.Results[$key]['Name'] -ieq $Name) {
                $result = $PodeContext.AsyncRoutes.Results[$key]
                break
            }
        }
    }
    else {
        $result = $PodeContext.AsyncRoutes.Results
    }

    if ($null -eq $result) {
        return $null
    }

    # If the -Raw switch is specified, return the filtered results directly
    if ($Raw) {
        return $result
    }

    if ([string]::IsNullOrEmpty($Id) -and [string]::IsNullOrEmpty($Name)) {
        # Otherwise, process each item in the filtered results through Export-PodeAsyncRouteInfo
        $export = @()
        foreach ($item in $result.Values) {
            $export += Export-PodeAsyncRouteInfo  -Async $item
        }
    }
    else {
        $export = Export-PodeAsyncRouteInfo  -Async $result
    }
    # Return the processed export result
    return $export
}


<#
.SYNOPSIS
    Aborts a specific asynchronous Pode route operation by its Id.

.DESCRIPTION
    The Stop-PodeAsyncRouteOperation function stops an asynchronous Pode route operation based on the provided Id.
    It sets the operation's state to 'Aborted', records an error message, and marks the completion time.
    The function then disposes of the associated runspace pipeline and calls Complete-PodeAsyncRouteOperation to finalize the operation.
    If the operation does not exist, it throws an exception with an appropriate error message.

.PARAMETER Id
    A string representing the Id (typically a UUID) of the asynchronous route operation to abort. This parameter is mandatory.

.PARAMETER Raw
    If specified, returns the raw [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]] without any formatting.

.EXAMPLE
    $operationId = '123e4567-e89b-12d3-a456-426614174000'
    $operationDetails = Stop-PodeAsyncRouteOperation -Id $operationId

    This example aborts the asynchronous route operation with the Id '123e4567-e89b-12d3-a456-426614174000' and retrieves the updated operation details.

.OUTPUTS
    Returns a hashtable representing the detailed information of the aborted asynchronous route operation.
#>
function Stop-PodeAsyncRouteOperation {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Id,

        [switch]
        $Raw
    )
    if ($PodeContext.AsyncRoutes.Results.ContainsKey($Id )) {
        $async = $PodeContext.AsyncRoutes.Results[$Id]
        $async['State'] = 'Aborted'
        $async['Error'] = 'Aborted by System'
        $async['CompletedTime'] = [datetime]::UtcNow
        $async['Runspace'].Pipeline.Dispose()
        Complete-PodeAsyncRouteOperation -AsyncResult $async
        return  Export-PodeAsyncRouteInfo -Async $async -Raw:$Raw
    }
    throw ($PodeLocale.asyncRouteOperationDoesNotExistExceptionMessage -f $Id)
}

<#
.SYNOPSIS
    Checks if a specific asynchronous Pode route operation exists by its Id.

.DESCRIPTION
    The Test-PodeAsyncRouteOperation function checks the Pode context to determine if an asynchronous route operation with the specified Id exists.
    It returns a boolean value indicating whether the operation is present in the Pode context.

.PARAMETER Id
    A string representing the Id (typically a UUID) of the asynchronous route operation to check. This parameter is mandatory.

.EXAMPLE
    $operationId = '123e4567-e89b-12d3-a456-426614174000'
    $exists = Test-PodeAsyncRouteOperation -Id $operationId

    This example checks if the asynchronous route operation with the Id '123e4567-e89b-12d3-a456-426614174000' exists and returns true or false.

.OUTPUTS
    Returns a boolean value:
    - $true if the asynchronous route operation exists.
    - $false if the asynchronous route operation does not exist.
#>
function Test-PodeAsyncRouteOperation {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Id
    )
    return ($PodeContext.AsyncRoutes.Results.ContainsKey($Id ))
}


<#
.SYNOPSIS
    Manages the progress of an asynchronous task within Pode routes.

.DESCRIPTION
    This function updates the progress of an asynchronous task in Pode. It supports different parameter sets:
    - StartEnd: Defines progress between a start and end value.
    - Tick: Increments the progress by a predefined tick value.
    - TimeBased: Updates progress based on a specified duration and interval.
    - SetValue: Allows setting the progress to a specific value.

.PARAMETER Start
    The start value for progress calculation (used in StartEnd parameter set).

.PARAMETER End
    The end value for progress calculation (used in StartEnd parameter set).

.PARAMETER Steps
    The number of steps between the start and end values (used in StartEnd parameter set).

.PARAMETER MaxProgress
    The maximum progress value (default is 100).

.PARAMETER Tick
    A switch to increment the progress by the predefined tick value.

.PARAMETER UseDecimalProgress
    A switch to use decimal values for progress.

.PARAMETER IntervalSeconds
    The interval in seconds for time-based progress updates (default is 5 seconds).

.PARAMETER DurationSeconds
    The total duration in seconds for time-based progress updates.

.PARAMETER Value
    The value to set the progress to (used in SetValue parameter set).

.EXAMPLE
    Set-PodeAsyncRouteProgress -Start 0 -End 100 -Steps 10 -MaxProgress 100

.EXAMPLE
    Set-PodeAsyncRouteProgress -Tick

.EXAMPLE
    Set-PodeAsyncRouteProgress -IntervalSeconds 5 -DurationSeconds 300 -MaxProgress 100

.EXAMPLE
    Set-PodeAsyncRouteProgress -Value 50

.NOTES
    This function can only be used inside an Async Route Scriptblock in Pode.
#>
function Set-PodeAsyncRouteProgress {
    [CmdletBinding(DefaultParameterSetName = 'StartEnd')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'StartEnd')]
        [double] $Start,

        [Parameter(Mandatory = $true, ParameterSetName = 'StartEnd')]
        [double] $End,

        [Parameter(ParameterSetName = 'StartEnd')]
        [double] $Steps = 1,

        [Parameter(ParameterSetName = 'TimeBased')]
        [Parameter(ParameterSetName = 'StartEnd')]
        [ValidateRange(1, 100)]
        [double] $MaxProgress = 100,

        [Parameter(Mandatory = $true, ParameterSetName = 'Tick')]
        [switch] $Tick,

        [Parameter(ParameterSetName = 'TimeBased')]
        [Parameter(ParameterSetName = 'StartEnd')]
        [Parameter(ParameterSetName = 'SetValue')]
        [switch] $UseDecimalProgress,

        [Parameter(ParameterSetName = 'TimeBased')]
        [int] $IntervalSeconds = 5,

        [Parameter(Mandatory = $true, ParameterSetName = 'TimeBased')]
        [int] $DurationSeconds,

        [Parameter(Mandatory = $true, ParameterSetName = 'SetValue')]
        [double] $Value
    )

    # Ensure this function is used within an async route
    if (!$___async___id___) {
        # Set-PodeAsyncRouteProgress can only be used inside an Async Route Scriptblock.
        throw $PodeLocale.setPodeAsyncProgressExceptionMessage
    }
    $asyncResult = $PodeContext.AsyncRoutes.Results[$___async___id___]

    # Initialize progress if not already set, for non-tick operations
    if ($PSCmdlet.ParameterSetName -ne 'Tick' -and $PSCmdlet.ParameterSetName -ne 'SetValue') {
        if (!$asyncResult.ContainsKey('Progress')) {
            if ( $UseDecimalProgress.IsPresent) {
                $asyncResult['Progress'] = [double] 0
            }
            else {
                $asyncResult['Progress'] = [int] 0
            }
        }

        if ($MaxProgress -le $asyncResult['Progress']) {
            # A Progress limit cannot be lower than the current progress.
            throw $PodeLocale.progressLimitLowerThanCurrentExceptionMessage
        }
    }

    switch ($PSCmdlet.ParameterSetName) {
        'StartEnd' {
            # Calculate total ticks and tick to progress ratio
            $totalTicks = [math]::ceiling(($End - $Start) / $Steps)
            if ($asyncResult['Progress'] -is [double]) {
                $asyncResult['TickToProgress'] = ($MaxProgress - $asyncResult['Progress']) / $totalTicks
            }
            else {
                $asyncResult['TickToProgress'] = [Math]::Floor(($MaxProgress - $asyncResult['Progress']) / $totalTicks)
            }
        }
        'Tick' {
            # Increment progress by TickToProgress value
            $asyncResult['Progress'] = $asyncResult['Progress'] + $asyncResult['TickToProgress']

            # Ensure Progress does not exceed the specified limit
            if ($asyncResult['Progress'] -ge $MaxProgress) {
                if ($asyncResult['Progress'] -is [double]) {
                    $asyncResult['Progress'] = $MaxProgress - 0.01
                }
                else {
                    $asyncResult['Progress'] = $MaxProgress - 1
                }
            }
        }
        'TimeBased' {
            # Calculate tick interval and progress increment per tick
            $totalTicks = [math]::ceiling($DurationSeconds / $IntervalSeconds)
            if ($asyncResult['Progress'] -is [double]) {
                $asyncResult['TickToProgress'] = ($MaxProgress - $asyncResult['Progress']) / $totalTicks
            }
            else {
                $asyncResult['TickToProgress'] = [Math]::Floor(($MaxProgress - $asyncResult['Progress']) / $totalTicks)
            }

            # Start the scheduler
            $asyncResult['eventName'] = "TimerEvent_$___async___id___"
            $asyncResult['Timer'] = [System.Timers.Timer]::new()
            $asyncResult['Timer'].Interval = $IntervalSeconds * 1000
            $null = Register-ObjectEvent -InputObject $asyncResult['Timer'] -EventName Elapsed -SourceIdentifier  $asyncResult['eventName'] -MessageData @{AsyncResult = $asyncResult; MaxProgress = $MaxProgress } -Action {
                $asyncResult = $Event.MessageData.AsyncResult
                $MaxProgress = $Event.MessageData.MaxProgress

                # Increment progress by TickToProgress value
                $asyncResult['Progress'] = $asyncResult['Progress'] + $asyncResult['TickToProgress']

                # Check if progress has reached or exceeded MaxProgress
                if ($asyncResult['Progress'] -gt $MaxProgress) {
                    # Closes and disposes of the timer
                    Close-PodeAsyncRouteTimer -Operation  $asyncResult

                    if ($asyncResult['Progress'] -is [double]) {
                        $asyncResult['Progress'] = $MaxProgress - 0.01
                    }
                    else {
                        $asyncResult['Progress'] = $MaxProgress - 1
                    }
                }
            }
            $asyncResult['Timer'].Enabled = $true
        }
        'SetValue' {
            if ( $UseDecimalProgress.IsPresent -or ($Value % 1 -ne 0) ) {
                $asyncResult['Progress'] = $Value
            }
            else {
                $asyncResult['Progress'] = [int]$Value
            }
        }
    }
}


<#
.SYNOPSIS
    Retrieves the current progress of an asynchronous route in Pode.

.DESCRIPTION
    The `Get-PodeAsyncRouteProgress` function returns the current progress of an asynchronous route in Pode.
    It retrieves the progress based on the asynchronous route ID (`$___async___id___`).
    If called outside of an asynchronous route script block, an error is thrown.

.EXAMPLE
    # Example usage inside an async route scriptblock
    Add-PodeRoute -PassThru -Method Get '/process' {
        # Perform some work and update progress
        Set-PodeAsyncCounter -Value 40
        # Retrieve the current progress
        $progress = Get-PodeAsyncRouteProgress
        Write-PodeHost "Current Progress: $progress"
    } |Set-PodeAsyncRoute -ResponseContentType 'application/json'

    .NOTES
    This function should only be used inside an asynchronous route scriptblock.

#>
function Get-PodeAsyncRouteProgress {
    if ($___async___id___) {
        return $PodeContext.AsyncRoutes.Results[$___async___id___]['Progress']
    }
    else {
        throw $PodeLocale.setPodeAsyncProgressExceptionMessage
    }
}


<#
.SYNOPSIS
    Sets the schema names for asynchronous Pode route operations.

.DESCRIPTION
    The Set-PodeAsyncRouteOASchemaName function is designed to configure schema names for asynchronous Pode route operations in OpenAPI documentation.
    It stores the specified type names and parameter names for OpenAPI documentation in the Pode context server's OpenAPI definitions.

.PARAMETER OATypeName
    The type name for OpenAPI documentation. The default is 'AsyncRouteTask'. This parameter is only used
    if the route is included in OpenAPI documentation.

.PARAMETER TaskIdName
    The name of the parameter that contains the task Id. The default is 'id'.

.PARAMETER QueryRequestName
    The name of the Pode task query request in the OpenAPI schema. Defaults to 'AsyncRouteTaskQuery'.

.PARAMETER QueryParameterName
    The name of the query parameter in the OpenAPI schema. Defaults to 'AsyncRouteTaskQueryParameter'.

.PARAMETER OADefinitionTag
    The tags associated with the OpenAPI definitions that need to be updated.
#>
function Set-PodeAsyncRouteOASchemaName {
    param(
        [string]
        $OATypeName,

        [Parameter()]
        [string]
        $TaskIdName,

        [Parameter()]
        [string]
        $QueryRequestName,

        [Parameter()]
        [string]
        $QueryParameterName,

        [Parameter()]
        [string[]]
        $OADefinitionTag
    )
    # Validates the provided OpenAPI definition tags using a custom function.
    $DefinitionTag = Test-PodeOADefinitionTag -Tag $OADefinitionTag

    # Iterates over each valid OpenAPI definition tag.
    foreach ($tag in $DefinitionTag) {

        # If $OATypeName is not provided, fetch it from the corresponding OpenAPI definition's hidden components.
        if (! $OATypeName) {
            $OATypeName = $PodeContext.Server.OpenApi.Definitions[$tag].hiddenComponents.AsyncRoute.OATypeName
        }

        # If $TaskIdName is not provided, fetch it from the corresponding OpenAPI definition's hidden components.
        if (! $TaskIdName) {
            $TaskIdName = $PodeContext.Server.OpenApi.Definitions[$tag].hiddenComponents.AsyncRoute.TaskIdName
        }

        # If $QueryRequestName is not provided, fetch it from the corresponding OpenAPI definition's hidden components.
        if (!$QueryRequestName) {
            $QueryRequestName = $PodeContext.Server.OpenApi.Definitions[$tag].hiddenComponents.AsyncRoute.QueryRequestName
        }

        # If $QueryParameterName is not provided, fetch it from the corresponding OpenAPI definition's hidden components.
        if (!$QueryParameterName) {
            $QueryParameterName = $PodeContext.Server.OpenApi.Definitions[$tag].hiddenComponents.AsyncRoute.QueryParameterName
        }

        # Update the hiddenComponents.AsyncRoute property of the OpenAPI definition
        # with the schema details fetched or provided, by calling Get-PodeAsyncRouteOASchemaNameInternal function.
        $PodeContext.Server.OpenApi.Definitions[$tag].hiddenComponents.AsyncRoute = Get-PodeAsyncRouteOASchemaNameInternal `
            -OATypeName $OATypeName -TaskIdName $TaskIdName `
            -QueryRequestName $QueryRequestName -QueryParameterName $QueryParameterName
    }
}

<#
.SYNOPSIS
    Sets the field name that uniquely identifies a user for async routes in Pode.

.DESCRIPTION
    The `Set-PodeAsyncRouteUserIdentifierField` function allows you to specify a custom field name
    that represents the user identifier in async routes within Pode. This field name is stored in the Pode context
    and is used throughout the application to identify users in async operations.

.PARAMETER UserIdentifierField
    The name of the field that uniquely identifies a user. This parameter is mandatory.
    By default, the user identifier field is 'Id'.

.EXAMPLE
    Set-PodeAsyncRouteUserIdentifierField -UserIdentifierField 'UserId'

    This example sets the user identifier field to 'UserId', overriding the default 'Id'.

.NOTES
    The user identifier field is stored in `$PodeContext.AsyncRoutes.UserFieldIdentifier`. The default value is 'Id'.
#>
function Set-PodeAsyncRouteUserIdentifierField {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $UserIdentifierField
    )
    $PodeContext.AsyncRoutes.UserFieldIdentifier = $UserIdentifierField
}

<#
.SYNOPSIS
    Retrieves the field name that uniquely identifies a user for async routes in Pode.

.DESCRIPTION
    The `Get-PodeAsyncRouteUserIdentifierField` function returns the current field name
    used to uniquely identify users in async routes within Pode. This field name is stored in the Pode context.

.PARAMETER UserIdentifierField
    The name of the field that uniquely identifies a user. This parameter is mandatory.
    By default, the user identifier field is 'Id'.

.EXAMPLE
    $userField = Get-PodeAsyncRouteUserIdentifierField

    This example retrieves the current user identifier field, which by default is 'Id'.

.NOTES
    The user identifier field is retrieved from `$PodeContext.AsyncRoutes.UserFieldIdentifier`. The default value is 'Id'.
#>
function Get-PodeAsyncRouteUserIdentifierField {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $UserIdentifierField
    )
    return $PodeContext.AsyncRoutes.UserFieldIdentifier
}
