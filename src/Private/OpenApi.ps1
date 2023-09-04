function ConvertTo-PodeOAContentTypeSchema
{
    param(
        [Parameter(ValueFromPipeline = $true)] 
        [hashtable]
        $Schemas,
        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Array 
    )

    if (Test-PodeIsEmpty $Schemas)
    {
        return $null
    }

    # ensure all content types are valid
    foreach ($type in $Schemas.Keys)
    {
        if ($type -inotmatch '^\w+\/[\w\.\+-]+$')
        {
            throw "Invalid content-type found for schema: $($type)"
        }
    }

    # convert each schema to openapi format
    return (ConvertTo-PodeOAObjectSchema -Schemas $Schemas -Array:$Array)
}

function ConvertTo-PodeOAHeaderSchema
{
    param(
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, Position = 0)]
        [string[]]$Schemas,
        [Parameter(ValueFromPipeline = $false)]
        [switch]
        $Array 
    )
    begin
    { 
        $obj = @{}
    }
    process
    {
        # convert each schema to openapi format
        #  return (ConvertTo-PodeOAObjectSchema -Schemas $Schemas)
        foreach ($schema in $Schemas)
        {
            if ( !(Test-PodeOAComponentHeaderSchema -Name $schema))
            {
                throw "The OpenApi component schema doesn't exist: $schema"
            }  
            if ($Array)
            {
                $obj[$schema] = @{ 
                    'description' = $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema].description
                    'schema'      = @{
                        'type'  = 'array'
                        'items' = ($PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema] | ConvertTo-PodeOASchemaProperty -NoDescription )
                    }
                }      
            }
            else
            {
                $obj[$schema] = @{ 
                    'description' = $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema].description
                    'schema'      = ($PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas[$schema] | ConvertTo-PodeOASchemaProperty -NoDescription ) 
                }            
            } 
        }
    }
    end
    {
        return $obj
    }
}

function ConvertTo-PodeOAObjectSchema
{
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
    foreach ($type in $Schemas.Keys)
    {
        $obj[$type] = @{
            schema = $null
        } 
        if ($Array)
        {
            $obj[$type].schema = @{
                'type'  = 'array'
                'items' = $null
            }
        }
        # add a shared component schema reference
        if ($Schemas[$type] -is [string])
        {
            if (@('string', 'integer' , 'number', 'boolean' ) -contains $Schemas[$type])
            {
                if ($Array)
                {
                    $obj[$type].schema.items = @{
                        'type' = $Schemas[$type]
                    }
                }
                else
                {
                    $obj[$type].schema = @{
                        'type' = $Schemas[$type]
                    }
                }
            }
            else
            {
                if ( !(Test-PodeOAComponentSchema -Name $Schemas[$type]))
                {
                    throw "The OpenApi component schema doesn't exist: $($Schemas[$type])"
                } 
                if ($Array)
                {
                    $obj[$type].schema.items = @{
                        '$ref' = "#/components/schemas/$($Schemas[$type])"
                    }
                }
                else
                {
                    $obj[$type].schema = @{
                        '$ref' = "#/components/schemas/$($Schemas[$type])"
                    }
                }
            }
        }  
        # add a set schema object
        else
        {
            $obj[$type].schema = ($Schemas[$type] | ConvertTo-PodeOASchemaProperty)
        } 
    }

    return $obj
}

function Test-PodeOAExternalDoc
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.externalDocs.ContainsKey($Name)
}
function Test-PodeOAComponentHeaderSchema
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.headerSchemas.ContainsKey($Name)
}

function Test-PodeOAComponentSchemaJson
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.hiddenComponents.schemaJson.ContainsKey($Name)
} 

function Test-PodeOAComponentSchema
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.schemas.ContainsKey($Name)
}

function Test-PodeOAComponentResponse
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.responses.ContainsKey($Name)
}

function Test-PodeOAComponentRequestBody
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.requestBodies.ContainsKey($Name)
}

function Test-PodeOAComponentParameter
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return $PodeContext.Server.OpenAPI.components.parameters.ContainsKey($Name)
}

function ConvertTo-PodeOASchemaProperty
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Property,

        [switch]
        $InObject,

        [switch]
        $NoDescription
    )

    # base schema type
    $schema = @{
        type = $Property.type 
    }


    if (!$NoDescription -and $Property.description)
    {
        $schema['description'] = $Property.description
    }

    if ($Property.format)
    {
        $schema['format'] = $Property.format
    }

    if ($Property.default)
    {
        $schema['default'] = $Property.default
    }

    if ($Property.deprecated)
    {
        $schema['deprecated'] = $Property.deprecated
    }

    

    if ($Property.required -and !$InObject)
    {
        $schema['required'] = $Property.required
    }  

    if ($null -ne $Property.meta)
    {
        foreach ($key in $Property.meta.Keys)
        {
            $schema[$key] = $Property.meta[$key]
        }
    }

    # schema refs
    if ($Property.type -ieq 'schema')
    {
        $schema = @{
            '$ref' = "#/components/schemas/$($Property['schema'])"
        }
    }

    # are we using an array?
    if ($Property.array)
    {
        if ($Property.maxItems )
        {
            $schema['maxItems'] = $Property.maxItems
        }
    
        if ($Property.minItems )
        {
            $schema['minItems'] = $Property.minItems
        }
    
        if ($Property.uniqueItems )
        {
            $schema['uniqueItems'] = $Property.uniqueItems
        } 

        if ($Property.explode )
        {
            $schema['explode'] = $Property.explode
        }

        $Property.array = $false
        $schema['type'] = 'array'
        $schema['items'] = ($Property | ConvertTo-PodeOASchemaProperty)         
        $Property.array = $true
        return $schema
    }
    
    if ($Property.object)
    {
        # are we using an object?
        $Property.object = $false

        $schema = @{
            type       = 'object'
            properties = (ConvertTo-PodeOASchemaObjectProperty -Properties $Property)
        }

        if ($Property.required)
        {
            $schema['required'] = @($Property.name)
        } 
    }

    if ($Property.type -ieq 'object')
    {
        $schema['properties'] = (ConvertTo-PodeOASchemaObjectProperty -Properties $Property.properties)

        $RequiredList = @(($Property.properties | Where-Object { $_.required }) )
        if ( $RequiredList.Count -gt 0)
        {
            $schema['required'] = @($RequiredList.Name) 
        }

        if ($Property.explode )
        {
            $schema['explode'] = $Property.explode
        }

        if ($Property.xml )
        { 
            $schema['xml'] = @{} 
            foreach ($key in $Property.xml.Keys)
            {
                $schema['xml'].$key = $Property.xml.$key
            } 
        }
    }

    return $schema
}

function ConvertTo-PodeOASchemaObjectProperty
{
    param(
        [Parameter(Mandatory = $true)]
        [hashtable[]]
        $Properties
    )

    $schema = @{}

    foreach ($prop in $Properties)
    {
        $schema[$prop.name] = ($prop | ConvertTo-PodeOASchemaProperty -InObject)
    }

    return $schema
}

function Get-PodeOpenApiDefinitionInternal
{
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Title,     

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
    $def = @{
        openapi = '3.0.2'
    }

    # metadata
    $def['info'] = @{
        title       = $Title
        version     = $MetaInfo.Version 
        description = $MetaInfo.Description      
    } 
    if ($MetaInfo.ExtraInfo)
    {
        $def['info'] += $MetaInfo.ExtraInfo
    }
    if ($MetaInfo.ExternalDocs)
    {
        $def['externalDocs'] = $MetaInfo.ExternalDocs
    } 
    # servers 
    if (!$MetaInfo.RestrictRoutes -and ($PodeContext.Server.Endpoints.Count -gt 1))
    {
        $def['servers'] = $null
        $def.servers = @(foreach ($endpoint in $PodeContext.Server.Endpoints.Values)
            {
                @{
                    url         = $endpoint.Url
                    description = (Protect-PodeValue -Value $endpoint.Description -Default $endpoint.Name)
                }
            })
    }
    else
    { 
        #$def['servers'] = @(@{'url' = $MetaInfo.RouteFilter.TrimEnd('/', '*') })
    }

    
    if ($PodeContext.Server.OpenAPI.tags)
    {
        $def['tags'] = $PodeContext.Server.OpenAPI.tags.Values
    }
    # components
    $def['components'] = $PodeContext.Server.OpenAPI.components

    # auth/security components
    if ($PodeContext.Server.Authentications.Methods.Count -gt 0)
    {
        if ($null -eq $def.components.securitySchemes)
        {
            $def.components.securitySchemes = @{}
        }

        foreach ($authName in $PodeContext.Server.Authentications.Methods.Keys)
        {
            $authType = (Find-PodeAuth -Name $authName).Scheme
            $_authName = ($authName -replace '\s+', '')

            $_authObj = @{}
            if ($authType.Scheme -ieq 'apikey')
            {
                $_authObj = @{
                    type = $authType.Scheme
                    in   = $authType.Arguments.Location.ToLowerInvariant()
                    name = $authType.Arguments.LocationName
                }
            }
            else
            {
                $_authObj = @{
                    type   = $authType.Scheme.ToLowerInvariant()
                    scheme = $authType.Name.ToLowerInvariant()
                }
            }

            $def.components.securitySchemes[$_authName] = $_authObj
        }

        if ($PodeContext.Server.OpenAPI.Security.Length -gt 0)
        {
            $def['security'] = @($PodeContext.Server.OpenAPI.Security.Definition)
        }
    }

    # paths
    $def['paths'] = @{}
    $filter = "^$($MetaInfo.RouteFilter)"

    foreach ($method in $PodeContext.Server.Routes.Keys)
    {
        foreach ($path in ($PodeContext.Server.Routes[$method].Keys | Sort-Object))
        {
            # does it match the route?
            if ($path -inotmatch $filter)
            {
                continue
            }

            # the current route
            $_routes = @($PodeContext.Server.Routes[$method][$path])
            if ($MetaInfo.RestrictRoutes)
            {
                $_routes = @(Get-PodeRoutesByUrl -Routes $_routes -EndpointName $EndpointName)
            }

            # continue if no routes
            if (($_routes.Length -eq 0) -or ($null -eq $_routes[0]))
            {
                continue
            }

            # get the first route for base definition
            $_route = $_routes[0]

            # do nothing if it has no responses set
            if ($_route.OpenApi.Responses.Count -eq 0)
            {
                continue
            }

            # add path to defintion
            if ($null -eq $def.paths[$_route.OpenApi.Path])
            {
                $def.paths[$_route.OpenApi.Path] = @{}
            }

            # add path's http method to defintition
            $def.paths[$_route.OpenApi.Path][$method] = @{
                tags        = @($_route.OpenApi.Tags)
                summary     = $_route.OpenApi.Summary
                description = $_route.OpenApi.Description
                operationId = $_route.OpenApi.OperationId 
                requestBody = $_route.OpenApi.RequestBody
                responses   = $_route.OpenApi.Responses
                parameters  = $_route.OpenApi.Parameters 
                servers     = $null
                security    = @($_route.OpenApi.Authentication)
            }

            if ($_route.OpenApi.Deprecated)
            {
                $def.paths[$_route.OpenApi.Path][$method]['deprecated'] = $_route.OpenApi.Deprecated
            }

            # add global authentication for route
            if (($null -ne $def['security']) -and ($def['security'].Length -gt 0))
            {
                foreach ($sec in $PodeContext.Server.OpenAPI.Security)
                {
                    if ([string]::IsNullOrWhiteSpace($sec.Route) -or ($sec.Route -ieq '/') -or ($sec.Route -ieq $_route.OpenApi.Path) -or ($_route.OpenApi.Path -imatch "^$($sec.Route)$"))
                    {
                        $def.paths[$_route.OpenApi.Path][$method].security += $sec.Definition
                    }
                }
            }

            if ($def.paths[$_route.OpenApi.Path][$method].security.Length -eq 0)
            {
                $def.paths[$_route.OpenApi.Path][$method].Remove('security')
            }

            # add any custom server endpoints for route
            foreach ($_route in $_routes)
            {
                if ([string]::IsNullOrWhiteSpace($_route.Endpoint.Address) -or ($_route.Endpoint.Address -ieq '*:*'))
                {
                    continue
                }

                if ($null -eq $def.paths[$_route.OpenApi.Path][$method].servers)
                {
                    $def.paths[$_route.OpenApi.Path][$method].servers = @()
                }

                $serverDef = $null
                if (![string]::IsNullOrWhiteSpace($_route.Endpoint.Name))
                {
                    $serverDef = @{
                        url = (Get-PodeEndpointByName -Name $_route.Endpoint.Name).Url
                    }
                }
                else
                {
                    $serverDef = @{
                        url = "$($_route.Endpoint.Protocol)://$($_route.Endpoint.Address)"
                    }
                }

                if ($null -ne $serverDef)
                {
                    $def.paths[$_route.OpenApi.Path][$method].servers += $serverDef
                }
            }
        }
    }

    # remove all null values (swagger hates them)
    $def | Remove-PodeNullKeysFromHashtable
    return $def
}

function ConvertTo-PodeOAPropertyFromCmdletParameter
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.ParameterMetadata]
        $Parameter
    )

    if ($Parameter.SwitchParameter -or ($Parameter.ParameterType.Name -ieq 'boolean'))
    {
        New-PodeOABoolProperty -Name $Parameter.Name
    }
    else
    {
        switch ($Parameter.ParameterType.Name)
        {
            { @('int32', 'int64') -icontains $_ }
            {
                New-PodeOAIntProperty -Name $Parameter.Name -Format $_
            }

            { @('double', 'float') -icontains $_ }
            {
                New-PodeOANumberProperty -Name $Parameter.Name -Format $_
            }
        }
    }

    New-PodeOAStringProperty -Name $Parameter.Name
}

function Get-PodeOABaseObject
{
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
        tags             = @{}
        hiddenComponents = @{
            headerSchemas = @{}
            externalDocs  = @{}
            schemaJson    = @{}
        } 
    }
}

function Set-PodeOAAuth
{
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Route,

        [Parameter()]
        [string[]]
        $Name
    )

    foreach ($n in @($Name))
    {
        if (!(Test-PodeAuth -Name $n))
        {
            throw "Authentication method does not exist: $($n)"
        }
    }

    foreach ($r in @($Route))
    {
        $r.OpenApi.Authentication = @(foreach ($n in @($Name))
            {
                @{
                    "$($n -replace '\s+', '')" = @()
                }
            })
    }
}

function Set-PodeOAGlobalAuth
{
    param(
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Route
    )

    if (!(Test-PodeAuth -Name $Name))
    {
        throw "Authentication method does not exist: $($Name)"
    }

    if (Test-PodeIsEmpty $PodeContext.Server.OpenAPI.Security)
    {
        $PodeContext.Server.OpenAPI.Security = @()
    }

    $PodeContext.Server.OpenAPI.Security += @{
        Definition = @{
            "$($Name -replace '\s+', '')" = @()
        }
        Route      = (ConvertTo-PodeRouteRegex -Path $Route)
    }
}

function Resolve-References ($obj, $schemas)
{ 
    $Keys = @()
    foreach ($item in $obj.properties.Keys)
    {
        $Keys += $item
    }
    foreach ($key in $Keys)
    {
        if ($obj.properties[$key].type -eq 'object')
        {
            Resolve-References -obj $obj.properties[$key].properties -schemas $schemas
        }
        elseif ($obj.properties[$key].'$ref')
        {  
            $refName = ($obj.properties[$key].'$ref') -replace '#/components/schemas/', ''
            if ($schemas.ContainsKey($refName))
            {
                $obj.properties[$key] = $schemas[$refName] 
            }
        }
    } 
} 