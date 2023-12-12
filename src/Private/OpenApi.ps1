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
        $Content,

        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Properties

    )

    # ensure all content types are valid
    foreach ($type in $Content.Keys) {
        if ($type -inotmatch '^(application|audio|image|message|model|multipart|text|video|\*)\/[\w\.\-\*]+(;[\s]*(charset|boundary)=[\w\.\-\*]+)*$') {
            throw "Invalid content-type found for schema: $($type)"
        }
    }
    # manage generic schema json conversion issue
    if ( $Content.ContainsKey('*/*')) {
        $Content['"*/*"'] = $Content['*/*']
        $Content.Remove('*/*')
    }
    # convert each schema to openapi format
    $obj = @{}
    foreach ($type in $Content.Keys) {
        $obj[$type] = @{ }
        if ($Content[$type].__array) {
            $isArray = $true
            $item = $Content[$type].__content
            $obj[$type].schema = [ordered]@{
                'type'  = 'array'
                'items' = $null
            }
            if ( $Content[$type].__title) {
                $obj[$type].schema.title = $Content[$type].__title
            }
            if ( $Content[$type].__uniqueItems) {
                $obj[$type].schema.uniqueItems = $Content[$type].__uniqueItems
            }
            if ( $Content[$type].__maxItems) {
                $obj[$type].schema.__maxItems = $Content[$type].__maxItems
            }
            if ( $Content[$type].minItems) {
                $obj[$type].schema.minItems = $Content[$type].__minItems
            }
        } else {
            $item = $Content[$type]
            $isArray = $false
        }
        # add a shared component schema reference
        if ($item -is [string]) {
            if (![string]::IsNullOrEmpty($item )) {
                #Check for empty reference
                if (@('string', 'integer' , 'number', 'boolean' ) -icontains $item) {
                    if ($isArray) {
                        $obj[$type].schema.items = @{
                            'type' = $item.ToLower()
                        }
                    } else {
                        $obj[$type].schema = @{
                            'type' = $item.ToLower()
                        }
                    }
                } else {
                    if ( !(Test-PodeOAComponentSchema -Name $item)) {
                        throw "The OpenApi component schema doesn't exist: $($item)"
                    }
                    if ($isArray) {
                        $obj[$type].schema.items = @{
                            '$ref' = "#/components/schemas/$($item)"
                        }
                    } else {
                        $obj[$type].schema = @{
                            '$ref' = "#/components/schemas/$($item)"
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
            if ($item.Count -eq 0) {
                $result = @{}
            } else {
                $result = ($item | ConvertTo-PodeOASchemaProperty)
            }
            if ($Properties) {
                if ($item.Name) {
                    $obj[$type].schema = @{
                        'properties' = @{
                            $item.Name = $result
                        }
                    }
                } else {
                    Throw 'The Properties parameters cannot be used if the Property has no name'
                }
            } else {
                if ($isArray) {
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

    return $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs.keys -ccontains $Name
}

function Test-PodeOAComponentHeaderSchema {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas.keys -ccontains $Name
}

function Test-PodeOAComponentSchemaJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson.keys -ccontains $Name
}

function Test-PodeOAComponentCallBack {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.callbacks.keys -ccontains $Name
}

function Test-PodeOAComponentLink {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return  $PodeContext.Server.OpenAPI.components.links.keys -ccontains $Name
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

function Get-PodeOAComponentPath {
    param (
        [Parameter(Mandatory)]
        [ValidateSet('parameters', 'requestBodies', 'responses', 'schemas', 'headers', 'securitySchemes', 'links', 'callbacks', 'pathItems', 'examples')]
        [string]
        $FixesField
    )
    return $PodeContext.Server.OpenAPI.components.$FixesField
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
        $schema = [ordered]@{ }
        if ($PodeContext.Server.OpenAPI.hiddenComponents.v3_0) {
            $schema['type'] = $Property.type.ToLower()
        } else {
            $schema.type = @($Property.type.ToLower())
            if ($Property.nullable) {
                $schema.type += 'null'
            }
        }
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

    if ($Property.nullable -and $PodeContext.Server.OpenAPI.hiddenComponents.v3_0) {
        $schema['nullable'] = $Property.nullable
    }

    if ($Property.writeOnly) {
        $schema['writeOnly'] = $Property.writeOnly
    }

    if ($Property.readOnly) {
        $schema['readOnly'] = $Property.readOnly
    }

    if ($Property.example) {
        if ($PodeContext.Server.OpenAPI.hiddenComponents.v3_0) {
            $schema['example'] = $Property.example
        } else {
            if ($Property.example -is [Array]) {
                $schema['examples'] = $Property.example
            } else {
                $schema['examples'] = @( $Property.example)
            }
        }
    }
    if ($PodeContext.Server.OpenAPI.hiddenComponents.v3_0) {
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
    } else {
        if ($Property.maximum) {
            if ($Property.exclusiveMaximum  ) {
                $schema['exclusiveMaximum'] = $Property.maximum
            } else {
                $schema['maximum'] = $Property.maximum
            }
        }
        if ($Property.minimum) {
            if ($Property.exclusiveMinimum  ) {
                $schema['exclusiveMinimum'] = $Property.minimum
            } else {
                $schema['minimum'] = $Property.minimum
            }
        }
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
    if (! $PodeContext.Server.OpenAPI.hiddenComponents.v3_0) {
        if ($Property.ContentMediaType) {
            $schema['contentMediaType'] = $Property.ContentMediaType
        }
        if ($Property.ContentEncoding) {
            $schema['contentEncoding'] = $Property.ContentEncoding
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
            if ($Property.xml) {
                $xmlFromProperties = $Property.xml
                $Property.Remove('xml')
            }
            $schema['items'] = ($Property | ConvertTo-PodeOASchemaProperty)
            $Property.array = $true
            if ($xmlFromProperties) {
                $Property.xml = $xmlFromProperties
            }

            if ($Property.xmlItemName) {
                $schema.items.xml = @{'name' = $Property.xmlItemName }
            }
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
                $schema['required'] = @($RequiredList.name)
            }
        } else {
            #if noproperties parameter create an empty properties
            if ( $Property.properties.Count -eq 1 -and $null -eq $Property.properties[0]) {
                $schema['properties'] = @{}
            }
        }


        if ($Property.minProperties) {
            $schema['minProperties'] = $Property.minProperties
        }

        if ($Property.maxProperties) {
            $schema['maxProperties'] = $Property.maxProperties
        }

        if ($Property.additionalProperties) {
            $schema['additionalProperties'] = $Property.additionalProperties
        }

        if ($Property.discriminator) {
            $schema['discriminator'] = $Property.discriminator
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

    if ($PodeContext.Server.OpenAPI.hiddenComponents.v3_1) {
        $def['jsonSchemaDialect'] = 'https://json-schema.org/draft/2020-12/schema'
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
        #  if ($null -eq $def.components.securitySchemes) {
        #     $def.components.securitySchemes = @{}
        # }
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

    if ($PodeContext.Server.OpenAPI.components.schemas.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('schemas')
    }
    if ($PodeContext.Server.OpenAPI.components.responses.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('responses')
    }
    if ($PodeContext.Server.OpenAPI.components.parameters.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('parameters')
    }
    if ($PodeContext.Server.OpenAPI.components.examples.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('examples')
    }
    if ($PodeContext.Server.OpenAPI.components.requestBodies.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('requestBodies')
    }
    if ($PodeContext.Server.OpenAPI.components.headers.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('headers')
    }
    if ($PodeContext.Server.OpenAPI.components.securitySchemes.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('securitySchemes')
    }
    if ($PodeContext.Server.OpenAPI.components.links.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('links')
    }
    if ($PodeContext.Server.OpenAPI.components.callbacks.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('callbacks')
    }
    if ($PodeContext.Server.OpenAPI.components.pathItems.count -eq 0) {
        $PodeContext.Server.OpenAPI.components.Remove('pathItems')
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
                if ($_route.OpenApi.CallBacks.Count -gt 0) {
                    $pm.callbacks = $_route.OpenApi.CallBacks
                }
                if ($_route.OpenApi.Authentication.Count -gt 0) {
                    $pm.security = @()
                    foreach ($sct in (Expand-PodeAuthMerge -Names $_route.OpenApi.Authentication.Keys)) {
                        if ($PodeContext.Server.Authentications.Methods.$sct.Scheme.Scheme -ieq 'oauth2') {
                            if ($_route.AccessMeta.Scope ) {
                                $sctValue = $_route.AccessMeta.Scope
                            } else {
                                #if scope is empty means 'any role' => assign an empty array
                                $sctValue = @()
                            }
                            $pm.security += @{ $sct = $sctValue }
                        } elseif ($sct -eq '%_allowanon_%') {
                            #allow anonymous access
                            $pm.security += @{  }
                        } else {
                            $pm.security += @{$sct = @() }
                        }
                    }
                }
                if ($_route.OpenApi.Responses.Count -gt 0) {
                    $pm.responses = $_route.OpenApi.Responses
                }
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
            schemas         = [ordered]@{}
            responses       = [ordered]@{}
            parameters      = [ordered]@{}
            examples        = [ordered]@{}
            requestBodies   = [ordered]@{}
            headers         = [ordered]@{}
            securitySchemes = [ordered]@{}
            links           = [ordered]@{}
            callbacks       = [ordered]@{}
            pathItems       = [ordered]@{}
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
            defaultResponses = $null
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
        $Name,

        [Parameter()]
        [switch]
        $AllowAnon
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
        if ($AllowAnon) {
            $r.OpenApi.Authentication += @{'%_allowanon_%' = '' }
        }
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
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param (
        [Parameter()]
        [String]
        $Type,
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Params
    )
    $param = [ordered]@{
    }

    if ($type) {
        $param.type = $type
    } elseif ($PodeContext.Server.OpenAPI.hiddenComponents.v3_0) {
        throw 'Multi type properties requeired OpenApi Version 3.1 or above'
    } else {
        $param.type = $Params.type
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


    if ($Params.XmlName -or $Params.XmlNamespace -or $Params.XmlPrefix -or $Params.XmlAttribute.IsPresent -or $Params.XmlWrapped.IsPresent) {
        $param.xml = @{}
        if ($Params.XmlName) {
            $param.xml.name = $Params.XmlName
        }
        if ($Params.XmlNamespace) {
            $param.xml.namespace = $Params.XmlNamespace
        }

        if ($Params.XmlPrefix) {
            $param.xml.prefix = $Params.XmlPrefix
        }

        if ($Params.XmlAttribute.IsPresent) {
            $param.xml.attribute = $Params.XmlAttribute.IsPresent
        }

        if ($Params.XmlWrapped.IsPresent) {
            $param.xml.wrapped = $Params.XmlWrapped.IsPresent
        }
    }


    if ($Params.XmlItemName) {
        $param.xmlItemName = $Params.XmlItemName
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
            $param.additionalProperties = $false
        }

        if ($Params.AdditionalProperties) {
            $param.additionalProperties = $Params.AdditionalProperties
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
                    $elems.$($e.name).schema.$k = $e.$k
                }
            }
        } else {
            throw 'Header requires a name when used in an encoding context'
        }
    }
    return $elems
}



function New-PodeOAComponentCallBackInternal {
    param(
        [hashtable]$Params
    )

    $_method = $Params.Method.ToLower()
    #  $_name = $Params.Name
    $callBack = [ordered]@{
        #  $_name = [ordered]@{
        "'$($Params.Path)'" = [ordered]@{
            $_method = [ordered]@{}
        }
        # }
    }
    if ($Params.RequestBody) {
        # $callBack."'$($Params.Path)'".$_method.requestBody = $Params.RequestBody
        $callBack."'$($Params.Path)'".$_method.requestBody = $Params.RequestBody
    }
    if ($Params.Responses) {
        #  $callBack."'$($Params.Path)'".$_method.responses = $Params.Responses
        $callBack."'$($Params.Path)'".$_method.responses = $Params.Responses
    }

    return $callBack

}




function New-PodeOResponseInternal {
    param(
        [hashtable]$Params
    )

    # set a general description for the status code
    if ([string]::IsNullOrWhiteSpace($Description)) {
        if ($Params.Default) {
            $Description = 'Default Response.'
        } elseif ($Params.StatusCode) {
            $Description = Get-PodeStatusDescription -StatusCode $Params.StatusCode
        } else {
            throw 'A Description is required'
        }
    } else {
        $Description = $Params.Description
    }

    if ($Params.Reference ) {
        if (!(Test-PodeOAComponentResponse -Name $Params.Reference)) {
            throw "The OpenApi component response doesn't exist: $($Params.Reference)"
        }
        $response = @{
            '$ref' = "#/components/responses/$($Params.Reference)"
        }
    } else {
        # build any content-type schemas
        $_content = $null
        if ($null -ne $Params.Content) {
            $_content = ConvertTo-PodeOAObjectSchema -Content $Params.Content
        }

        # build any header schemas
        $_headers = $null
        if ($null -ne $Params.Headers) {
            if ($Params.Headers -is [System.Object[]] -or $Params.Headers -is [string] -or $Params.Headers -is [string[]]) {
                if ($Params.Headers -is [System.Object[]] -and $Params.Headers.Count -gt 0 -and ($Params.Headers[0] -is [hashtable] -or $Params.Headers[0] -is [ordered] )) {
                    $_headers = ConvertTo-PodeOAHeaderProperties -Headers   $Params.Headers
                } else {
                    $_headers = ConvertTo-PodeOAHeaderSchema -Schemas $Params.Headers -Array:$Params.HeaderArray
                }
            } elseif ($Params.Headers -is [hashtable]) {
                $_headers = ConvertTo-PodeOAObjectSchema -Content  $Params.Headers
            }
        }


        $response = [ordered]@{
            description = $Description
        }
        if ($_headers) {
            $response.headers = $_headers
        }
        if ($_content) {
            $response.content = $_content
        }
        if ($Params.Links) {
            $response.links = $Params.Links
        }
    }
    return $response
}



function New-PodeOAResponseLinkInternal {
    param(
        [hashtable]$Params
    )

    $link = [ordered]@{  }

    if ($Description) {
        $link.description = $Params.Description
    }
    if ($OperationId) {
        $link.operationId = $Params.OperationId
    }
    if ($OperationRef) {
        $link.operationRef = $Params.OperationRef
    }
    if ($OperationRef) {
        $link.operationRef = $Params.OperationRef
    }
    if ($Parameters) {
        $link.parameters = $Params.Parameters
    }
    if ($RequestBody) {
        $link.requestBody = $Params.RequestBody
    }

    return $link
}