function ConvertTo-PodeOAObjectSchema {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [hashtable]
        $Content,

        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Properties,

        [Parameter(Mandatory = $true)]
        [string ]
        $DefinitionTag

    )

    # ensure all content types are valid
    foreach ($type in $Content.Keys) {
        if ($type -inotmatch '^(application|audio|image|message|model|multipart|text|video|\*)\/[\w\.\-\*]+(;[\s]*(charset|boundary)=[\w\.\-\*]+)*$|^"\*\/\*"$') {
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
    $types = [string[]]$Content.Keys
    foreach ($type in $types) {
        $obj[$type] = @{ }

        if ($Content[$type].__upload) {
            if ($Content[$type].__array) {
                $upload = $Content[$type].__content.__upload
            } else {
                $upload = $Content[$type].__upload
            }

            if ($type -ieq 'multipart/form-data' -and $upload.content ) {
                if ((Test-OpenAPIVersion -Version 3.1 -DefinitionTag $DefinitionTag ) -and $upload.partContentMediaType) {
                    foreach ($key in $upload.content.Properties ) {
                        if ($key.type -eq 'string' -and $key.format -and $key.format -ieq 'binary' -or $key.format -ieq 'base64') {
                            $key.ContentMediaType = $PartContentMediaType
                            $key.remove('format')
                            break
                        }
                    }
                }
                $newContent = $upload.content
            } else {
                if (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $DefinitionTag  ) {
                    $newContent = [ordered]@{
                        'type'   = 'string'
                        'format' = $upload.contentEncoding
                    }
                } else {
                    if ($ContentEncoding -ieq 'Base64') {
                        $newContent = [ordered]@{
                            'type'            = 'string'
                            'contentEncoding' = $upload.contentEncoding
                        }
                    }
                }
            }
            if ($Content[$type].__array) {
                $Content[$type].__content = $newContent
            } else {
                $Content[$type] = $newContent
            }
        }

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
                    Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $item -PostValidation
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
                $result = ($item | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag)
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

<#

.SYNOPSIS
Check if an ComponentSchemaJson reference exist.

.DESCRIPTION
Check if an ComponentSchemaJson reference with a given name exist.

.PARAMETER Name
The Name of the ComponentSchemaJson reference.
#>


function Test-PodeOAComponentSchemaJson {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $DefinitionTag
    )

    foreach ($tag in $DefinitionTag) {
        if (!($PodeContext.Server.OpenAPI[$tag].hiddenComponents.schemaJson.keys -ccontains $Name)) {
            # If $Name is not found in the current $tag, return $false
            return $false
        }
    }
    return $true
}




function Test-PodeOAComponentExternalPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [string[]]
        $DefinitionTag
    )

    foreach ($tag in $DefinitionTag) {
        if (!($PodeContext.Server.OpenAPI[$tag].hiddenComponents.externalPath.keys -ccontains $Name)) {
            # If $Name is not found in the current $tag, return $false
            return $false
        }
    }
    return $true
}






function ConvertTo-PodeOAOfProperty {
    param (
        [hashtable]
        $Property,

        [Parameter(Mandatory = $true)]
        [string ]
        $DefinitionTag
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
                Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $prop -PostValidation
                $schema[$Property.type ] += @{ '$ref' = "#/components/schemas/$prop" }
            } else {
                $schema[$Property.type ] += $prop | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag
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
        $NoDescription,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )

    if ( @('allof', 'oneof', 'anyof') -icontains $Property.type  ) {
        $schema = ConvertTo-PodeOAofProperty -DefinitionTag $DefinitionTag -Property $Property
    } else {
        # base schema type
        $schema = [ordered]@{ }
        if (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $DefinitionTag ) {
            if ($Property.type -is [string[]]) {
                throw 'Multi type properties requeired OpenApi Version 3.1 or above'
            }
            $schema['type'] = $Property.type.ToLower()
        } else {
            $schema.type = @($Property.type.ToLower())
            if ($Property.nullable) {
                $schema.type += 'null'
            }
        }
    }

    if ($Property.externalDocs) {
        $schema['externalDocs'] = $Property.externalDocs
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
    if ($Property.nullable -and (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $DefinitionTag )) {
        $schema['nullable'] = $Property.nullable
    }

    if ($Property.writeOnly) {
        $schema['writeOnly'] = $Property.writeOnly
    }

    if ($Property.readOnly) {
        $schema['readOnly'] = $Property.readOnly
    }

    if ($Property.example) {
        if (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $DefinitionTag ) {
            $schema['example'] = $Property.example
        } else {
            if ($Property.example -is [Array]) {
                $schema['examples'] = $Property.example
            } else {
                $schema['examples'] = @( $Property.example)
            }
        }
    }
    if (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $DefinitionTag ) {
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

    if (Test-OpenAPIVersion -Version 3.1 -DefinitionTag $DefinitionTag ) {
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
            Test-PodeOAComponentInternal -Field schemas -DefinitionTag $DefinitionTag -Name $Property['schema'] -PostValidation
            $schema['items'] = @{ '$ref' = "#/components/schemas/$($Property['schema'])" }
        } else {
            $Property.array = $false
            if ($Property.xml) {
                $xmlFromProperties = $Property.xml
                $Property.Remove('xml')
            }
            $schema['items'] = ($Property | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag)
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
            Test-PodeOAComponentInternal -Field schemas  -DefinitionTag $DefinitionTag -Name $Property['schema'] -PostValidation
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
            properties = (ConvertTo-PodeOASchemaObjectProperty  -DefinitionTag $DefinitionTag -Properties $Property)
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
                $schema += ConvertTo-PodeOAofProperty -DefinitionTag $DefinitionTag -Property $prop

            }
        }
        if ($Property.properties) {
            $schema['properties'] = (ConvertTo-PodeOASchemaObjectProperty  -DefinitionTag $DefinitionTag -Properties $Property.properties)
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
        $Properties,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )
    $schema = @{}
    foreach ($prop in $Properties) {
        if ( @('allOf', 'oneOf', 'anyOf') -inotcontains $prop.type  ) {
            $schema[$prop.name] = ($prop | ConvertTo-PodeOASchemaProperty -DefinitionTag $DefinitionTag  )
        }
    }
    return $schema
}

function Get-PodeOpenApiDefinitionInternal {
    param(

        [string]
        $Protocol,

        [string]
        $Address,

        [string]
        $EndpointName,

        [hashtable]
        $MetaInfo,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )
    function Set-OpenApiRouteValues {
        param(
            [Parameter(Mandatory = $true)]
            [hashtable]
            $_route,

            [Parameter(Mandatory = $true)]
            [string]
            $DefinitionTag
        )
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
        if ($_route.OpenApi.RequestBody.$DefinitionTag) {
            $pm.requestBody = $_route.OpenApi.RequestBody.$DefinitionTag
        }
        if ($_route.OpenApi.CallBacks.$DefinitionTag) {
            $pm.callbacks = $_route.OpenApi.CallBacks.$DefinitionTag
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
        if ($_route.OpenApi.Responses.$DefinitionTag ) {
            $pm.responses = $_route.OpenApi.Responses.$DefinitionTag
        } else {
            $pm.responses = @{'204' = @{'description' = (Get-PodeStatusDescription -StatusCode 204) } }
        }
        return $pm
    }

    $Definition = $PodeContext.Server.OpenAPI[$DefinitionTag]

    if (!  $Definition.Version) {
        throw 'OpenApi openapi field is required'
    }
    $localEndpoint = $null
    # set the openapi version
    $def = [ordered]@{
        openapi = $Definition.Version
    }

    if (Test-OpenAPIVersion -Version 3.1 -DefinitionTag $DefinitionTag  ) {
        $def['jsonSchemaDialect'] = 'https://spec.openapis.org/oas/3.1/dialect/base'
    }

    if (  $Definition.info) {
        $def['info'] = $Definition.info
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

    if (  $Definition.externalDocs) {
        $def['externalDocs'] = $Definition.externalDocs
    }

    if (  $Definition.servers) {
        $def['servers'] = $Definition.servers
        if (  $Definition.servers.Count -eq 1 -and $Definition.servers[0].url.StartsWith('/')) {
            $localEndpoint = $Definition.servers[0].url
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
    if (  $Definition.tags.Count -gt 0) {
        $def['tags'] = @(  $Definition.tags.Values)
    }

    # paths
    $def['paths'] = [ordered]@{}
    if (  $Definition.webhooks.count -gt 0) {
        if (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $DefinitionTag  ) {
            throw 'Feature webhooks is unsupported in OpenAPI v3.0.x'
        } else {
            $keys = [string[]]$Definition.webhooks.Keys
            foreach ($key in $keys) {
                if ($Definition.webhooks[$key].NotPrepared) {
                    $Definition.webhooks[$key] = @{
                        $Definition.webhooks[$key].Method = Set-OpenApiRouteValues -_route $Definition.webhooks[$key] -DefinitionTag $DefinitionTag
                    }
                }
            }
            $def['webhooks'] = $Definition.webhooks
        }
    }
    # components
    $def['components'] = [ordered]@{}  #  $Definition.components
    $components = $Definition.components

    if ($components.schemas.count -gt 0) {
        $def['components'].schemas = $components.schemas
    }
    if ($components.responses.count -gt 0) {
        $def['components'].responses = $components.responses
    }
    if ($components.parameters.count -gt 0) {
        $def['components'].parameters = $components.parameters
    }
    if ($components.examples.count -gt 0) {
        $def['components'].examples = $components.examples
    }
    if ($components.requestBodies.count -gt 0) {
        $def['components'].requestBodies = $components.requestBodies
    }
    if ($components.headers.count -gt 0) {
        $def['components'].headers = $components.headers
    }
    if ($components.securitySchemes.count -gt 0) {
        $def['components'].securitySchemes = $components.securitySchemes
    }
    if ($components.links.count -gt 0) {
        $def['components'].links = $components.links
    }
    if ($components.callbacks.count -gt 0) {
        $def['components'].callbacks = $components.callbacks
    }
    if ($components.pathItems.count -gt 0) {
        if (Test-OpenAPIVersion -Version 3.0 -DefinitionTag $DefinitionTag  ) {
            throw 'Feature pathItems is unsupported in OpenAPI v3.0.x'
        } else {
            $keys = [string[]]$components.pathItems.Keys
            foreach ($key in $keys) {
                if ($components.pathItems[$key].NotPrepared) {
                    $components.pathItems[$key] = @{
                        $components.pathItems[$key].Method = Set-OpenApiRouteValues -_route $components.pathItems[$key] -DefinitionTag $DefinitionTag
                    }
                }
            }
            $def['components'].pathItems = $components.pathItems
        }
    }

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
            if (!$def.components.securitySchemes) {
                $def.components.securitySchemes = [ordered]@{}
            }
            $def.components.securitySchemes[$_authName] = $_authObj
        }

        if (  $Definition.Security.Definition -and $Definition.Security.Definition.Length -gt 0) {
            $def['security'] = @(  $Definition.Security.Definition)
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
            if (($_route.OpenApi.Swagger -and $_route.OpenApi.DefinitionTag -contains $DefinitionTag ) -or $Definition.hiddenComponents.enableMinimalDefinitions) {

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
                # add path's http method to defintition

                $pm = Set-OpenApiRouteValues -_route $_route -DefinitionTag $DefinitionTag
                $def.paths[$_route.OpenApi.Path][$method] = $pm

                # add any custom server endpoints for route
                foreach ($_route in $_routes) {

                    if ($_route.OpenApi.Servers.count -gt 0) {
                        if ($null -eq $def.paths[$_route.OpenApi.Path][$method].servers) {
                            $def.paths[$_route.OpenApi.Path][$method].servers = @()
                        }
                        if ($localEndpoint) {
                            $def.paths[$_route.OpenApi.Path][$method].servers += $Definition.servers[0]
                        }
                        $def.paths[$_route.OpenApi.Path][$method].servers += $_route.OpenApi.Servers
                    }
                    if ([string]::IsNullOrWhiteSpace($_route.Endpoint.Address) -or ($_route.Endpoint.Address -ieq '*:*')  ) {
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

    if (   $Definition.hiddenComponents.externalPath) {
        foreach ($extPath in   $Definition.hiddenComponents.externalPath.values) {
            foreach ($method in $extPath.keys) {
                $_route = $extPath[$method]
                if (! ( $def.paths.keys -ccontains $_route.Path)) {
                    $def.paths[$_route.OpenAPI.Path] = @{}
                }
                $pm = Set-OpenApiRouteValues -_route $_route -DefinitionTag $DefinitionTag
                # add path's http method to defintition
                $def.paths[$_route.OpenAPI.Path][$method.ToLower()] = $pm
            }
        }
    }
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
        webhooks         = [ordered]@{}
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
            version          = 3.0
            depth            = 20
            schemaJson       = @{}
            viewer           = @{}
            postValidation   = @{
                schemas         = @{}
                responses       = @{}
                parameters      = @{}
                examples        = @{}
                requestBodies   = @{}
                headers         = @{}
                securitySchemes = @{}
                links           = @{}
                callbacks       = @{}
                pathItems       = @{}
            }
            externalPath     = [ordered]@{}
            defaultResponses = @{
                '200'     = @{ description = 'OK' }
                'default' = @{ description = 'Internal server error' }
            }
            operationId      = @()
        }
    }
}

function Set-PodeOAAuth {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [string[]]
        $Name,

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
        [string]
        $Name,

        [string]
        $Route,

        [Parameter(Mandatory = $true)]
        [string[]]
        $DefinitionTag
    )

    if (!(Test-PodeAuthExists -Name $Name)) {
        throw "Authentication method does not exist: $($Name)"
    }
    foreach ($tag in $DefinitionTag) {
        if (Test-PodeIsEmpty $PodeContext.Server.OpenAPI[$tag].Security) {
            $PodeContext.Server.OpenAPI[$tag].Security = @()
        }

        foreach ($authName in  (Expand-PodeAuthMerge -Names $Name)) {
            $authType = Get-PodeAuth $authName
            if ($authType.Scheme.Arguments.Scopes) {
                $Scopes = @($authType.Scheme.Arguments.Scopes )
            } else {
                $Scopes = @()
            }
            @($authType.Scheme.Arguments.Scopes )
            $PodeContext.Server.OpenAPI[$tag].Security += @{
                Definition = @{
                    "$($authName -replace '\s+', '')" = $Scopes
                }
                Route      = (ConvertTo-PodeRouteRegex -Path $Route)
            }
        }
    }
}

function Resolve-PodeOAReferences {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $ComponentSchema,

        [Parameter(Mandatory = $true)]
        [string]
        $DefinitionTag
    )

    $Schemas = $PodeContext.Server.OpenAPI[$DefinitionTag].hiddenComponents.schemaJson
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
                            $tmpProp += Resolve-PodeOAReferences -DefinitionTag $DefinitionTag -ComponentSchema  $comp
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
            $ComponentSchema.properties[$key].properties = Resolve-PodeOAReferences -DefinitionTag $DefinitionTag -ComponentSchema $ComponentSchema.properties[$key].properties
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
        [String]
        $Type,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Params

    )

    $param = [ordered]@{}

    if ($type) {
        $param.type = $type
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
        $param.externalDocs = $Params.ExternalDocs
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
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Params,

        [Parameter(Mandatory = $true)]
        [string ]
        $DefinitionTag
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
    if ($Params.RequestBody.ContainsKey( $DefinitionTag)) {
        # $callBack."'$($Params.Path)'".$_method.requestBody = $Params.RequestBody
        $callBack."'$($Params.Path)'".$_method.requestBody = $Params.RequestBody[$DefinitionTag]
    }
    if ($Params.Responses.ContainsKey( $DefinitionTag)) {
        #  $callBack."'$($Params.Path)'".$_method.responses = $Params.Responses
        $callBack."'$($Params.Path)'".$_method.responses = $Params.Responses[$DefinitionTag]
    }

    return $callBack

}




function New-PodeOResponseInternal {
    param(
        [hashtable]$Params,

        [Parameter(Mandatory = $true)]
        [string ]
        $DefinitionTag
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
        Test-PodeOAComponentInternal  -Field responses -DefinitionTag $DefinitionTag -Name $Params.Reference -PostValidation
        $response = @{
            '$ref' = "#/components/responses/$($Params.Reference)"
        }
    } else {
        # build any content-type schemas
        $_content = $null
        if ($null -ne $Params.Content) {
            $_content = ConvertTo-PodeOAObjectSchema -DefinitionTag $DefinitionTag -Content $Params.Content
        }

        # build any header schemas
        $_headers = $null
        if ($null -ne $Params.Headers) {
            if ($Params.Headers -is [System.Object[]] -or $Params.Headers -is [string] -or $Params.Headers -is [string[]]) {
                if ($Params.Headers -is [System.Object[]] -and $Params.Headers.Count -gt 0 -and ($Params.Headers[0] -is [hashtable] -or $Params.Headers[0] -is [ordered] )) {
                    $_headers = ConvertTo-PodeOAHeaderProperties -Headers $Params.Headers
                } else {
                    $_headers = @{}
                    foreach ($h in $Params.Headers) {
                        Test-PodeOAComponentInternal -Field headers -DefinitionTag $DefinitionTag -Name $h -PostValidation
                        $_headers[$h] = @{
                            '$ref' = "#/components/headers/$h"
                        }
                    }
                }
            } elseif ($Params.Headers -is [hashtable]) {
                $_headers = ConvertTo-PodeOAObjectSchema -DefinitionTag $DefinitionTag -Content  $Params.Headers
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


function  Test-PodeOADefinitionInternal {

    #Validate OpenAPI definitions
    $definitionIssues = Test-PodeOADefinition

    if (! $definitionIssues.valid) {
        Write-PodeHost 'Undefined OpenAPI References :' -ForegroundColor Red
        foreach ($tag in $definitionIssues.issues.keys) {
            Write-PodeHost "  Definition $tag :" -ForegroundColor Red
            if($definitionIssues.issues[$tag].definition ){
                Write-PodeHost '     OpenAPI generation deocument error: ' -ForegroundColor Red
                Write-PodeHost "       $definitionIssues.issues[$tag].definition" -ForegroundColor Red
            }
            if($definitionIssues.issues[$tag].title ) {
                Write-PodeHost '     info.title is mandatory' -ForegroundColor Red
            }
            if($definitionIssues.issues[$tag].version ) {
                Write-PodeHost '     info.version is mandatory' -ForegroundColor Red
            }
            if($definitionIssues.issues[$tag].components ) {
                Write-PodeHost '     Missing component(s)' -ForegroundColor Red
                foreach ($key in $definitionIssues.issues[$tag].components.keys) {
                    $occurences = $definitionIssues.issues[$tag].components[$key]
                    if ( $PodeContext.Server.OpenAPI[$tag].hiddenComponents.schemaValidation) {
                        $occurences = $occurences / 2
                    }
                    Write-PodeHost "      `$refs : $key ($occurences)" -ForegroundColor Red
                }
            }
            Write-PodeHost
        }
        throw 'OpenAPI document compliance issues'
    }
}





<#
.SYNOPSIS
Check the OpenAPI component exist (Internal Function)

.DESCRIPTION
Check the OpenAPI component exist (Internal Function)

.PARAMETER Field
The component type

.PARAMETER Name
The component Name

.PARAMETER DefinitionTag
An Array of strings representing the unique tag for the API specification.
This tag helps in distinguishing between different versions or types of API specifications within the application.
You can use this tag to reference the specific API documentation, schema, or version that your function interacts with.

.PARAMETER ThrowException
Generate an exception if the component doesn't exist

.PARAMETER PostValidation
Postpone the check before the server start

.EXAMPLE
Test-PodeOAComponentInternal -Field 'responses' -Name 'myresponse' -DefinitionTag 'default'
#>
function Test-PodeOAComponentInternal {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet( 'schemas' , 'responses' , 'parameters' , 'examples' , 'requestBodies' , 'headers' , 'securitySchemes' , 'links' , 'callbacks' , 'pathItems'  )]
        [string]
        $Field,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [string[]]
        $DefinitionTag,

        [switch]
        $ThrowException,

        [switch]
        $PostValidation
    )

    $DefinitionTag = Test-PodeOADefinitionTag -Tag $DefinitionTag
    if ($PostValidation.IsPresent) {
        foreach ($tag in $DefinitionTag) {
            if (! ($PodeContext.Server.OpenAPI[$tag].hiddenComponents.postValidation[$field].keys -ccontains $Name)) {
                $PodeContext.Server.OpenAPI[$tag].hiddenComponents.postValidation[$field][$name] = 1
            } else {
                $PodeContext.Server.OpenAPI[$tag].hiddenComponents.postValidation[$field][$name] += 1
            }
        }
    } else {
        foreach ($tag in $DefinitionTag) {
            if (!($PodeContext.Server.OpenAPI[$tag].components[$field].keys -ccontains $Name)) {
                # If $Name is not found in the current $tag, return $false or throw an exception
                if ($ThrowException.IsPresent ) {
                    throw "No components of type $field named $Name are available in the $tag definition."
                } else {
                    return $false
                }
            }
        }
        if (!$ThrowException.IsPresent) {
            return $true
        }
    }
}