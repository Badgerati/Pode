# Overview

Pode has built-in support for converting your routes into OpenAPI 3.0 definitions. There is also support for enabling simple Swagger and/or ReDoc viewers and others.

The OpenApi module has been extended with many more functions, and some old ones have been improved.

For more detailed information regarding OpenAPI and Pode, please refer to [OpenAPI Specification and Pode](../Specification/v3_0_3.md)

You can enable OpenAPI in Pode, and a straightforward definition will be generated. However, to get a more complex definition with request bodies, parameters, and response payloads, you'll need to use the relevant OpenAPI functions detailed below.

## Enabling OpenAPI

To enable support for generating OpenAPI definitions you'll need to use the [`Enable-PodeOpenApi`](../../../Functions/OpenApi/Enable-PodeOpenApi) function. This will allow you to set a title and version for your API. You can also set a default route to retrieve the OpenAPI definition for tools like Swagger or ReDoc, the default is at `/openapi`.

You can also set a route filter (such as `/api/*`, the default is `/*` for everything), so only those routes are included in the definition.

An example of enabling OpenAPI is a follows:

```powershell
Enable-PodeOpenApi -Title 'My Awesome API' -Version 9.0.0.1
```

An example of setting the OpenAPI route is a follows. This will create a route accessible at `/docs/openapi`:

```powershell
Enable-PodeOpenApi -Path '/docs/openapi' -Title 'My Awesome API' -Version 9.0.0.1
```

### Default Setup

In the very simplest of scenarios, just enabling OpenAPI will generate a minimal definition. It can be viewed in Swagger/ReDoc etc, but won't be usable for trying calls.

When you enable OpenAPI, and don't set any other OpenAPI data, the following is the minimal data that is included:

* Every route will have a 200 and Default response
* Although routes will be included, no request bodies, parameters or response payloads will be defined
* If you have multiple endpoints, then the servers section will be included
* Any authentication will be included

This can be changed with [`Enable-PodeOpenApi`](../../../Functions/OpenApi/Enable-PodeOpenApi)

For example to change the default response 404 and 500

```powershell
Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'  -DefaultResponses (
        New-PodeOAResponse -StatusCode 404 -Description 'User not found' | Add-PodeOAResponse -StatusCode 500
    )
```

For disabling the Default Response use:

```powershell
Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3' -NoDefaultResponses
```

For disabling the Minimal Definitions feature use:

```powershell
Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3' -DisableMinimalDefinitions
```

### Get Definition

Instead of defining a route to return the definition, you can write the definition to the response whenever you want, and in any route, using the [`Get-PodeOADefinition`](../../../Functions/OpenApi/Get-PodeOADefinition) function. This could be useful in certain scenarios like in Azure Functions, where you can enable OpenAPI, and then write the definition to the response of a GET request if some query parameter is set; eg: `?openapi=1`.

For example:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    if ($WebEvent.Query.openapi -eq 1) {
        Get-PodeOpenApiDefinition | Write-PodeJsonResponse
    }
}
```

## OpenAPI Info object

In previous releases some of the Info object properties like Version and Title were defined by [`Enable-PodeOpenApi`](../../../Functions/OpenApi/Enable-PodeOpenApi).
Starting from version 2.10 a new [`Add-PodeOAInfo`](../../../Functions/OpenApi/Add-PodeOAInfo) function has been added to create a full OpenAPI Info spec.

```powershell
Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' `
        -Version 1.0.17 `
        -Description $InfoDescription `
        -TermsOfService 'http://swagger.io/terms/' `
        -LicenseName 'Apache 2.0' `
        -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' `
        -ContactName 'API Support' `
        -ContactEmail 'apiteam@swagger.io'
```

## OpenAPI configuration Best Practice

Pode is rich of functions to create and configure an complete OpenApi spec. Here is a typical code you should use to initiate an OpenApi spec

```powershell
#Initialize OpenApi
Enable-PodeOpenApi -Path '/docs/openapi' -Title 'Swagger Petstore - OpenAPI 3.0' `
    -OpenApiVersion 3.1 -DisableMinimalDefinitions -NoDefaultResponses

# OpenApi Info
Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' `
    -Version 1.0.17 `
    -Description 'This is a sample Pet Store Server based on the OpenAPI 3.0 specification. ...' `
    -TermsOfService 'http://swagger.io/terms/' `
    -LicenseName 'Apache 2.0' `
    -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' `
    -ContactName 'API Support' `
    -ContactEmail 'apiteam@swagger.io' `
    -ContactUrl 'http://example.com/support'

# Endpoint for the API
    Add-PodeOAServerEndpoint -url '/api/v3.1' -Description 'default endpoint'

    # OpenApi external documentation links
    $extDoc = New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
    $extDoc | Add-PodeOAExternalDoc

    # OpenApi documentation viewer
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc'
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc'
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight'
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'
```

## Authentication

Any authentication defined, either by [`Add-PodeAuthMiddleware`](../../../Functions/Authentication/Add-PodeAuthMiddleware), or using the `-Authentication` parameter on Routes, will be automatically added to the `security` section of the OpenAPI definition.


## Tags

In OpenAPI, a "tag" is used to group related operations. Tags are often used to organize and categorize endpoints in an API specification, making it easier to understand and navigate the API documentation. Each tag can be associated with one or more API operations, and these tags are then used in tools like Swagger UI to group and display operations in a more organized way.

Here's an example of how to define and use tags:

```powershell
# create an External Doc reference
$swaggerDocs = New-PodeOAExternalDoc -Description 'Find out more about Swagger' -Url 'http://swagger.io'

# create a Tag
Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc $swaggerDocs

Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'Login-OAuth2' -Scope 'read' -AllowAnon -ScriptBlock {
    #route code
} | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma-separated strings' `
    -Tags 'pet' -OperationId 'findPetsByStatus'
```

## Routes

To extend the definition of a route, you can use the `-PassThru` switch on the [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute) function. This will cause the route that was created to be returned, so you can pass it down the pipe into more OpenAPI functions.

To add metadata to a route's definition you can use the [`Set-PodeOARouteInfo`](../../../Functions/OpenApi/Set-PodeOARouteInfo) function. This will allow you to define a summary/description for the route, as well as tags for grouping:

```powershell
Add-PodeRoute -Method Get -Path "/api/resources" -ScriptBlock {
    Set-PodeResponseStatus -Code 200
} -PassThru |
    Set-PodeOARouteInfo -Summary 'Retrieve some resources' -Tags 'Resources'
```

Each of the following OpenAPI functions have a `-PassThru` switch, allowing you to chain many of them together.

### Responses

You can define multiple responses for a route, but only one of each status code, using the [`Add-PodeOAResponse`](../../../Functions/OpenApi/Add-PodeOAResponse) function. You can either just define the response and status code, with a custom description, or with a schema defining the payload of the response.

The following is an example of defining simple 200 and 404 responses on a route:

```powershell
Add-PodeRoute -Method Get -Path "/api/user/:userId" -ScriptBlock {
    # logic
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -PassThru |
    Add-PodeOAResponse -StatusCode 404 -Description 'User not found'
```

Whereas the following is a more complex definition, which also defines the responses JSON payload. This payload is defined as an object with a string Name, and integer UserId:

```powershell
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
    }
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Description 'A user object' --Content @{
        'application/json' = (New-PodeOAStringProperty -Name 'Name'|
            New-PodeOAIntProperty -Name 'UserId'| New-PodeOAObjectProperty)
    }
```

the JSON response payload defined is as follows:

```json
{
    "Name": [string],
    "UserId": [integer]
}
```

In case the response JSON payload is an array

```powershell
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Name   = 'Rick'
            UserId = $WebEvent.Parameters['userId']
        }
    } -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'A user object' -Content (
            New-PodeOAContentMediaType -ContentMediaType 'application/json' -Array -Content (
                New-PodeOAStringProperty -Name 'Name' |
                    New-PodeOAIntProperty -Name 'UserId' |
                    New-PodeOAObjectProperty
                )
            )
```

```json
[
    {
        "Name": [string],
        "UserId": [integer]
    }
]
```

Internally, each route is created with an empty default 200 and 500 response. You can remove these, or other added responses, by using [`Remove-PodeOAResponse`](../../../Functions/OpenApi/Remove-PodeOAResponse):

```powershell
Add-PodeRoute -Method Get -Path "/api/user/:userId" -ScriptBlock {
    # route logic
} -PassThru |
    Remove-PodeOAResponse -StatusCode 200
```

### Requests

#### Parameters

You can set route parameter definitions, such as parameters passed in the path/query, by using the [`Set-PodeOARequest`](../../../Functions/OpenApi/Set-PodeOARequest) function with the `-Parameters` parameter. The parameter takes an array of properties converted into parameters, using the [`ConvertTo-PodeOAParameter`](../../../Functions/OpenApi/ConvertTo-PodeOAParameter) function.

For example, to create some integer `userId` parameter that is supplied in the path of the request, the following will work:

```powershell
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
    }
} -PassThru |
    Set-PodeOARequest -Parameters @(
        (New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Path)
    )
```

Whereas you could use the next example to define 2 query parameters, both strings:

```powershell
Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Query['name']
    }
} -PassThru |
    Set-PodeOARequest -Parameters (
        (New-PodeOAStringProperty -Name 'name' -Required | ConvertTo-PodeOAParameter -In Query),
        (New-PodeOAStringProperty -Name 'city' -Required | ConvertTo-PodeOAParameter -In Query)
    )
```

#### Payload

You can set request payload schemas by using the [`Set-PodeOARequest`](../../../Functions/OpenApi/Set-PodeOARequest)function, with the `-RequestBody` parameter. The request body can be defined using the [`New-PodeOARequestBody`](../../../Functions/OpenApi/New-PodeOARequestBody) function, and supplying schema definitions for content types - this works in very much a similar way to defining responses above.

For example, to define a request JSON payload of some `userId` and `name` you could use the following:

```powershell
Add-PodeRoute -Method Patch -Path '/api/users' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = $WebEvent.Data.name
        UserId = $WebEvent.Data.userId
    }
} -PassThru |
    Set-PodeOARequest -RequestBody (
        New-PodeOARequestBody -Required -Content (
        New-PodeOAContentMediaType -ContentMediaType 'application/json','application/xml' -Content (  New-PodeOAStringProperty -Name 'Name'| New-PodeOAIntProperty -Name 'UserId'| New-PodeOAObjectProperty ) )

    )
```

The expected payload would look as follows:

```json
{
    "name": [string],
    "userId": [integer]
}
```

```xml
<Object>
    <name type="string"></name>
    <userId type="integer"></userId>
</Object>

```

  