function ConvertTo-PodeOAContentTypeSchema {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $Schemas,

        [Parameter()]
        [switch]
        $Array,

        [Parameter()]
        [switch]
        $Properties
    )

    if (Test-PodeIsEmpty $Schemas) {
        return $null
    }

    # ensure all content types are valid
    foreach ($type in $Schemas.Keys) {
        if ($type -inotmatch '^(application|audio|image|message|model|multipart|text|video|\*)\/[\w\.\-\*]+(;[\s]*(charset|boundary)=[\w\.\-\*]+)*$') {
            throw "Invalid content-type found for schema: $($type)"
        }
    }

    # convert each schema to openapi format
    return (ConvertTo-PodeOAObjectSchema -Schemas $Schemas -Array:$Array -Properties:$Properties)
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
        $Array,

        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Properties

    )
    # manage generic schema json conversion issue
    if ( $Schemas.ContainsKey('*/*')) {
        $Schemas['"*/*"'] = $Schemas['*/*']
        $Schemas.Remove('*/*')
    }
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
            if (![string]::IsNullOrEmpty($Schemas[$type])) {
                #Check for empty reference
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
            } else {
                # Create an empty content
                $obj[$type] = @{}
            }
        }
        # add a set schema object
        else {
            $result = ($Schemas[$type] | ConvertTo-PodeOASchemaProperty)
            if ($Properties) {
                if ($Schemas[$type].Name) {
                    $obj[$type].schema = @{
                        'properties' = @{
                            $Schemas[$type].Name = $result
                        }
                    }
                } else {
                    Throw 'The Properties parameters cannot be used if the Property has no name'
                }
            } else {
                if ($Array) {
                    $obj[$type].schema.items = $result
                } else {
                    $obj[$type].schema = $result
                }
            }
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

    return  $PodeContext.Server.OpenAPI.components.schemas.keys -ccontains $Name
}



function Test-PodeOAComponentExample {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return  $PodeContext.Server.OpenAPI.components.examples.keys -ccontains $Name
}


function Test-PodeOAComponentResponse {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return  $PodeContext.Server.OpenAPI.components.responses.keys -ccontains $Name
}

function Test-PodeOAComponentRequestBody {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return  $PodeContext.Server.OpenAPI.components.requestBodies.keys -ccontains $Name
}

function Test-PodeOAComponentParameter {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    return  $PodeContext.Server.OpenAPI.components.parameters.keys -ccontains $Name
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
        $schema['discriminator'] = $Property.discriminator
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

        if ($Property.nullable) {
            $schema['nullable'] = $Property.nullable
        }

        if ($Property.writeOnly) {
            $schema['writeOnly'] = $Property.writeOnly
        }

        if ($Property.readOnly) {
            $schema['readOnly'] = $Property.readOnly
        }

        if ($Property.example) {
            $schema['example'] = $Property.example
        }

        if ($Property.minimum) {
            $schema['minimum'] = $Property.minimum
        }

        if ($Property.maximum) {
            $schema['maximum'] = $Property.maximum
        }

        if ($Property.exclusiveMaximum) {
            $schema['exclusiveMaximum'] = $Property.exclusiveMaximum
        }

        if ($Property.exclusiveMinimum) {
            $schema['exclusiveMinimum'] = $Property.exclusiveMinimum
        }

        if ($Property.multipleOf) {
            $schema['multipleOf'] = $Property.multipleOf
        }

        if ($Property.pattern) {
            $schema['pattern'] = $Property.pattern
        }

        if ($Property.minLength) {
            $schema['minLength'] = $Property.minLength
        }

        if ($Property.maxLength) {
            $schema['maxLength'] = $Property.maxLength
        }

        if ($Property.xml ) {
            $schema['xml'] = $Property.xml
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
            if ($Property.properties) {
                $schema['properties'] = (ConvertTo-PodeOASchemaObjectProperty -Properties $Property.properties)
                $RequiredList = @(($Property.properties | Where-Object { $_.required }) )
                if ( $RequiredList.Count -gt 0) {
                    $schema['required'] = @($RequiredList.Name)
                }
            } else {
                #if noproperties parameter create an empty properties
                if ( $Property.properties.Count -eq 1 -and $null -eq $Property.properties[0]) {
                    $schema['properties'] = @{}
                }
            }


            if ($Property.MinProperties) {
                $schema['minProperties'] = $Property.MinProperties
            }

            if ($Property.MaxProperties) {
                $schema['maxProperties'] = $Property.MaxProperties
            }

            if ($Property.additionalProperties) {
                $schema['additionalProperties'] = $Property.additionalProperties
            }

            if ($Property.discriminator) {
                $schema['discriminator'] = $Property.discriminator
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
    if (!$PodeContext.Server.OpenAPI.Version) {
        throw 'OpenApi openapi field is required'
    }
    $localEndpoint = $null
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
        if ($PodeContext.Server.OpenAPI.servers.Count -eq 1 -and $PodeContext.Server.OpenAPI.servers[0].url.StartsWith('/')) {
            $localEndpoint = $PodeContext.Server.OpenAPI.servers[0].url
        }
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
        $authNames = (Expand-PodeAuthMerge -Names $PodeContext.Server.Authentications.Methods.Keys)

        foreach ($authName in $authNames) {
            $authType = (Find-PodeAuth -Name $authName).Scheme
            $_authName = ($authName -replace '\s+', '')

            $_authObj = @{}

            if ($authType.Scheme -ieq 'apikey') {
                $_authObj = [ordered]@{
                    type = $authType.Scheme
                    in   = $authType.Arguments.Location.ToLowerInvariant()
                    name = $authType.Arguments.LocationName
                }
                if ($authType.Arguments.Description) {
                    $_authObj.description = $authType.Arguments.Description
                }
            } elseif ($authType.Scheme -ieq 'oauth2') {
                if ($authType.Arguments.Urls.Token -and $authType.Arguments.Urls.Authorise) {
                    $oAuthFlow = 'authorizationCode'
                } elseif ($authType.Arguments.Urls.Token ) {
                    if ($null -ne $authType.InnerScheme) {
                        if ($authType.InnerScheme.Name -ieq 'basic' -or $authType.InnerScheme.Name -ieq 'form') {
                            $oAuthFlow = 'password'
                        } else {
                            $oAuthFlow = 'implicit'
                        }
                    }
                }
                $_authObj = [ordered]@{
                    type = $authType.Scheme
                }
                if ($authType.Arguments.Description) {
                    $_authObj.description = $authType.Arguments.Description
                }
                $_authObj.flows = @{
                    $oAuthFlow = [ordered]@{
                    }
                }
                if ($authType.Arguments.Urls.Token) {
                    $_authObj.flows.$oAuthFlow.tokenUrl = $authType.Arguments.Urls.Token
                }

                if ($authType.Arguments.Urls.Authorise) {
                    $_authObj.flows.$oAuthFlow.authorizationUrl = $authType.Arguments.Urls.Authorise
                }
                if ($authType.Arguments.Urls.Refresh) {
                    $_authObj.flows.$oAuthFlow.refreshUrl = $authType.Arguments.Urls.Refresh
                }

                $_authObj.flows.$oAuthFlow.scopes = @{}
                if ($authType.Arguments.Scopes ) {
                    foreach ($scope in $authType.Arguments.Scopes  ) {
                        if ($PodeContext.Server.Authorisations.Methods.ContainsKey($scope) -and $PodeContext.Server.Authorisations.Methods[$scope].Scheme.Type -ieq 'Scope' -and $PodeContext.Server.Authorisations.Methods[$scope].Description) {
                            $_authObj.flows.$oAuthFlow.scopes[$scope] = $PodeContext.Server.Authorisations.Methods[$scope].Description
                        } else {
                            $_authObj.flows.$oAuthFlow.scopes[$scope] = 'No description.'
                        }
                    }
                }
            } else {
                $_authObj = @{
                    type   = $authType.Scheme.ToLowerInvariant()
                    scheme = $authType.Name.ToLowerInvariant()
                }
                if ($authType.Arguments.Description) {
                    $_authObj.description = $authType.Arguments.Description
                }
            }
            $def.components.securitySchemes[$_authName] = $_authObj
        }

        if ($PodeContext.Server.OpenAPI.Security.Definition -and $PodeContext.Server.OpenAPI.Security.Definition.Length -gt 0) {
            $def['security'] = @($PodeContext.Server.OpenAPI.Security.Definition)
        }
    }

    if ($MetaInfo.RouteFilter) {
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
            if ($_route.OpenApi.Swagger -or $PodeContext.Server.OpenAPI.hiddenComponents.enableMinimalDefinitions) {
                #remove the ServerUrl part
                if ( $localEndpoint) {
                    $_route.OpenApi.Path = $_route.OpenApi.Path.replace($localEndpoint, '')
                }
                #    $def.servers.url.StartsWith('/')
                #    if ($MetaInfo -and $MetaInfo.ServerUrl) {
                #        $_route.OpenApi.Path = $_route.OpenApi.Path.replace($MetaInfo.ServerUrl, '')
                #    }
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
                if ($_route.OpenApi.CallBacks) {
                    $pm.callbacks = $_route.OpenApi.CallBacks
                }
                if ($_route.OpenApi.Authentication.Count -gt 0) {
                    $pm.security = @()
                    foreach ($sct in (Expand-PodeAuthMerge -Names $_route.OpenApi.Authentication.Keys)) {
                        if ($PodeContext.Server.Authentications.Methods.$sct.Scheme.Scheme -ieq 'oauth2') {
                            $pm.security += @{ $sct = $_route.AccessMeta.Scope }
                        } else {
                            $pm.security += @{$sct = @() }
                        }
                    }
                }
                $pm.responses = $_route.OpenApi.Responses
                # add path's http method to defintition
                $def.paths[$_route.OpenApi.Path][$method] = $pm

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
        info             = [ordered]@{}
        Path             = $null
        components       = [ordered]@{
            schemas       = @{}
            responses     = @{}
            requestBodies = @{}
            parameters    = @{}
            examples      = @{}
        }
        Security         = @()
        tags             = [ordered]@{}
        hiddenComponents = @{
            enabled          = $false
            schemaValidation = $false
            depth            = 20
            headerSchemas    = @{}
            externalDocs     = @{}
            schemaJson       = @{}
            viewer           = @{}

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

    foreach ($authName in  (Expand-PodeAuthMerge -Names $Name)) {
        $authType = Get-PodeAuth $authName
        if ($authType.Scheme.Arguments.Scopes) {
            $Scopes = @($authType.Scheme.Arguments.Scopes )
        } else {
            $Scopes = @()
        }
        @($authType.Scheme.Arguments.Scopes )
        $PodeContext.Server.OpenAPI.Security += @{
            Definition = @{
                "$($authName -replace '\s+', '')" = $Scopes
            }
            Route      = (ConvertTo-PodeRouteRegex -Path $Route)
        }
    }
}

function Resolve-PodeOAReferences {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $ComponentSchema
    )
    #  $Schemas = $PodeContext.Server.OpenAPI.components.schemas
    $Schemas = $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson
    $Keys = @()

    if ($ComponentSchema.properties) {
        foreach ($item in $ComponentSchema.properties.Keys) {
            $Keys += $item
        }
    }
    foreach ($item in $ComponentSchema.Keys) {
        if ( @('allof', 'oneof', 'anyof') -icontains $item ) {
            $Keys += $item
        }
    }

    foreach ($key in $Keys) {
        if ( @('allof', 'oneof', 'anyof') -icontains $key ) {
            if ($key -ieq 'allof') {
                $tmpProp = @()
                foreach ( $comp in $ComponentSchema[$key] ) {
                    if ($comp.'$ref') {
                        if (($comp.'$ref').StartsWith('#/components/schemas/')) {
                            $refName = ($comp.'$ref') -replace '#/components/schemas/', ''
                            if ($Schemas.ContainsKey($refName)) {
                                $tmpProp += $Schemas[$refName].schema
                            }
                        }
                    } elseif ( $comp.properties) {
                        if ($comp.type -eq 'object') {
                            $tmpProp += Resolve-PodeOAReferences -ComponentSchema  $comp
                        } else {
                            throw 'Unsupported object'
                        }
                    }
                }

                $ComponentSchema.type = 'object'
                $ComponentSchema.remove('allOf')
                if ($tmpProp.count -gt 0) {
                    foreach ($t in $tmpProp) {
                        $ComponentSchema.properties += $t.properties
                    }
                }

            } elseif ($key -ieq 'oneof') {
                #TBD
            } elseif ($key -ieq 'anyof') {
                #TBD
            }
        } elseif ($ComponentSchema.properties[$key].type -eq 'object') {
            $ComponentSchema.properties[$key].properties = Resolve-PodeOAReferences -ComponentSchema $ComponentSchema.properties[$key].properties
        } elseif ($ComponentSchema.properties[$key].'$ref') {
            if (($ComponentSchema.properties[$key].'$ref').StartsWith('#/components/schemas/')) {
                $refName = ($ComponentSchema.properties[$key].'$ref') -replace '#/components/schemas/', ''
                if ($Schemas.ContainsKey($refName)) {
                    $ComponentSchema.properties[$key] = $Schemas[$refName].schema
                }
            }
        } elseif ($ComponentSchema.properties[$key].items -and $ComponentSchema.properties[$key].items.'$ref' ) {
            if (($ComponentSchema.properties[$key].items.'$ref').StartsWith('#/components/schemas/')) {
                $refName = ($ComponentSchema.properties[$key].items.'$ref') -replace '#/components/schemas/', ''
                if ($Schemas.ContainsKey($refName)) {
                    $ComponentSchema.properties[$key].items = $schemas[$refName].schema
                }
            }
        }
    }
    return   $ComponentSchema
}




function New-PodeOAPropertyInternal {
    param (
        [String]
        $Type,
        [hashtable]$Params
    )
    $param = @{
        type = $Type
    }

    if ($Params.Name) {
        $param.name = $Params.Name
    }

    if ($Params.Description ) {
        $param.description = $Params.Description
    }

    if ($Params.Array.IsPresent ) {
        $param.array = $Params.Array.IsPresent
    }

    if ($Params.Object.IsPresent ) {
        $param.object = $Params.Object.IsPresent
    }

    if ($Params.Required.IsPresent ) {
        $param.required = $Params.Required.IsPresent
    }

    if ($Params.Default ) {
        $param.default = $Params.Default
    }

    if ($Params.Format) {
        $param.format = $Params.Format.ToLowerInvariant()
    }

    if ($Params.Deprecated.IsPresent ) {
        $param.deprecated = $Params.Deprecated.IsPresent
    }

    if ($Params.Nullable.IsPresent ) {
        $param.nullable = $Params.Nullable.IsPresent
    }

    if ($Params.WriteOnly.IsPresent ) {
        $param.writeOnly = $Params.WriteOnly.IsPresent
    }

    if ($Params.ReadOnly.IsPresent ) {
        $param.readOnly = $Params.ReadOnly.IsPresent
    }

    if ($Params.Example ) {
        $param.example = $Params.Example
    }

    if ($Params.UniqueItems.IsPresent ) {
        $param.uniqueItems = $Params.UniqueItems.IsPresent
    }

    if ($Params.MaxItems) {
        $param.maxItems = $Params.MaxItems
    }

    if ($Params.MinItems) {
        $param.minItems = $Params.MinItems
    }


    if ($Params.Enum) {
        $param.enum = $Params.Enum
    }

    if ($Params.Minimum ) {
        $param.minimum = $Params.Minimum
    }

    if ($Params.Maximum  ) {
        $param.maximum = $Params.Maximum
    }

    if ($Params.ExclusiveMaximum.IsPresent  ) {
        $param.exclusiveMaximum = $Params.ExclusiveMaximum.IsPresent
    }

    if ($Params.ExclusiveMinimum  ) {
        $param.exclusiveMinimum = $Params.ExclusiveMinimum.IsPresent
    }

    if ($Params.MultiplesOf  ) {
        $param.multipleOf = $Params.MultiplesOf
    }

    if ($Params.Pattern) {
        $param.pattern = $Params.Pattern
    }

    if ($Params.MinLength) {
        $param.minLength = $Params.MinLength
    }

    if ($Params.MaxLength) {
        $param.maxLength = $Params.MaxLength
    }

    if ($Params.MinProperties) {
        $param.minProperties = $Params.MinProperties
    }

    if ($Params.MaxProperties) {
        $param.maxProperties = $Params.MaxProperties
    }
    if ($Params.Xml -and $Params.XmlName) {
        throw 'Params -Xml and -XmlName are mutually exclusive'
    } else {
        if ($Params.Xml) {
            $param.xml = $Params.Xml
        }

        if ($Params.XmlName) {
            $param.xml = @{'name' = $Params.XmlName }
        }
    }


    if ($Params.ExternalDocs) {
        if ( !(Test-PodeOAExternalDoc -Name $Params.ExternalDocs)) {
            throw "The ExternalDoc doesn't exist: $($Params.ExternalDocs)"
        }
        $param.externalDocs = $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs[$Params.ExternalDocs]
    }

    if ($Params.NoAdditionalProperties.IsPresent -and $Params.AdditionalProperties) {
        throw 'Params -NoAdditionalProperties and AdditionalProperties are mutually exclusive'
    } else {
        if ($Params.NoAdditionalProperties.IsPresent) {
            $param.AdditionalProperties = $false
        }

        if ($Params.AdditionalProperties) {
            $param.AdditionalProperties = $Params.AdditionalProperties
        }
    }
    return $param
}


function ConvertTo-PodeOAHeaderProperties {
    param (
        [hashtable[]]
        $Headers
    )
    $elems = @{}
    foreach ( $e in $Headers) {
        if ($e.name) {
            $elems.$($e.name) = @{}
            if ($e.description ) {
                $elems.$($e.name).description = $e.description
            }
            $elems.$($e.name).schema = @{
                type = $($e.type)
            }
            foreach ($k in $e.keys) {
                if (@('name', 'description' ) -notcontains $k) {
                    <#     if ( $k -eq 'meta') {
                        foreach ($mk in $e.meta.Keys) {
                            $elems.$($e.name).schema.$mk = $e.meta.$mk
                        }
                    } else {#>
                    $elems.$($e.name).schema.$k = $e.$k
                    #    }
                }
            }
        } else {
            throw 'Header requires a name when used in an encoding context'
        }
    }
    return $elems
}