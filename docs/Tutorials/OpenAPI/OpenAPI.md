# Overview


Pode has built-in support for converting your routes into OpenAPI 3.0 definitions. There is also support for enabling simple Swagger and/or ReDoc viewers and others.

The OpenApi module has been extended with many more functions, and some old ones have been improved.

For more detailed information regarding OpenAPI and Pode, please refer to [OpenAPI Specification and Pode](../Specification/v3_0_3.md)

You can enable OpenAPI in Pode, and a straightforward definition will be generated. However, to get a more complex definition with request bodies, parameters, and response payloads, you'll need to use the relevant OpenAPI functions detailed below.

## Enabling OpenAPI

To enable support for generating OpenAPI definitions you'll need to use the [`Enable-PodeOpenApi`] function. This will allow you to set a title and version for your API. You can also set a default route to retrieve the OpenAPI definition for tools like Swagger or ReDoc, the default is at `/openapi`.

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

This can be changed with [`Enable-PodeOpenApi`]

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

Instead of defining a route to return the definition, you can write the definition to the response whenever you want, and in any route, using the [`Get-PodeOADefinition`] function. This could be useful in certain scenarios like in Azure Functions, where you can enable OpenAPI, and then write the definition to the response of a GET request if some query parameter is set; eg: `?openapi=1`.

For example:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    if ($WebEvent.Query.openapi -eq 1) {
        Get-PodeOpenApiDefinition | Write-PodeJsonResponse
    }
}
```

## OpenAPI Info object

In previous releases some of the Info object properties like Version and Title were defined by [`Enable-PodeOpenApi`].
Starting from version 2.10 a new [`Add-PodeOAInfo`] function has been added to create a full OpenAPI Info spec.

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

Any authentication defined, either by [`Add-PodeAuthMiddleware`], or using the `-Authentication` parameter on Routes, will be automatically added to the `security` section of the OpenAPI definition.


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

To extend the definition of a route, you can use the `-PassThru` switch on the [`Add-PodeRoute`] function. This will cause the route that was created to be returned, so you can pass it down the pipe into more OpenAPI functions.

To add metadata to a route's definition you can use the [`Set-PodeOARouteInfo`] function. This will allow you to define a summary/description for the route, as well as tags for grouping:

```powershell
Add-PodeRoute -Method Get -Path "/api/resources" -ScriptBlock {
    Set-PodeResponseStatus -Code 200
} -PassThru |
    Set-PodeOARouteInfo -Summary 'Retrieve some resources' -Tags 'Resources'
```

Each of the following OpenAPI functions have a `-PassThru` switch, allowing you to chain many of them together.

### Responses

You can define multiple responses for a route, but only one of each status code, using the [`Add-PodeOAResponse`] function. You can either just define the response and status code, with a custom description, or with a schema defining the payload of the response.

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

Internally, each route is created with an empty default 200 and 500 response. You can remove these, or other added responses, by using [`Remove-PodeOAResponse`]:

```powershell
Add-PodeRoute -Method Get -Path "/api/user/:userId" -ScriptBlock {
    # route logic
} -PassThru |
    Remove-PodeOAResponse -StatusCode 200
```

### Requests

#### Parameters

You can set route parameter definitions, such as parameters passed in the path/query, by using the [`Set-PodeOARequest`] function with the `-Parameters` parameter. The parameter takes an array of properties converted into parameters, using the [`ConvertTo-PodeOAParameter`] function.

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

You can set request payload schemas by using the [`Set-PodeOARequest`]function, with the `-RequestBody` parameter. The request body can be defined using the [`New-PodeOARequestBody`] function, and supplying schema definitions for content types - this works in very much a similar way to defining responses above.

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

## Components

You can define reusable OpenAPI components in Pode. Currently supported are Schemas, Parameters, Request Bodies, and Responses.

### Schemas

To define a reusable schema that can be used in request bodies, and responses, you can use the [`Add-PodeOAComponentSchema`] function. You'll need to supply a Name, and a Schema that can be reused.

The following is an example of defining a schema which is a object of Name, UserId, and Age:

```powershell
# define a reusable schema user object
New-PodeOAStringProperty -Name 'Name' |
  New-PodeOAIntProperty -Name 'UserId' |
  New-PodeOAIntProperty -Name 'Age' |
  New-PodeOAObjectProperty |
  Add-PodeOAComponentSchema -Name 'UserSchema'

# reuse the above schema in a response
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
        Age = 42
    }
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Description 'A list of users' -Content @{
        'application/json' = 'UserSchema'
    }
```

### Request Bodies

To define a reusable request bodies you can use the [`Add-PodeOAComponentRequestBody`] function. You'll need to supply a Name, as well as the needed schemas for each content type.

The following is an example of defining a JSON object that a Name, UserId, and an Enable flag:

```powershell
# define a reusable request body
New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/x-www-form-urlencoded' -Content (
    New-PodeOAStringProperty -Name 'Name' |
        New-PodeOAIntProperty -Name 'UserId' |
        New-PodeOABoolProperty -Name 'Enabled' |
        New-PodeOAObjectProperty
    ) | Add-PodeOAComponentRequestBody -Name 'UserBody' -Required

# use the request body in a route
Add-PodeRoute -Method Patch -Path '/api/users' -ScriptBlock {
    Set-PodeResponseStatus -StatusCode 200
} -PassThru |
    Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'UserBody')
```

The JSON payload expected is of the format:

```json
{
    "Name": [string],
    "UserId": [integer],
    "Enabled": [boolean]
}
```

### Parameters

To define reusable parameters that are used on requests, you can use the [`Add-PodeOAComponentParameter`] function. You'll need to supply a Name and the Parameter definition.

The following is an example of defining an integer path parameter for a `userId`, and then using that parameter on a route.

```powershell
# define a reusable {userid} path parameter
New-PodeOAIntProperty -Name 'userId' -Required | ConvertTo-PodeOAParameter -In Path |Add-PodeOAComponentParameter -Name 'UserId'

# use this parameter in a route
Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
    Write-PodeJsonResponse -Value @{
        Name = 'Rick'
        UserId = $WebEvent.Parameters['userId']
    }
} -PassThru |
    Set-PodeOARequest -Parameters @(ConvertTo-PodeOAParameter -Reference 'UserId')
```

### Responses

To define a reusable response definition you can use the [`Add-PodeOAComponentResponse`] function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

The following is an example of defining a 200 response with a JSON payload of an array of objects for Name/UserId. The Response component can be used by a route referencing the name:

```powershell
# defines a response with a json payload using New-PodeOAContentMediaType
Add-PodeOAComponentResponse -Name 'OK' -Description 'A user object' -Content (
        New-PodeOAContentMediaType -MediaType 'application/json' -Array -Content (
            New-PodeOAStringProperty -Name 'Name' |
                New-PodeOAIntProperty -Name 'UserId' |
                New-PodeOAObjectProperty
        )
    )

# reuses the above response on a route using its "OK" name
Add-PodeRoute -Method Get -Path "/api/users" -ScriptBlock {
    Write-PodeJsonResponse -Value @(
        @{ Name = 'Rick'; UserId = 123 },
        @{ Name = 'Geralt'; UserId = 124 }
    )
} -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Reference 'OK'
```

the JSON response payload defined is as follows:

```json
[
    {
        "Name": [string],
        "UserId": [integer]
    }
]
```


### Examples

To define a reusable example definition you can use the [`Add-PodeOAComponentExample`] function. You'll need to supply a Name, a Summary and a list of value representing the object.

The following is an example that defines three Pet examples request bodies, and how they're used in a Route's OpenAPI definition:

```powershell
 # defines the frog example
Add-PodeOAComponentExample -name 'frog-example' -Summary "An example of a frog with a cat's name" -Value @{
    name = 'Jaguar'; petType = 'Panthera'; color = 'Lion'; gender = 'Male'; breed = 'Mantella Baroni'
}
# defines the cat example
Add-PodeOAComponentExample   -Name 'cat-example' -Summary 'An example of a cat' -Value @{
    name = 'Fluffy'; petType = 'Cat'; color = 'White'; gender = 'male'; breed = 'Persian'
}
# defines the dog example
Add-PodeOAComponentExample -Name 'dog-example' -Summary   "An example of a dog with a cat's name" -Value @{
    name = 'Puma'; petType = 'Dog'; color = 'Black'; gender = 'Female'; breed = 'Mixed'
}

# reuses the examples
Add-PodeRoute -PassThru -Method Put -Path '/pet/:petId' -ScriptBlock {
    # route code
} | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data' -Tags 'pet' `
    -OperationId 'updatepet' -PassThru |
    Set-PodeOARequest  -Parameters @(
            (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
    ) -RequestBody (
        New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'Pet' } -Examples (
            New-PodeOAExample -ContentMediaType 'application/json', 'application/xml' -Reference 'cat-example' |
                New-PodeOAExample -ContentMediaType 'application/json', 'application/xml'   -Reference 'dog-example' |
                New-PodeOAExample -ContentMediaType 'application/json', 'application/xml' -Reference 'frog-example'
            )
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.'
```

### Headers

To define a reusable header definition you can use the [`Add-PodeOAComponentHeader`] function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

```powershell
 # define Headers
New-PodeOAIntProperty -Format Int32 -Description 'calls per hour allowed by the user' |
    Add-PodeOAComponentHeader -Name 'X-Rate-Limit'
New-PodeOAStringProperty -Format Date-Time -Description 'date in UTC when token expires' |
    Add-PodeOAComponentHeader -Name 'X-Expires-After'

Add-PodeRoute -PassThru -Method Get -Path '/user/login' -ScriptBlock {
    # route code
} | Set-PodeOARouteInfo -Summary 'Logs user into the system.' -Description 'Logs user into the system.' `
    -Tags 'user' -OperationId 'loginUser' -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' `
        -Header @('X-Rate-Limit', 'X-Expires-After')  -Content (
        New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'string'
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username/password supplied'
```


### CallBacks

To define a reusable callback definition you can use the [`Add-PodeOAComponentCallBack`] function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

```powershell
Add-PodeRoute -PassThru -Method Post -Path '/petcallbackReference'  -Authentication 'Login-OAuth2' `
    -Scope 'write'  -ScriptBlock {
    #route code
} | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' `
    -Tags 'pet' -OperationId 'petcallbackReference' -PassThru |
    Set-PodeOARequest -RequestBody ( New-PodeOARequestBody -Reference 'PetBodySchema' ) -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (
        New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet'
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -Content @{
        'application / json' = ( New-PodeOAStringProperty -Name 'result' |
                New-PodeOAStringProperty -Name 'message' |
                New-PodeOAObjectProperty )
        } -PassThru |
        Add-PodeOACallBack -Name 'test1'   -Reference 'test'
```

### Response Links

To define a reusable response link definition you can use the [`Add-PodeOAComponentResponseLink`] function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

```powershell
#Add link reference
Add-PodeOAComponentResponseLink -Name 'address' -OperationId 'getUserByName' -Parameters @{
    'username' = '$request.path.username'
}

#use link reference
Add-PodeRoute -PassThru -Method Put -Path '/userLinkByRef/:username' -ScriptBlock {
    Write-PodeJsonResponse -Value 'done' -StatusCode 200
} | Set-PodeOARouteInfo -Summary 'Update user' -Description 'This can only be done by the logged in user.' `
    -Tags 'user' -OperationId 'updateUserLinkByRef' -PassThru |
    Set-PodeOARequest -Parameters (
        ( New-PodeOAStringProperty -Name 'username' -Description ' name that need to be updated.' -Required | ConvertTo-PodeOAParameter -In Path )
    ) -RequestBody (
        New-PodeOARequestBody -Required -Content (
            New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User' }  -PassThru  -Links (
        New-PodeOAResponseLink -Name 'address2' -Reference 'address'
    ) |
    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
    Add-PodeOAResponse -StatusCode 404 -Description 'User not found' -PassThru |
    Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'
```

## Properties

Properties are used to create all Parameters and Schemas in OpenAPI. You can use the simple types on their own, or you can combine multiple of them together to form complex objects.

### Simple Types

There are 5 simple property types: Integers, Numbers, Strings, Booleans, and Schemas. Each of which can be created using the following functions:

* [`New-PodeOAIntProperty`]
* [`New-PodeOANumberProperty`]
* [`New-PodeOAStringProperty`]
* [`New-PodeOABoolProperty`]
* [`New-PodeOASchemaProperty`]
* [`New-PodeOAMultiTypeProperty`] (Note: OpenAPI 3.1 only)

These properties can be created with a Name, and other flags such as Required and/or a Description:

```powershell
# simple integer
New-PodeOAIntProperty -Name 'userId'

# a float number with a max value of 100
New-PodeOANumberProperty -Name 'ratio' -Format Float -Maximum 100

# a string with a default value, and enum of options
New-PodeOAStringProperty -Name 'type' -Default 'admin' -Enum @('admin', 'user')

# a boolean that's required
New-PodeOABoolProperty -Name 'enabled' -Required

# a schema property that references another component schema
New-PodeOASchemaProperty -Name 'Config' -Reference 'ConfigSchema'

# a string or an integer or a null value (only available with OpenAPI 3.1)
New-PodeOAMultiTypeProperty -Name 'multi' -Type integer,string -Nullable
```

On their own, like above, the simple properties don't really do much. However, you can combine that together to make complex objects/arrays as defined below.

### Arrays

There isn't a dedicated function to create an array property, instead there is an `-Array` switch on each of the property functions - both Object and the above simple properties.

If you supply the `-Array` switch to any of the above simple properties, this will define an array of that type - the `-Name` parameter can also be omitted if only a simple array if required.

For example, the below will define an integer array:

```powershell
New-PodeOAIntProperty -Array
```

When used in a Response, this could return the following JSON example:

```json
[
    0,
    1,
    2
]
```

### Objects

An object property is a combination of multiple other properties - both simple, array of more objects.

There are two ways to define objects:

1. Similar to arrays, you can use the `-Object` switch on the simple properties.
2. You can use the [`New-PodeOAObjectProperty`] function to combine multiple properties.

#### Simple

If you use the `-Object` switch on the simple property function, this will automatically wrap the property as an object. The Name for this is required.

For example, the below will define a simple `userId` integer object:

```powershell
New-PodeOAIntProperty -Name 'userId' -Object
```

In a response as JSON, this could look as follows:

```json
{
    "userId": 0
}
```

Furthermore, you can also supply both `-Array` and `-Object` switches:

```powershell
New-PodeOAIntProperty -Name 'userId' -Object -Array
```

This wil result in something like the following JSON:

```json
{
    "userId": [ 0, 1, 2 ]
}
```

#### Complex

Unlike the `-Object` switch that simply converts a single property into an object, the [`New-PodeOAObjectProperty`] function can combine and convert multiple properties.

For example, the following will create an object using an Integer, String, and a Boolean:

Legacy Definition

```powershell
New-PodeOAObjectProperty -Properties (
    (New-PodeOAIntProperty -Name 'userId'),
    (New-PodeOAStringProperty -Name 'name'),
    (New-PodeOABoolProperty -Name 'enabled')
)
```

Using piping (new in Pode 2.10)

```powershell
New-PodeOAIntProperty -Name 'userId'| New-PodeOAStringProperty -Name 'name'|
   New-PodeOABoolProperty -Name 'enabled' |New-PodeOAObjectProperty
```

As JSON, this could look as follows:

```json
{
    "userId": 0,
    "name": "Gary Goodspeed",
    "enabled": true
}
```

You can also supply the `-Array` switch to the [`New-PodeOAObjectProperty`] function. This will result in an array of objects. For example, if we took the above:

```powershell
New-PodeOAIntProperty -Name 'userId'| New-PodeOAStringProperty -Name 'name'|
   New-PodeOABoolProperty -Name 'enabled' |New-PodeOAObjectProperty -Array
```

As JSON, this could look as follows:

```json
[
    {
        "userId": 0,
        "name": "Gary Goodspeed",
        "enabled": true
    },
    {
        "userId": 1,
        "name": "Kevin",
        "enabled": false
    }
]
```

You can also combine objects into other objects:

```powershell
$usersArray = New-PodeOAIntProperty -Name 'userId'| New-PodeOAStringProperty -Name 'name'|
   New-PodeOABoolProperty -Name 'enabled' |New-PodeOAObjectProperty -Array

New-PodeOAObjectProperty -Properties @(
    (New-PodeOAIntProperty -Name 'found'),
    $usersArray
)
```

As JSON, this could look as follows:

```json
{
    "found": 2,
    "users": [
        {
            "userId": 0,
            "name": "Gary Goodspeed",
            "enabled": true
        },
        {
            "userId": 1,
            "name": "Kevin",
            "enabled": false
        }
    ]
}
```

### oneOf, anyOf and allOf Keywords

OpenAPI 3.x provides several keywords which you can use to combine schemas. You can use these keywords to create a complex schema or validate a value against multiple criteria.

* oneOf - validates the value against exactly one of the sub-schemas
* allOf - validates the value against all the sub-schemas
* anyOf - validates the value against any (one or more) of the sub-schemas

You can use the [`Merge-PodeOAProperty`] will instead define a relationship between the properties.

Unlike [`New-PodeOAObjectProperty`] which combines and converts multiple properties into an Object, [`Merge-PodeOAProperty`] will instead define a relationship between the properties.

For example, the following will create an something like an C Union object using an Integer, String, and a Boolean:

```powershell
Merge-PodeOAProperty -Type OneOf -ObjectDefinitions @(
            (New-PodeOAIntProperty -Name 'userId' -Object),
            (New-PodeOAStringProperty -Name 'name' -Object),
            (New-PodeOABoolProperty -Name 'enabled' -Object)
        )
```

Or

```powershell
New-PodeOAIntProperty -Name 'userId' -Object |
        New-PodeOAStringProperty -Name 'name' -Object |
        New-PodeOABoolProperty -Name 'enabled' -Object |
        Merge-PodeOAProperty -Type OneOf
```

As JSON, this could look as follows:

```json
{
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "userId": {
          "type": "integer"
        }
      }
    },
    {
      "type": "object",
      "properties": {
        "name": {
          "type": "string"
        }
      }
    },
    {
      "type": "object",
      "properties": {
        "enabled": {
          "type": "boolean",
          "default": false
        }
      }
    }
  ]
}
```

You can also supply a Component Schema created using [`Add-PodeOAComponentSchema`]. For example, if we took the above:

```powershell
    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 -ReadOnly |
        New-PodeOAStringProperty -Name 'username' -Example 'theUser' -Required |
        New-PodeOAStringProperty -Name 'firstName' -Example 'John' |
        New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
        New-PodeOAStringProperty -Name 'email' -Format email -Example 'john@email.com' |
        New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
        New-PodeOAStringProperty -Name 'password' -Format Password -Example '12345' -Required |
        New-PodeOAStringProperty -Name 'phone' -Example '12345' |
        New-PodeOAIntProperty -Name 'userStatus'-Format int32 -Description 'User Status' -Example 1|
        New-PodeOAObjectProperty  -Name 'User' -XmlName 'user'  |
        Add-PodeOAComponentSchema

    New-PodeOAStringProperty -Name 'street' -Example '437 Lytton' -Required |
        New-PodeOAStringProperty -Name 'city' -Example 'Palo Alto' -Required |
        New-PodeOAStringProperty -Name 'state' -Example 'CA' -Required |
        New-PodeOAStringProperty -Name 'zip' -Example '94031' -Required |
        New-PodeOAObjectProperty -Name 'Address' -XmlName 'address' -Description 'Shipping Address' |
        Add-PodeOAComponentSchema

    Merge-PodeOAProperty -Type AllOf -ObjectDefinitions 'Address','User'

```

As JSON, this could look as follows:

```json
{
  "allOf": [
    {
      "$ref": "#/components/schemas/Address"
    },
    {
      "$ref": "#/components/schemas/User"
    }
  ]
}
```
## Implementing Parameter Validation

Is possible to validate any parameter submitted by clients against an OpenAPI schema, ensuring adherence to defined standards.


First, schema validation has to be enabled using :

```powershell
Enable-PodeOpenApi   -EnableSchemaValidation #any other parameters needed
```

This command activates the OpenAPI feature with schema validation enabled, ensuring strict adherence to specified schemas.

Next, is possible to validate any route using `PodeOAJsonSchemaCompliance`.
In this example, we'll create a route for updating a pet:

```powershell
Add-PodeRoute -PassThru -Method Post -Path '/user' -ScriptBlock {
    $contentType = Get-PodeHeader -Name 'Content-Type'
    $responseMediaType = Get-PodeHeader -Name 'Accept'
    switch ($contentType) {
        'application/xml' {
            $user = ConvertFrom-PodeXml -node $WebEvent.data | ConvertTo-Json
        }
        'application/json' { $user = ConvertTo-Json $WebEvent.data }
        'application/x-www-form-urlencoded' { $user = ConvertTo-Json $WebEvent.data }
        default {
            Write-PodeHtmlResponse -StatusCode 415
            return
        }
    }
    $Validate = Test-PodeOAJsonSchemaCompliance -Json $user -SchemaReference 'User'
    if ($Validate.result) {
        $newUser = Add-user -User (convertfrom-json -InputObject $user -AsHashtable)
        Save-PodeState -Path $using:PetDataJson
        switch ($responseMediaType) {
            'application/xml' { Write-PodeXmlResponse -Value $newUser -StatusCode 200 }
            'application/json' { Write-PodeJsonResponse -Value $newUser -StatusCode 200 }
            default { Write-PodeHtmlResponse -StatusCode 415 }
        }
    }
    else {
        Write-PodeHtmlResponse -StatusCode 405 -Value  ($Validate.message -join ', ')
    }
} | Set-PodeOARouteInfo -Summary 'Create user.' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'createUser' -PassThru |
    Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )) -PassThru |
    Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input' -PassThru |
    Add-PodeOAResponse -Default -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml'  -Content 'User' )
```
#### Explanation
- The route handles different content types (JSON/XML) and converts them to JSON for validation.
- It validates the received pet object against the 'User' schema using the 'Test-PodeOAJsonSchemaCompliance' function.
- Depending on the validation result, appropriate HTTP responses are returned.
- OpenAPI metadata such as summary, description, request body, and responses are also defined for documentation purposes.



## OpenApi Documentation pages

If you're not using a custom OpenAPI viewer, then you can use one or more of the inbuilt which Pode supports: ones with Pode:

* Swagger
* ReDoc
* RapiDoc
* StopLight
* Explorer
* RapiPdf

For each you can customise the Route path to access the page on, but by default Swagger is at `/swagger`, ReDoc is at `/redoc`, etc. If you've written your own custom OpenAPI definition then you can also set a custom Route path to fetch the definition on.

To enable a viewer you can use the [`Enable-PodeOAViewer`] function:

```powershell
# for swagger at "/docs/swagger"
Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger' -DarkMode

# and ReDoc at the default "/redoc"
Enable-PodeOpenApiViewer -Type ReDoc

# and RapiDoc at "/docs/rapidoc"
Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode

# and StopLight at "/docs/stoplight"
Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight'

# and Explorer at "/docs/explorer"
Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer'

# and RapiPdf at "/docs/rapipdf"
Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf'

# plus a bookmark page with the link to all documentation
Enable-PodeOAViewer -Bookmarks -Path '/docs'

# there is also an OpenAPI editor (only for v3.0.x)
Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
```

## Multiple OpenAPI definition

It's possible to create multiple OpenAPI definitions inside the same Server instance. This feature could be useful in situations such as:

* Multiple versions of the OpenAPI specification for different use cases
* The same OpenAPI definition, but one using OpenAPI v3.0.3 and another using v3.1.0
* Different APIs based on the IP or URL


### How to use it
Any Pode function that interacts with OpenAPI has a `-DefinitionTag [string[]]` parameter available. This allows you to specify within which OpenAPI definition(s) the API's definition should be available.

!!! note
    These functions accept a simple string, and not an array

    * Get-PodeOADefinition
    * Enable-PodeOpenApi
    * Enable-PodeOAViewer
    * Add-PodeOAInfo
    * Test-PodeOAJsonSchemaCompliance

A new OpenAPI definition has to be created using the `Enable-PodeOpenApi` function

```powershell
Enable-PodeOpenApi -Path '/docs/openapi/v3.0' -OpenApiVersion '3.0.3'  -DefinitionTag 'v3'
Enable-PodeOpenApi -Path '/docs/openapi/v3.1' -OpenApiVersion '3.1.0' -DefinitionTag 'v3.1'
Enable-PodeOpenApi -Path '/docs/openapi/admin' -OpenApiVersion '3.1.0' -DefinitionTag 'admin'
```

There is also [`Select-PodeOADefinition`], which simplifies the selection of which OpenAPI definition to use as a wrapper around multiple OpenAPI functions, or Route functions. Meaning you don't have to specify `-DefinitionTag` on embedded OpenAPI/Route calls:

```powershell
Select-PodeOADefinition -Tag 'v3', 'v3.1' -Scriptblock {
    Add-PodeRouteGroup -Path '/api/v5' -Routes {
        Add-PodeRoute -Method Get -Path '/petbyRef/:petId' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 2005
        }
    }
}

Select-PodeOADefinition -Tag 'admin' -ScriptBlock {
    # your admin definition
}
```

The default `Definition Tag` is named "default". This can be changed using the `Server.psd1` file and the `Web.OpenApi.DefaultDefinitionTag` property

```powershell
@{
    Web=@{
        OpenApi=@{
            DefaultDefinitionTag= 'NewDfault'
        }
    }
}
```

### OpenAPI example

A simple OpenAPI definition

```powershell
Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' `
    -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -DefinitionTag 'v3'

Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.1' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' `
    -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -DefinitionTag 'v3.1'

Add-PodeOAServerEndpoint -url '/api/v3' -Description 'default endpoint' -DefinitionTag 'v3', 'v3.1'

#OpenAPI 3.0
Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger' -DefinitionTag 'v3'
Enable-PodeOAViewer -Type Bookmarks -Path '/docs' -DefinitionTag 'v3'

#OpenAPI 3.1
Enable-PodeOAViewer -Type Swagger -Path '/docs/v3.1/swagger' -DefinitionTag 'v3.1'
Enable-PodeOAViewer -Type ReDoc -Path '/docs/v3.1/redoc' -DarkMode -DefinitionTag 'v3.1'
Enable-PodeOAViewer -Type Bookmarks -Path '/docs/v3.1' -DefinitionTag 'v3.1'

Select-PodeOADefinition -Tag 'v3', 'v3.1'  -ScriptBlock {
    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example  10 -Required |
        New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required |
        New-PodeOASchemaProperty -Name 'category' -Reference 'Category' |
        New-PodeOAStringProperty -Name 'photoUrls' -Array  -XmlWrapped -XmlItemName 'photoUrl' -Required |
        New-PodeOASchemaProperty -Name 'tags' -Reference 'Tag' -Array -XmlWrapped |
        New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold') |
        New-PodeOAObjectProperty -XmlName 'pet' |
        Add-PodeOAComponentSchema -Name 'Pet'


     Add-PodeRouteGroup -Path '/api/v3'   -Routes {
            Add-PodeRoute -PassThru -Method Put -Path '/pet' -Authentication 'merged_auth_nokey' -Scope 'write:pets', 'read:pets' -ScriptBlock {
     #code
            } | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru |
                Set-PodeOARequest -RequestBody (
                    New-PodeOARequestBody -Description  'Update an existent pet in the store' -Required -Content (
                        New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet'  )
                ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception'
    }
}
```
