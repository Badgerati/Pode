function ConvertTo-PodeOAContentTypeSchema {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $Schemas,
        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Array
    )

    if (Test-PodeIsEmpty $Schemas) {
        return $null
    }

    # ensure all content types are valid
    foreach ($type in $Schemas.Keys) {
        if ($type -inotmatch '^\w+\/[\w\.\+-]+$') {
            throw "Invalid content-type found for schema: $($type)"
        }
    }

    # convert each schema to openapi format
    return (ConvertTo-PodeOAObjectSchema -Schemas $Schemas -Array:$Array)
}

function ConvertTo-PodeOAHeaderSchema {
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true)]
        [string[]]
        $Schemas,
        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Array
    )
    begin {
        $obj = @{}
    }
    process {
        # convert each schema to openapi format
        foreach ($schema in $Schemas) {
            if ( !(Test-PodeOAComponentHeaderSchema -Name $schema)) {
                throw "The OpenApi component schema doesn't exist: $schema"
            }
            if ($Array) {
                $obj[$schema] = @{
                    'description' = $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema].description
                    'schema'      = @{
                        'type'  = 'array'
                        'items' = ($PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema] | ConvertTo-PodeOASchemaProperty -NoDescription )
                    }
                }
            } else {
                $obj[$schema] = @{
                    'description' = $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema].description
                    'schema'      = ($PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema] | ConvertTo-PodeOASchemaProperty -NoDescription )
                }
            }
        }
    }
    end {
        return $obj
    }
}

function ConvertTo-PodeOAObjectSchema {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $Schemas,
        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Array
    )

    # convert each schema to openapi format
    $obj = @{}
    foreach ($type in $Schemas.Keys) {
        $obj[$type] = @{
            schema = $null
        }
        if ($Array) {
            $obj[$type].schema = @{
                'type'  = 'array'
                'items' = $null
            }
        }
        # add a shared component schema reference
        if ($Schemas[$type] -is [string]) {
            if (@('string', 'integer' , 'number', 'boolean' ) -icontains $Schemas[$type]) {
                if ($Array) {
                    $obj[$type].schema.items = @{
                        'type' = $Schemas[$type].ToLower()
                    }
                } else {
                    $obj[$type].schema = @{
                        'type' = $Schemas[$type].ToLower()
                    }
                }
            } else {
                if ( !(Test-PodeOAComponentSchema -Name $Schemas[$type])) {
                    throw "The OpenApi component schema doesn't exist: $($Schemas[$type])"
                }
                if ($Array) {
                    $obj[$type].schema.items = @{
                        '$ref' = "#/components/schemas/$($Schemas[$type])"
                    }
                } else {
                    $obj[$type].schema = @{
                        '$ref' = "#/components/schemas/$($Schemas[$type])"
                    }
                }
            }
        }
        # add a set schema object
        else {
            $obj[$type].schema = ($Schemas[$type] | ConvertTo-PodeOASchemaProperty)
        }
    }

    return $obj
}

function Test-PodeOAExternalDoc {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs.ContainsKey($Name)
}

function Test-PodeOAComponentHeaderSchema {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas.ContainsKey($Name)
}

function Test-PodeOAComponentSchemaJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson.ContainsKey($Name)
}

function Test-PodeOAComponentSchema {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.schemas.ContainsKey($Name)
}

function Test-PodeOAComponentResponse {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.responses.ContainsKey($Name)
}

function Test-PodeOAComponentRequestBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.requestBodies.ContainsKey($Name)
}

function Test-PodeOAComponentParameter {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    return $PodeContext.Server.OpenAPI.components.parameters.ContainsKey($Name)
}


function ConvertTo-PodeOAOfProperty {
    param (
        [hashtable]
        $Property
    )
    if ( @('allOf', 'oneOf', 'anyOf') -inotcontains $Property.type  ) {
        return  @{}
    }
    $schema = [ordered]@{
        $Property.type = @()
    }
    if ($Property.schemas ) {
        foreach ($prop in $Property.schemas ) {
            if ($prop -is [string]) {
                if ( !(Test-PodeOAComponentSchema -Name $prop)) {
                    throw "The OpenApi component schema doesn't exist: $prop"
                }
                $schema[$Property.type ] += @{ '$ref' = "#/components/schemas/$prop" }
            } else {
                $schema[$Property.type ] += $prop | ConvertTo-PodeOASchemaProperty
            }
        }
    }
    if ($Property.discriminator) {
        $schema['discriminator'] = @{'propertyName' = $Property.discriminator }
    }
    return  $schema
}

function ConvertTo-PodeOASchemaProperty {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Property,
        [switch]
        $NoDescription
    )
    if ( @('allof', 'oneof', 'anyof') -icontains $Property.type  ) {
        $schema = ConvertTo-PodeOAofProperty -Property $Property
    } else {
        # base schema type
        $schema = [ordered]@{
            type = $Property.type.ToLower()
        }

        if (!$NoDescription -and $Property.description) {
            $schema['description'] = $Property.description
        }

        if ($Property.default) {
            $schema['default'] = $Property.default
        }

        if ($Property.deprecated) {
            $schema['deprecated'] = $Property.deprecated
        }
        if ($param.xmlName ) {
            $schema['xml'] = @{ 'name' = $param.xmlName }
        }

        if ($null -ne $Property.meta) {
            foreach ($key in $Property.meta.Keys) {
                if ($Property.meta.$key) {
                    $schema[$key] = $Property.meta[$key]
                }
            }
        }

        # are we using an array?
        if ($Property.array) {
            if ($Property.maxItems ) {
                $schema['maxItems'] = $Property.maxItems
            }

            if ($Property.minItems ) {
                $schema['minItems'] = $Property.minItems
            }

            if ($Property.uniqueItems ) {
                $schema['uniqueItems'] = $Property.uniqueItems
            }

            $schema['type'] = 'array'
            if ($Property.type -ieq 'schema') {
                if ( !(Test-PodeOAComponentSchema -Name $Property['schema'])) {
                    throw "The OpenApi component schema doesn't exist: $($Property['schema'])"
                }
                $schema['items'] = @{ '$ref' = "#/components/schemas/$($Property['schema'])" }
            } else {
                $Property.array = $false
                $schema['items'] = ($Property | ConvertTo-PodeOASchemaProperty)
                $Property.array = $true
            }
            return $schema
        } else {
            #format is not applicable to array
            if ($Property.format) {
                $schema['format'] = $Property.format
            }

            # schema refs
            if ($Property.type -ieq 'schema') {
                if ( !(Test-PodeOAComponentSchema -Name $Property['schema'])) {
                    throw "The OpenApi component schema doesn't exist: $($Property['schema'])"
                }
                $schema = @{
                    '$ref' = "#/components/schemas/$($Property['schema'])"
                }
            }
            #only if it's not an array
            if ($Property.enum ) {
                $schema['enum'] = $Property.enum
            }
        }

        if ($Property.object) {
            # are we using an object?
            $Property.object = $false

            $schema = @{
                type       = 'object'
                properties = (ConvertTo-PodeOASchemaObjectProperty -Properties $Property)
            }
            $Property.object = $true
            if ($Property.required) {
                $schema['required'] = @($Property.name)
            }
        }

        if ($Property.type -ieq 'object') {
            foreach ($prop in $Property.properties) {
                if ( @('allOf', 'oneOf', 'anyOf') -icontains $prop.type  ) {
                    switch ($prop.type.ToLower()) {
                        'allof' { $prop.type = 'allOf' }
                        'oneof' { $prop.type = 'oneOf' }
                        'anyof' { $prop.type = 'anyOf' }
                    }
                    $schema += ConvertTo-PodeOAofProperty -Property $prop

                }
            }
            $schema['properties'] = (ConvertTo-PodeOASchemaObjectProperty -Properties $Property.properties)
            $RequiredList = @(($Property.properties | Where-Object { $_.required }) )
            if ( $RequiredList.Count -gt 0) {
                $schema['required'] = @($RequiredList.Name)
            }

            if ($Property.xml ) {
                $schema['xml'] = @{}
                foreach ($key in $Property.xml.Keys) {
                    $schema['xml'].$key = $Property.xml.$key
                }
            }
        }
    }
    return $schema
}

function ConvertTo-PodeOASchemaObjectProperty {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Properties
    )
    $schema = @{}
    foreach ($prop in $Properties) {
        if ( @('allOf', 'oneOf', 'anyOf') -inotcontains $prop.type  ) {
            <#  switch ($prop.type.ToLower()) {
                'allof' { $prop.type = 'allOf' }
                'oneof' { $prop.type = 'oneOf' }
                'anyof' { $prop.type = 'anyOf' }
            }#>
            $schema[$prop.name] = ($prop | ConvertTo-PodeOASchemaProperty  )
        }
    }
    return $schema
}

function Get-PodeOpenApiDefinitionInternal {
    param(

        [Parameter()]
        [string]
        $Protocol,

        [Parameter()]
        [string]
        $Address,

        [Parameter()]
        [string]
        $EndpointName,

        [Parameter()]
        [hashtable]
        $MetaInfo
    )

    # set the openapi version
    $def = [ordered]@{
        openapi = $PodeContext.Server.OpenAPI.Version
    }

    if ($PodeContext.Server.OpenAPI.info) {
        $def['info'] = $PodeContext.Server.OpenAPI.info
    }

    #overwite default values
    if ($MetaInfo.Title) {
        $def.info.title = $MetaInfo.Title
    }
    if ($MetaInfo.Version) {
        $def.info.version = $MetaInfo.Version
    }
    if ($MetaInfo.Description) {
        $def.info.description = $MetaInfo.Description
    }

    if ($PodeContext.Server.OpenAPI.externalDocs) {
        $def['externalDocs'] = $PodeContext.Server.OpenAPI.externalDocs
    }

    if ($PodeContext.Server.OpenAPI.servers) {
        $def['servers'] = $PodeContext.Server.OpenAPI.servers
    } elseif (!$MetaInfo.RestrictRoutes -and ($PodeContext.Server.Endpoints.Count -gt 1)) {
        #  $def['servers'] = $null
        $def.servers = @(foreach ($endpoint in $PodeContext.Server.Endpoints.Values) {
                @{
                    url         = $endpoint.Url
                    description = (Protect-PodeValue -Value $endpoint.Description -Default $endpoint.Name)
                }
            })
    }
    if ($PodeContext.Server.OpenAPI.tags.Count -gt 0) {
        $def['tags'] = @($PodeContext.Server.OpenAPI.tags.Values)
    }

    # paths
    $def['paths'] = [ordered]@{}
    # components
    $def['components'] = $PodeContext.Server.OpenAPI.components
    # auth/security components
    if ($PodeContext.Server.Authentications.Methods.Count -gt 0) {
        if ($null -eq $def.components.securitySchemes) {
            $def.components.securitySchemes = @{}
        }

        foreach ($authName in $PodeContext.Server.Authentications.Methods.Keys) {
            $authType = (Find-PodeAuth -Name $authName).Scheme
            $_authName = ($authName -replace '\s+', '')

            $_authObj = @{}
            if ($authType.Scheme -ieq 'apikey') {
                $_authObj = @{
                    type = $authType.Scheme
                    in   = $authType.Arguments.Location.ToLowerInvariant()
                    name = $authType.Arguments.LocationName
                }
            } else {
                $_authObj = @{
                    type   = $authType.Scheme.ToLowerInvariant()
                    scheme = $authType.Name.ToLowerInvariant()
                }
            }

            $def.components.securitySchemes[$_authName] = $_authObj
        }

        if ($PodeContext.Server.OpenAPI.Security.Definition -and $PodeContext.Server.OpenAPI.Security.Definition.Length -gt 0) {
            $def['security'] = @($PodeContext.Server.OpenAPI.Security.Definition)
        }
    }

    if ($MetaInfo) {
        $filter = "^$($MetaInfo.RouteFilter)"
    } else {
        $filter = ''
    }

    foreach ($method in $PodeContext.Server.Routes.Keys) {
        foreach ($path in ($PodeContext.Server.Routes[$method].Keys | Sort-Object)) {
            # does it match the route?
            if ($path -inotmatch $filter) {
                continue
            }
            # the current route
            $_routes = @($PodeContext.Server.Routes[$method][$path])
            if ( $MetaInfo -and $MetaInfo.RestrictRoutes) {
                $_routes = @(Get-PodeRoutesByUrl -Routes $_routes -EndpointName $EndpointName)
            }

            # continue if no routes
            if (($_routes.Length -eq 0) -or ($null -eq $_routes[0])) {
                continue
            }

            # get the first route for base definition
            $_route = $_routes[0]
            # check if the route has to be published
            if ($_route.OpenApi.Swagger) {
                #remove the ServerUrl part
                if ($MetaInfo -and $MetaInfo.ServerUrl) {
                    $_route.OpenApi.Path = $_route.OpenApi.Path.replace($MetaInfo.ServerUrl, '')
                }
                # do nothing if it has no responses set
                if ($_route.OpenApi.Responses.Count -eq 0) {
                    continue
                }

                # add path to defintion
                if ($null -eq $def.paths[$_route.OpenApi.Path]) {
                    $def.paths[$_route.OpenApi.Path] = @{}
                }

                $pm = [ordered]@{}
                if ($_route.OpenApi.Deprecated) {
                    $pm.deprecated = $_route.OpenApi.Deprecated
                }
                if ($_route.OpenApi.Tags  ) {
                    $pm.tags = $_route.OpenApi.Tags
                }
                if ($_route.OpenApi.Summary) {
                    $pm.summary = $_route.OpenApi.Summary
                }
                if ($_route.OpenApi.Description) {
                    $pm.description = $_route.OpenApi.Description
                }
                if ($_route.OpenApi.OperationId  ) {
                    $pm.operationId = $_route.OpenApi.OperationId
                }
                if ($_route.OpenApi.Parameters) {
                    $pm.parameters = $_route.OpenApi.Parameters
                }
                if ($_route.OpenApi.RequestBody) {
                    $pm.requestBody = $_route.OpenApi.RequestBody
                }
                if ($_route.OpenApi.Authentication.Count -gt 0) {
                    $pm.security = @($_route.OpenApi.Authentication)
                }
                $pm.responses = $_route.OpenApi.Responses
                #servers     = $null
                # add path's http method to defintition
                $def.paths[$_route.OpenApi.Path][$method] = $pm
                # add global authentication for route
                if (($null -ne $def['security']) -and ($def['security'].Length -gt 0)) {
                    foreach ($sec in $PodeContext.Server.OpenAPI.Security) {
                        if ([string]::IsNullOrWhiteSpace($sec.Route) -or ($sec.Route -ieq '/') -or ($sec.Route -ieq $_route.OpenApi.Path) -or ($_route.OpenApi.Path -imatch "^$($sec.Route)$")) {
                            if (!$def.paths[$_route.OpenApi.Path][$method].security) {
                                $def.paths[$_route.OpenApi.Path][$method].security = @($sec.Definition)
                            } else {
                                $def.paths[$_route.OpenApi.Path][$method].security += $sec.Definition
                            }
                        }
                    }
                }

                # add any custom server endpoints for route
                foreach ($_route in $_routes) {
                    if ([string]::IsNullOrWhiteSpace($_route.Endpoint.Address) -or ($_route.Endpoint.Address -ieq '*:*')) {
                        continue
                    }

                    if ($null -eq $def.paths[$_route.OpenApi.Path][$method].servers) {
                        $def.paths[$_route.OpenApi.Path][$method].servers = @()
                    }

                    $serverDef = $null
                    if (![string]::IsNullOrWhiteSpace($_route.Endpoint.Name)) {
                        $serverDef = @{
                            url = (Get-PodeEndpointByName -Name $_route.Endpoint.Name).Url
                        }
                    } else {
                        $serverDef = @{
                            url = "$($_route.Endpoint.Protocol)://$($_route.Endpoint.Address)"
                        }
                    }

                    if ($null -ne $serverDef) {
                        $def.paths[$_route.OpenApi.Path][$method].servers += $serverDef
                    }

                }
            }
        }
    }

    # remove all null values (swagger hates them)
    #$def | Remove-PodeNullKeysFromHashtable

    return $def
}

function ConvertTo-PodeOAPropertyFromCmdletParameter {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.ParameterMetadata]
        $Parameter
    )

    if ($Parameter.SwitchParameter -or ($Parameter.ParameterType.Name -ieq 'boolean')) {
        New-PodeOABoolProperty -Name $Parameter.Name
    } else {
        switch ($Parameter.ParameterType.Name) {
            { @('int32', 'int64') -icontains $_ } {
                New-PodeOAIntProperty -Name $Parameter.Name -Format $_
            }

            { @('double', 'float') -icontains $_ } {
                New-PodeOANumberProperty -Name $Parameter.Name -Format $_
            }
        }
    }

    New-PodeOAStringProperty -Name $Parameter.Name
}

function Get-PodeOABaseObject {
    return @{
        Path             = $null
        Title            = $null
        components       = @{
            schemas       = @{}
            responses     = @{}
            requestBodies = @{}
            parameters    = @{}
        }
        Security         = @()
        tags             = [ordered]@{}
        hiddenComponents = @{
            headerSchemas = @{}
            externalDocs  = @{}
            schemaJson    = @{}
        }
    }
}

function Set-PodeOAAuth {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [string[]]
        $Name
    )

    foreach ($n in @($Name)) {
        if (!(Test-PodeAuthExists -Name $n)) {
            throw "Authentication method does not exist: $($n)"
        }
    }

    foreach ($r in @($Route)) {
        $r.OpenApi.Authentication = @(foreach ($n in @($Name)) {
                @{
                    "$($n -replace '\s+', '')" = @()
                }
            })
    }
}

function Set-PodeOAGlobalAuth {
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Route
    )

    if (!(Test-PodeAuthExists -Name $Name)) {
        throw "Authentication method does not exist: $($Name)"
    }

    if (Test-PodeIsEmpty $PodeContext.Server.OpenAPI.Security) {
        $PodeContext.Server.OpenAPI.Security = @()
    }

    $PodeContext.Server.OpenAPI.Security += @{
        Definition = @{
            "$($Name -replace '\s+', '')" = @()
        }
        Route      = (ConvertTo-PodeRouteRegex -Path $Route)
    }
}

function Resolve-PodeOAReferences {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $ComponentSchema
    )
    $Schemas = $PodeContext.Server.OpenAPI.components.schemas
    $Keys = @()

    if ($ComponentSchema.properties) {
        foreach ($item in $ComponentSchema.properties.Keys) {
            $Keys += $item
        }
    } else {
        foreach ($item in $ComponentSchema.Keys) {
            if ( @('allof', 'oneof', 'anyof') -icontains $item ) {
                $Keys += $item
            }
        }
    }
    foreach ($key in $Keys) {
        if ( @('allof', 'oneof', 'anyof') -icontains $key ) {
            if ($key -ieq 'allof') {
                $tmpProp = @()
                foreach ( $offKey in $ComponentSchema[$key].Keys) {
                    switch ($offKey) {
                        '$ref' {
                            if (($ComponentSchema.$key.'$ref').StartsWith('#/components/schemas/')) {
                                $refName = ($ComponentSchema.$key.'$ref') -replace '#/components/schemas/', ''
                                if ($Schemas.ContainsKey($refName)) {
                                    $tmpProp += $Schemas[$refName]
                                }
                            }
                        }
                        'properties' {
                            $tmpProp += $ComponentSchema.$key.properties
                        }
                    }

                }
                $ComponentSchema.type = 'object'
                $ComponentSchema.remove('allOf')
                if ($tmpProp.count -gt 0) {
                    $ComponentSchema.properties = $tmpProp
                }

            } elseif ($key -ieq 'oneof') {
                #TBD
            } elseif ($key -ieq 'anyof') {
                #TBD
            }
        } elseif ($ComponentSchema.properties[$key].type -eq 'object') {
            Resolve-PodeOAReferences -ComponentSchema $ComponentSchema.properties[$key].properties
        } elseif ($ComponentSchema.properties[$key].'$ref') {
            if (($ComponentSchema.properties[$key].'$ref').StartsWith('#/components/schemas/')) {
                $refName = ($ComponentSchema.properties[$key].'$ref') -replace '#/components/schemas/', ''
                if ($Schemas.ContainsKey($refName)) {
                    $ComponentSchema.properties[$key] = $Schemas[$refName]
                }
            }
        } elseif ($ComponentSchema.properties[$key].items -and $ComponentSchema.properties[$key].items.'$ref' ) {
            if (($ComponentSchema.properties[$key].items.'$ref').StartsWith('#/components/schemas/')) {
                $refName = ($ComponentSchema.properties[$key].items.'$ref') -replace '#/components/schemas/', ''
                if ($Schemas.ContainsKey($refName)) {
                    $ComponentSchema.properties[$key].items = $schemas[$refName]
                }
            }
        }
    }
}