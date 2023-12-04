$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
if (Test-Path -Path "$($path)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
} else {
    Import-Module -Name 'Pode'
}

Start-PodeServer -Threads 2 -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Default
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    $InfoDescription = @'
This is a sample Pet Store Server based on the OpenAPI 3.0 specification.  You can find out more about Swagger at [http://swagger.io](http://swagger.io).
In the third iteration of the pet store, we've switched to the design first approach!
You can now help us improve the API whether it's by making changes to the definition itself or to the code.
That way, with time, we can improve the API in general, and expose some of the new features in OAS3.

Some useful links:
- [The Pet Store repository](https://github.com/swagger-api/swagger-petstore)
- [The source API definition for the Pet Store](https://github.com/swagger-api/swagger-petstore/blob/master/src/main/resources/openapi.yaml)
'@



    Enable-PodeOpenApi -Path '/docs/openapi'     -OpenApiVersion '3.0.2' -EnableSchemaValidation -DisableMinimalDefinitions -DefaultResponses @{}
    New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
    Add-PodeOAExternalDoc -Reference 'SwaggerDocs'
    Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' `
        -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io'
    Add-PodeOAServerEndpoint -url '/api/v3' -Description 'default endpoint'

    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode

    Enable-PodeOAViewer -Type Bookmarks -Path '/docs'


    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'read:pets' -Description 'read your pets'
    New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'write:pets' -Description 'modify pets in your account'
    $clientId = '123123123'
    $clientSecret = '<mysecret>'

    New-PodeAuthScheme  -OAuth2  -ClientId $ClientId -ClientSecret $ClientSecret `
        -AuthoriseUrl 'https://petstore3.swagger.io/oauth/authorize' `
        -TokenUrl 'https://petstore3.swagger.io/oauth/token' `
        -Scope 'read:pets', 'write:pets' |
        Add-PodeAuth -Name 'petstore_auth' -FailureUrl 'https://petstore3.swagger.io/oauth/failure' -SuccessUrl '/'  -ScriptBlock {
            param($user, $accessToken, $refreshToken)
            return @{ User = $user }
        }

    New-PodeAuthScheme -ApiKey -LocationName 'api_key' | Add-PodeAuth -Name 'api_key' -Sessionless -ScriptBlock {
        param($key)
        if ($key) {
            # here you'd check a real storage, this is just for example
            if ($key -eq 'test-key') {
                return @{
                    User = @{
                        'ID'   = 'M0R7Y302'
                        'Name' = 'Morty'
                        'Type' = 'Human'
                    }
                }
            }

            # authentication failed
            return @{
                Code      = 401
                Challenge = 'qop="auth", nonce="<some-random-guid>"'
            }
        } else {
            return @{
                Message = 'No Authorization header found'
                Code    = 401
            }

        }
    }

    Merge-PodeAuth -Name 'merged_auth' -Authentication 'petstore_auth', 'api_key'

    Add-PodeOATag -Name 'user' -Description 'Operations about user'
    Add-PodeOATag -Name 'store' -Description 'Access to Petstore orders' -ExternalDoc 'SwaggerDocs'
    Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc 'SwaggerDocs'


    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 |
        New-PodeOAIntProperty -Name 'petId' -Format Int64 -Example 198772 |
        New-PodeOAIntProperty -Name 'quantity' -Format Int32 -Example 7 |
        New-PodeOAStringProperty -Name 'shipDate' -Format Date-Time |
        New-PodeOAStringProperty -Name 'status' -Description 'Order Status' -Example 'approved' -Enum @('placed', 'approved', 'delivered') |
        New-PodeOABoolProperty -Name 'complete' |
        New-PodeOAObjectProperty -XmlName 'order' |
        Add-PodeOAComponentSchema -Name 'Order'

    New-PodeOAStringProperty -Name 'street' -Example '437 Lytton' -Required |
        New-PodeOAStringProperty -Name 'city' -Example 'Palo Alto' -Required |
        New-PodeOAStringProperty -Name 'state' -Example 'CA' -Required |
        New-PodeOAStringProperty -Name 'zip' -Example '94031' -Required |
        New-PodeOAObjectProperty   -XmlName 'address' |
        Add-PodeOAComponentSchema -Name 'Address'

    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 100000 |
        New-PodeOAStringProperty -Name 'username' -example  'fehguy' |
        New-PodeOASchemaProperty -Name 'Address' -Component 'Address' -Array -Xml @{ 'name' = 'addresses'; 'wrapped' = $true } |
        New-PodeOAObjectProperty -XmlName 'customer' |
        Add-PodeOAComponentSchema -Name 'Customer'


    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
        New-PodeOAStringProperty -Name 'name' -Example 'Dogs' |
        New-PodeOAObjectProperty  -XmlName 'category' |
        Add-PodeOAComponentSchema -Name 'Category'

    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 |
        New-PodeOAStringProperty -Name 'username' -Example 'theUser' -Required |
        New-PodeOAStringProperty -Name 'firstName' -Example 'John' |
        New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
        New-PodeOAStringProperty -Name 'email' -Format email -Example 'john@email.com' |
        New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
        New-PodeOAStringProperty -Name 'password' -Format Password -Example '12345' -Required |
        New-PodeOAStringProperty -Name 'phone' -Example '12345' |
        New-PodeOAIntProperty -Name 'userStatus'-Format Int32 -Description 'User Status' -Example 1 |
        New-PodeOAObjectProperty -XmlName 'user' |
        Add-PodeOAComponentSchema -Name 'User'



    New-PodeOAIntProperty -Name 'id'-Format Int64 |
        New-PodeOAStringProperty -Name 'name' |
        New-PodeOAObjectProperty -XmlName 'tag' |
        Add-PodeOAComponentSchema -Name 'Tag'

    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example  10 |
        New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required |
        New-PodeOASchemaProperty -Name 'category' -Component 'Category' |
        New-PodeOAStringProperty -Name 'photoUrls' -Array  -XmlWrapped -XmlItemName 'photoUrl' -Required |
        New-PodeOASchemaProperty -Name 'tags' -Component 'Tag' -Array -XmlWrapped |
        New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold') |
        New-PodeOAObjectProperty -XmlName 'pet' |
        Add-PodeOAComponentSchema -Name 'Pet'



    New-PodeOAIntProperty -Name 'code'-Format Int32 |
        New-PodeOAStringProperty -Name 'type' |
        New-PodeOAStringProperty -Name 'message' |
        New-PodeOAObjectProperty  -XmlName '##default' |
        Add-PodeOAComponentSchema -Name 'ApiResponse'


    Add-PodeOAComponentRequestBody -Name 'Pet' -Description 'Pet object that needs to be added to the store' -Content (
        New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet')

    Add-PodeOAComponentRequestBody -Name 'UserArray' -Description 'List of user object' -Content (
        New-PodeOAContentMediaType -ContentMediaType 'application/json' -Content 'User' -Array)


    Add-PodeRouteGroup -Path '/api/v3'   -Routes {
        <#
           PUT '/pet'
         #>
        Add-PodeRoute -PassThru -Method Put -Path '/pet' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $JsonPet = ConvertTo-Json $WebEvent.data
            $Validate = Test-PodeOAJsonSchemaCompliance -Json $JsonPet -SchemaReference 'Pet'
            if ($Validate.result) {
                $Pet = $WebEvent.data
                $Pet.tags.id = Get-Random -Minimum 1 -Maximum 9999999
                Write-PodeJsonResponse -Value ($Pet | ConvertTo-Json -Depth 20 ) -StatusCode 200
            } else {
                Write-PodeJsonResponse -StatusCode 405 -Value @{
                    result  = $Validate.result
                    message = $Validate.message -join ', '
                }
            }
        } | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru |
            Set-PodeOARequest -RequestBody (
                New-PodeOARequestBody -Description  'Update an existent pet in the store' -Required -Content (
                    New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet'  )
            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception'


        <#
           POST '/pet'
         #>
        Add-PodeRoute -PassThru -Method Post -Path '/pet'  -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets'  -ScriptBlock {
            $JsonPet = ConvertTo-Json $WebEvent.data
            $Validate = Test-PodeOAJsonSchemaCompliance -Json $JsonPet -SchemaReference 'Pet'
            if ($Validate.result) {
                $Pet = $WebEvent.data
                $Pet.tags.id = Get-Random -Minimum 1 -Maximum 9999999
                Write-PodeJsonResponse -Value ($Pet | ConvertTo-Json -Depth 20 ) -StatusCode 200
            } else {
                Write-PodeJsonResponse -StatusCode 405 -Value @{
                    result  = $Validate.result
                    message = $Validate.message -join ', '
                }
            }
        } | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' -Tags 'pet' -OperationId 'addPet' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Description 'Create a new pet in the store' -Required  -Content (
                    New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet'  )
            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description  'Invalid input'


        <#
            GET '/pet/findByStatus'
        #>
        Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') |
                    ConvertTo-PodeOAParameter -In Query -Explode ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -ContentMediaType 'application/json', 'application/xml' -Content 'Pet' -Array) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'



        <#
            GET '/pet/{petId}'
        #>
        Add-PodeRoute -PassThru -Method Get -Path '/pet/:petId' -Authentication 'merged_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Find pet by ID' -Description 'Returns a single pet.' -Tags 'pet' -OperationId 'getPetById' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAIntProperty -Name 'petId' -Description 'ID of pet to return'  -Format Int64 |
                    ConvertTo-PodeOAParameter -In Path -Required ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found'


        <#
            POST '/pet/{petId}'
        #>

        Add-PodeRoute -PassThru -Method post -Path '/pet/:petId' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Updates pet with ID' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePetWithForm' -PassThru |
            Set-PodeOARequest -PassThru -Parameters  ( New-PodeOAIntProperty -Name 'petId' -Description 'ID of pet that needs to be updated'  -Format Int64 |
                    ConvertTo-PodeOAParameter -In Path -Required ),
                                    (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                                    (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

        <#
            DELETE '/pet/{petId}'
        #>
        Add-PodeRoute -PassThru -Method Delete -Path '/pet/:petId' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Deletes pet by ID' -Description 'Deletes a pet.' -Tags 'pet' -OperationId 'deletePet' -PassThru |
            Set-PodeOARequest -PassThru -Parameters  (  New-PodeOAStringProperty -Name 'api_key' | ConvertTo-PodeOAParameter -In Header),
            ( New-PodeOAIntProperty -Name 'petId' -Description 'ID of pet that needs to be updated'  -Format Int64 |
                ConvertTo-PodeOAParameter -In Path -Required ) |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid pet value'

    }
    $yaml = PodeOADefinition -Format Yaml
    # $json=  PodeOADefinition -Format Json
}