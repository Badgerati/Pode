# Components

You can define reusable OpenAPI components in Pode. Currently supported are Schemas, Parameters, Request Bodies, and Responses.

### Schemas

To define a reusable schema that can be used in request bodies, and responses, you can use the [`Add-PodeOAComponentSchema`](../../../Functions/OAComponents/Add-PodeOAComponentSchema) function. You'll need to supply a Name, and a Schema that can be reused.

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

To define a reusable request bodies you can use the [`Add-PodeOAComponentRequestBody`](../../../Functions/OAComponents/Add-PodeOAComponentRequestBody) function. You'll need to supply a Name, as well as the needed schemas for each content type.

The following is an example of defining a JSON object that a Name, UserId, and an Enable flag:

```powershell
# define a reusable request body
New-PodeOAContentMediaType -ContentType 'application/json', 'application/x-www-form-urlencoded' -Content (
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

To define reusable parameters that are used on requests, you can use the [`Add-PodeOAComponentParameter`](../../../Functions/OAComponents/Add-PodeOAComponentParameter) function. You'll need to supply a Name and the Parameter definition.

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

To define a reusable response definition you can use the [`Add-PodeOAComponentResponse`](../../../Functions/OAComponents/Add-PodeOAComponentResponse) function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

The following is an example of defining a 200 response with a JSON payload of an array of objects for Name/UserId. The Response component can be used by a route referencing the name:

```powershell
# defines a response with a json payload using New-PodeOAContentMediaType
Add-PodeOAComponentResponse -Name 'OK' -Description 'A user object' -Content (
        New-PodeOAContentMediaType -ContentType 'application/json' -Array -Content (
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

To define a reusable example definition you can use the [`Add-PodeOAComponentExample`](../../../Functions/OAComponents/Add-PodeOAComponentExample) function. You'll need to supply a Name, a Summary and a list of value representing the object.

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
            New-PodeOAExample -ContentType 'application/json', 'application/xml' -Reference 'cat-example' |
                New-PodeOAExample -ContentType 'application/json', 'application/xml'   -Reference 'dog-example' |
                New-PodeOAExample -ContentType 'application/json', 'application/xml' -Reference 'frog-example'
            )
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.'
```

### Headers

To define a reusable header definition you can use the [`Add-PodeOAComponentHeader`](../../../Functions/OAComponents/Add-PodeOAComponentHeader) function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

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
        New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'string'
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username/password supplied'
```


### CallBacks

To define a reusable callback definition you can use the [`Add-PodeOAComponentCallBack`](../../../Functions/OAComponents/Add-PodeOAComponentCallBack) function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

```powershell
Add-PodeRoute -PassThru -Method Post -Path '/petcallbackReference'  -Authentication 'Login-OAuth2' `
    -Scope 'write'  -ScriptBlock {
    #route code
} | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' `
    -Tags 'pet' -OperationId 'petcallbackReference' -PassThru |
    Set-PodeOARequest -RequestBody ( New-PodeOARequestBody -Reference 'PetBodySchema' ) -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (
        New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet'
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -Content @{
        'application / json' = ( New-PodeOAStringProperty -Name 'result' |
                New-PodeOAStringProperty -Name 'message' |
                New-PodeOAObjectProperty )
        } -PassThru |
        Add-PodeOACallBack -Name 'test1'   -Reference 'test'
```

### Response Links

To define a reusable response link definition you can use the [`Add-PodeOAComponentResponseLink`](../../../Functions/OAComponents/Add-PodeOAComponentResponseLink) function. You'll need to supply a Name, and optionally any Content/Header schemas that define the responses payload.

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
            New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )
    ) -PassThru |
    Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User' }  -PassThru  -Links (
        New-PodeOAResponseLink -Name 'address2' -Reference 'address'
    ) |
    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
    Add-PodeOAResponse -StatusCode 404 -Description 'User not found' -PassThru |
    Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'
```