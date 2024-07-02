try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

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



    #Enable-PodeOpenApi -Path '/docs/openapi'     -OpenApiVersion '3.0.0' -EnableSchemaValidation -DisableMinimalDefinitions -DefaultResponses @{}
    #  New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
    #  Add-PodeOAExternalDoc -Reference 'SwaggerDocs'

    Enable-PodeOpenApi -Path '/docs/openapi/v3.0'     -OpenApiVersion '3.0.3' -EnableSchemaValidation -DisableMinimalDefinitions -NoDefaultResponses -DefinitionTag 'v3'
    Enable-PodeOpenApi -Path '/docs/openapi/v3.1'     -OpenApiVersion '3.1.0' -EnableSchemaValidation -DisableMinimalDefinitions -NoDefaultResponses -DefinitionTag 'v3.1'
    $swaggerDocs = New-PodeOAExternalDoc   -Description 'Find out more about Swagger' -Url 'http://swagger.io'

    $swaggerDocs | Add-PodeOAExternalDoc  -DefinitionTag 'v3', 'v3.1'


    #  Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'


    Add-PodeOAServerEndpoint -url '/api/v3' -Description 'default endpoint'  -DefinitionTag 'v3', 'v3.1'

    Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' `
        -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -DefinitionTag 'v3'

    Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.1' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' `
        -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -DefinitionTag 'v3.1'


    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger' -DefinitionTag 'v3'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode -DefinitionTag 'v3'
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode -DefinitionTag 'v3'
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode -DefinitionTag 'v3'
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode -DefinitionTag 'v3'
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode -DefinitionTag 'v3'
    Enable-PodeOAViewer -Editor -DefinitionTag 'v3'
    Enable-PodeOAViewer -Bookmarks -Path '/docs' -DefinitionTag 'v3'


    Enable-PodeOAViewer -Type Swagger -Path '/docs/v3.1/swagger' -DefinitionTag 'v3.1'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/v3.1/redoc' -DarkMode -DefinitionTag 'v3.1'
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/v3.1/rapidoc' -DarkMode -DefinitionTag 'v3.1'
    Enable-PodeOAViewer -Type StopLight -Path '/docs/v3.1/stoplight' -DarkMode -DefinitionTag 'v3.1'
    Enable-PodeOAViewer -Type Explorer -Path '/docs/v3.1/explorer' -DarkMode -DefinitionTag 'v3.1'

    Enable-PodeOAViewer -Bookmarks -Path '/docs/v3.1' -DefinitionTag 'v3.1'

    Select-PodeOADefinition -Tag 'v3', 'v3.1'  -Scriptblock {

        Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc $swaggerDocs
        Add-PodeOATag -Name 'store' -Description 'Access to Petstore orders' -ExternalDoc $swaggerDocs
        Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc $swaggerDocs


        <#   Add-PodeOAComponentSchema -Name 'Address' -Schema (
        New-PodeOAObjectProperty -Name 'Address' -XmlName  'address' } -Description 'Shipping Address' -Properties (
            New-PodeOAStringProperty -Name 'street' -Example '437 Lytton' -Required |
                New-PodeOAStringProperty -Name 'city' -Example 'Palo Alto' -Required |
                New-PodeOAStringProperty -Name 'state' -Example 'CA' -Required |
                New-PodeOAStringProperty -Name 'zip' -Example '94031' -Required
        ))
        Merge-PodeOAProperty -Type OneOf -ObjectDefinitions @(
            (New-PodeOAIntProperty -Name 'userId' -Object),
            (New-PodeOAStringProperty -Name 'name' -Object),
            (New-PodeOABoolProperty -Name 'enabled' -Object)
        )|Add-PodeOAComponentSchema -Name 'Test123'

    New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
        New-PodeOAObjectProperty -Name 'User' -XmlName  'user' } -Properties  (
            New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 -ReadOnly |
                New-PodeOAStringProperty -Name 'username' -Example 'theUser' -Required ) |
            New-PodeOAStringProperty -Name 'username' -Example 'theUser' -Required |
            New-PodeOAStringProperty -Name 'firstName' -Example 'John' |
            New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
            New-PodeOAObjectProperty -Name 'test' | Add-PodeOAComponentSchema -Name 'Test'

#>
        New-PodeOAStringProperty -Name 'street' -Example '437 Lytton' -Required |
            New-PodeOAStringProperty -Name 'city' -Example 'Palo Alto' -Required |
            New-PodeOAStringProperty -Name 'state' -Example 'CA' -Required |
            New-PodeOAStringProperty -Name 'zip' -Example '94031' -Required |
            New-PodeOAObjectProperty -Name 'Address' -XmlName 'address' -Description 'Shipping Address' |
            Add-PodeOAComponentSchema -Name 'Address'


        New-PodeOAIntProperty -Name 'id'-Format Int64 -ReadOnly -Example 10 |
            New-PodeOAIntProperty -Name 'petId' -Format Int64 -Example 198772 |
            New-PodeOAIntProperty -Name 'quantity' -Format Int32 -Example 7 |
            New-PodeOAStringProperty -Name 'shipDate' -Format Date-Time |
            New-PodeOAStringProperty -Name 'status' -Description 'Order Status' -Example 'approved' -Enum @('placed', 'approved', 'delivered') |
            New-PodeOABoolProperty -Name 'complete' |
            New-PodeOASchemaProperty -Name 'Address' -Reference 'Address' |
            New-PodeOAObjectProperty -Name 'Order' -XmlName 'order'  -AdditionalProperties (New-PodeOAStringProperty ) |
            Add-PodeOAComponentSchema -Name 'Order'

        Add-PodeOAComponentSchema -Name 'Category' -Schema (
            New-PodeOAObjectProperty -Name 'Category' -XmlName  'category' -Properties  (
                New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                    New-PodeOAStringProperty -Name 'name' -Example 'Dogs'
            ))

        Add-PodeOAComponentSchema -Name 'User' -Schema (
            New-PodeOAObjectProperty -Name 'User' -XmlName  'user' -Properties  (
                New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 -ReadOnly |
                    New-PodeOAStringProperty -Name 'username' -Example 'theUser' -Required |
                    New-PodeOAStringProperty -Name 'firstName' -Example 'John' |
                    New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
                    New-PodeOAStringProperty -Name 'email' -Format email -Example 'john@email.com' |
                    New-PodeOAStringProperty -Name 'lastName' -Example 'James' |
                    New-PodeOAStringProperty -Name 'password' -Format Password -Example '12345' -Required |
                    New-PodeOAStringProperty -Name 'phone' -Example '12345' |
                    New-PodeOAIntProperty -Name 'userStatus'-Format int32 -Description 'User Status' -Example 1
            ))

        Merge-PodeOAProperty -Type AllOf -ObjectDefinitions 'Address', 'User' | Add-PodeOAComponentSchema -Name 'aaaaa'
        Add-PodeOAComponentSchema -Name 'Tag' -Component (
            New-PodeOAObjectProperty -Name 'Tag' -XmlName  'tag' -Properties  (
                New-PodeOAIntProperty -Name 'id'-Format Int64 |
                    New-PodeOAStringProperty -Name 'name'
            ))

        Add-PodeOAComponentSchema -Name 'Pet' -Component (
            New-PodeOAObjectProperty -Name 'Pet' -XmlName  'pet'  -Properties  (
                New-PodeOAIntProperty -Name 'id'-Format Int64 -Example @(10, 2, 4) -ReadOnly |
                    New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required |
                    New-PodeOASchemaProperty -Name 'category' -Reference 'Category' |
                    New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required |
                    New-PodeOAStringProperty -Name 'photoUrls' -Array |
                    New-PodeOASchemaProperty -Name 'tags' -Reference 'Tag' |
                    New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold')
            ))

        Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions 'Pet', (
            New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @(  'clueless', 'lazy', 'adventurous', 'aggressive') | New-PodeOAObjectProperty
        ) | Add-PodeOAComponentSchema -Name 'NewCat'

        #XML teest
        New-PodeOAIntProperty -Name 'id' -Format Int32 -XmlAttribute | New-PodeOAStringProperty -Name 'name' -XmlPrefix 'sample' -XmlNamespace 'http://example.com/schema/sample' |
            New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name 'XmlPrefixAndNamespace'

        New-PodeOAStringProperty   -Array -XmlItemName 'animal' | Add-PodeOAComponentSchema -Name 'animals'

        New-PodeOAStringProperty -Array -XmlItemName 'animal' -XmlName 'aliens' | Add-PodeOAComponentSchema -Name 'AnimalsNoAliens'

        New-PodeOAStringProperty -Array -XmlWrapped | Add-PodeOAComponentSchema -Name 'WrappedAnimals'

        New-PodeOAStringProperty -Array -XmlWrapped -XmlItemName 'animal' | Add-PodeOAComponentSchema -Name 'WrappedAnimal'

        New-PodeOAStringProperty -Array -XmlWrapped -XmlItemName 'animal' -XmlName 'aliens' | Add-PodeOAComponentSchema -Name 'WrappedAliens'

        New-PodeOAStringProperty -Array -XmlWrapped  -XmlName 'aliens' | Add-PodeOAComponentSchema -Name 'WrappedAliensWithItems'


        New-PodeOAStringProperty -Name 'name' |
            New-PodeOAStringProperty -Name 'type' |
            New-PodeOASchemaProperty -Name 'children' -Array -Reference 'StructPart' |
            New-PodeOAObjectProperty |
            Add-PodeOAComponentSchema -Name 'StructPart'


        #Define Pet schema
        New-PodeOAStringProperty -Name 'name' | New-PodeOAStringProperty -Name 'petType' |
            New-PodeOAObjectProperty -DiscriminatorProperty 'petType' | Add-PodeOAComponentSchema -Name 'Pet2'

        #Define Cat schema
        Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions 'Pet2',
(New-PodeOAStringProperty -Name 'huntingSkill'  -Description 'The measured skill for hunting' -Default 'lazy' -Enum 'clueless', 'lazy', 'adventurous', 'aggressive' -Required -Object ) |
            Add-PodeOAComponentSchema -Name 'Cat2' -Description "A representation of a cat. Note that `Cat` will be used as the discriminator value."


        #Define Dog schema
        Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions 'Pet2',
(New-PodeOAIntProperty -Name 'packSize'  -Description 'the size of the pack the dog is from' -Default 0 -Minimum 0 -Format Int32 -Required -Object ) |
            Add-PodeOAComponentSchema -Name 'Dog2' -Description "A representation of a dog. Note that `Dog` will be used as the discriminator value."


        <#   Alternative :
        Add-PodeOAComponentSchema -Name 'Pet' -Schema (
        New-PodeOAObjectProperty -Name 'Pet' -XmlName  'pet' } -Properties @(
                    (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly),
                        (New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required),
                        (New-PodeOASchemaProperty -Name 'category' -Component 'Category'),
                        (New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required),
                        (New-PodeOAStringProperty -Name 'photoUrls' -Array),
                        (New-PodeOASchemaProperty -Name 'tags' -Component 'Tag')
                        (New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold'))
        )) #>

        <#    Add-PodeOAComponentSchema -Name 'Cat' -Schema (   New-PodeOAObjectProperty  -Name 'testcat' -Description 'Type of cat' -Properties (
            New-PodeOAStringProperty -Name 'breed' -Description 'Type of Breed' -Enum @(  'Abyssinian', 'Balinese-Javanese', 'Burmese', 'British Shorthair') |
                Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions @( 'Pet',
                (New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @(  'clueless', 'lazy', 'adventurous', 'aggressive') -Object)
                )
        )
    )#>
        Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions 'Pet', (New-PodeOAStringProperty -Name 'rootCause' -required -object) |
            Add-PodeOAComponentSchema -Name 'ExtendedErrorModel'

        New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @(  'clueless', 'lazy', 'adventurous', 'aggressive') -Object |
            Merge-PodeOAProperty  -Type AllOf  -ObjectDefinitions 'Pet' |
            New-PodeOAStringProperty -Name 'breed' -Description 'Type of Breed' -Enum @(  'Abyssinian', 'Balinese-Javanese', 'Burmese', 'British Shorthair') |

            New-PodeOAObjectProperty   -Description 'Type of cat' | Add-PodeOAComponentSchema -Name 'Cat'





        Add-PodeOAComponentSchema -Name 'Dog' -Component (
            Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions @( 'Pet', ( New-PodeOAObjectProperty -Properties (
                        New-PodeOAStringProperty -Name 'breed' -Description 'Type of Breed' -Enum @(  'Dingo', 'Husky', 'Retriever', 'Shepherd') |
                            New-PodeOABoolProperty -Name 'bark'
                    ))
            )
        )


        Add-PodeOAComponentSchema -Name 'Pets' -Component (
            Merge-PodeOAProperty  -Type OneOf -ObjectDefinitions @( 'Cat', 'Dog') -DiscriminatorProperty 'petType')


        Add-PodeOAComponentSchema -Name 'ApiResponse' -Component (
            New-PodeOAObjectProperty -Name 'ApiResponse' -XmlName  '##default'  -Properties  (
                New-PodeOAIntProperty -Name 'code'-Format Int32 |
                    New-PodeOAStringProperty -Name 'type' -Example 'doggie' |
                    New-PodeOAStringProperty -Name 'message'
            )
        )

        New-PodeOAStringProperty -Name 'message' | New-PodeOAIntProperty -Name 'code'-Format Int32 | New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name 'ErrorModel'


        Add-PodeRoute -PassThru -Method Get -Path '/peta/:id' -ScriptBlock {
            Write-PodeJsonResponse -Value (Get-Pet -Id $WebEvent.Parameters['id']) -StatusCode 200
        } |
            Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
        (  New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
            Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -Content (@{  '*/*' = New-PodeOASchemaProperty   -Reference 'Pet' -array }) -PassThru |
            Add-PodeOAResponse -Default  -Description 'error payload' -Content (@{  'text/html' = 'ApiResponse' }) -PassThru





        New-PodeOAIntProperty -Format Int32 -Description 'calls per hour allowed by the user' | Add-PodeOAComponentHeader -Name 'X-Rate-Limit'
        New-PodeOAStringProperty -Format Date-Time -Description 'date in UTC when token expires' | Add-PodeOAComponentHeader -Name 'X-Expires-After'

        #define '#/components/responses/'
        Add-PodeOAComponentResponse -Name 'UserOpSuccess' -Description 'Successful operation' -ContentSchemas (@{'application/json' = 'User' ; 'application/xml' = 'User' })

        Add-PodeOAComponentRequestBody -Name 'PetBodySchema' -Required -Description 'Pet in the store' -ContentSchemas (@{ 'application/json' = 'Pets'; 'application/xml' = 'Pets'; 'application/x-www-form-urlencoded' = 'Pets' })


        #define '#/components/parameters/'
        Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Path )
    }



    # setup apikey authentication to validate a user
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
        }
        else {
            return @{
                Message = 'No Authorization header found'
                Code    = 401
            }

        }
    }
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Login' -Sessionless -ScriptBlock {
        param($username, $password)
        # check if the user is valid
        return @{ User = $user }
    }
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'LoginApiKey' -Sessionless -ScriptBlock {
        param($username, $password)
        # check if the user is valid
        return @{ User = $user }
    }
    # jwt with no signature:
    New-PodeAuthScheme -Bearer -AsJWT | Add-PodeAuth -Name 'Jwt' -Sessionless -ScriptBlock {
        param($payload)

        return ConvertFrom-PodeJwt -Token $payload
    }


    New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'read' -Description 'Grant read-only access to all your data except for the account and user info'
    New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'write' -Description 'Grant write-only access to all your data except for the account and user info'
    New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'profile' -Description 'Grant read-only access to the account and user info only'
    # setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    $clientId = '123123123'
    $clientSecret = 'acascascasca>zzzcz'

    <#     $InnerScheme = New-PodeAuthScheme -Form
    $scheme = New-PodeAuthScheme `
        -OAuth2 `
        -ClientId $ClientId `
        -ClientSecret $ClientSecret `
        -AuthoriseUrl "https://login.microsoftonline.com/$($tenantId)/oauth2/v2.0/authorize" `
        -TokenUrl "https://login.microsoftonline.com/$($tenantId)/oauth2/v2.0/token" `
        -UserUrl 'https://graph.microsoft.com/oidc/userinfo' `
        -RedirectUrl $RedirectUrl `
        -InnerScheme $InnerScheme `
        # -Middleware $Middleware `
        -Scope 'read', 'write', 'profile'
    $scheme | Add-PodeAuth -Name 'Login-OAuth2' -FailureUrl '/LoginOAuth2' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)
        return @{ User = $user }
    }#>
    New-PodeAuthScheme `
        -OAuth2 `
        -ClientId $ClientId `
        -ClientSecret $ClientSecret `
        -AuthoriseUrl 'http://example.org/api/oauth/dialog' `
        -TokenUrl 'http://example.org/api/oauth/token' `
        -Scope 'read', 'write' | Add-PodeAuth -Name 'Login-OAuth2' -FailureUrl '/LoginOAuth2' -SuccessUrl '/' -ScriptBlock {
        param($user, $accessToken, $refreshToken)
        return @{ User = $user }
    }
    Merge-PodeAuth -Name 'test' -Authentication 'Login-OAuth2', 'api_key'

    $ex =
    New-PodeOAExample -MediaType 'application/json' -Name 'user' -Summary   'User Example' -ExternalValue  'http://foo.bar/examples/user-example.json' |
        New-PodeOAExample -MediaType 'application/xml' -Name 'user' -Summary   'User Example in XML' -ExternalValue  'http://foo.bar/examples/user-example.xml' |
        New-PodeOAExample -MediaType 'text/plain' -Name 'user' -Summary   'User Example in Plain text' -ExternalValue 'http://foo.bar/examples/user-example.txt' |
        New-PodeOAExample -MediaType '*/*' -Name 'user' -Summary   'User example in other forma' -ExternalValue  'http://foo.bar/examples/user-example.whatever'
    Select-PodeOADefinition -Tag 'v3' -Scriptblock {
        Add-PodeRouteGroup -Path '/api/v4'     -Routes {

            Add-PodeRoute -PassThru -Method Put -Path '/pat/:petId' -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                if ( Update-Pet -Id $WebEvent.Parameters['petId'] -Data  $JsonPet) {
                    Write-PodeJsonResponse -Value @{} -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -Value @{} -StatusCode 405
                }
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatePasdadaetWithForm' -PassThru |
                Set-PodeOARequest  -Parameters @(
            (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
                ) -RequestBody (
                    New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'User'; 'application/xml' = 'User' }  -Examples  $ex

                ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -Content (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -Content  (@{  'application/json' = '' ; 'application/xml' = '' })

            Add-PodeRoute -PassThru -Method Put -Path '/paet/:petId' -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet) {
                    Write-PodeJsonResponse -Value @{} -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -Value @{} -StatusCode 405
                }
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet' -PassThru |
                Set-PodeOARequest  -Parameters @(
          (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required -Examples (
                        New-PodeOAExample   -Name 'user' -Summary   'User Example' -Value  'http://foo.bar/examples/user-example.json' |
                            New-PodeOAExample   -Name 'user1' -Summary   'User Example in XML' -Value  'http://foo.bar/examples/user-example.xml' |
                            New-PodeOAExample   -Name 'user2' -Summary   'User Example in Plain text' -Value 'http://foo.bar/examples/user-example.txt' |
                            New-PodeOAExample  -Name 'user3' -Summary   'User example in other forma' -Value  'http://foo.bar/examples/user-example.whatever' ))
                    ) -RequestBody (New-PodeOARequestBody -Required -Content (@{
                                'application/x-www-form-urlencoded' = New-PodeOAObjectProperty -Properties @(
              (New-PodeOAStringProperty -Name 'name' -Description 'Updated name of the pet'),
              (New-PodeOAStringProperty -Name 'status' -Description 'Updated status of the pet' -Required)
                                )
                            })
                    ) -PassThru |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -Content (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
                    Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -Content  (@{  'application/json' = '' ; 'application/xml' = '' })


            #Start 3.1
            Select-PodeOADefinition -Tag 'v3.1'  -Scriptblock {

                Add-PodeOAComponentPathItem -Name 'GetPetByIdWithRef' -Method Get -PassThru | Set-PodeOARouteInfo -Summary 'Find pet by ID' -Description 'Returns a single pet.' -Tags 'pet' -OperationId 'getPetByIdWithRef' -PassThru |
                    Set-PodeOARequest -PassThru -Parameters (
                        New-PodeOAIntProperty -Name 'petId' -Description 'ID of pet to return'  -Format Int64 |
                            ConvertTo-PodeOAParameter -In Path -Required ) |
                        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet') -PassThru |
                        Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                        Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
                        Add-PodeOAResponse -StatusCode 415

                Add-PodeOAWebhook -Name 'newPet' -Method Post -PassThru | Set-PodeOARouteInfo   -Description 'Information about a new pet in the system'   -PassThru |
                    Set-PodeOARequest -PassThru -RequestBody (
                        New-PodeOARequestBody -Content @{ 'application/json' = 'Pets' }
                    ) | Add-PodeOAResponse -StatusCode 200 -Description 'Return a 200 status to indicate that the data was received successfully'

            }
            #end 3.1
            Add-PodeRoute -PassThru -Method Put -Path '/paet2/:petId' -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet) {
                    Write-PodeJsonResponse -Value @{} -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -Value @{} -StatusCode 405
                }
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet2' -PassThru |
                Set-PodeOARequest  -Parameters @(
              (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
                ) -RequestBody (New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'text/plain' = New-PodeOAStringProperty   -array } ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -Content (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -Content  (@{  'application/json' = '' ; 'application/xml' = '' })



            $ex =
            New-PodeOAExample -MediaType 'application/json' -Name 'user' -Summary  'User Example' -ExternalValue   'http://foo.bar/examples/user-example.json' |
                New-PodeOAExample -MediaType 'application/xml' -Name 'user' -Summary   'User Example in XML' -ExternalValue   'http://foo.bar/examples/user-example.xml' |
                New-PodeOAExample -MediaType 'text/plain' -Name 'user' -Summary  'User Example in Plain text' -ExternalValue   'http://foo.bar/examples/user-example.txt' |
                New-PodeOAExample -MediaType '*/*' -Name 'user' -Summary   'User example in other forma' -ExternalValue  'http://foo.bar/examples/user-example.whatever'

            Add-PodeOAComponentExample -name 'frog-example' -Summary   "An example of a frog with a cat's name" -Value @{name = 'Jaguar'; petType = 'Panthera'; color = 'Lion'; gender = 'Male'; breed = 'Mantella Baroni' }

            Add-PodeRoute -PassThru -Method Put -Path '/paet3/:petId' -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet) {
                    Write-PodeJsonResponse -Value @{} -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -Value @{} -StatusCode 405
                }
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet3' -PassThru |
                Set-PodeOARequest  -Parameters @(
                  (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
                ) -RequestBody (New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'NewCat' } -Examples (
                        New-PodeOAExample -MediaType 'application/json' -Name 'cat' -Summary   'An example of a cat' -Value    @{name = 'Fluffy'; petType = 'Cat'; color = 'White'; gender = 'male'; breed = 'Persian' } |
                            New-PodeOAExample -MediaType 'application/json' -Name 'dog' -Summary   "An example of a dog with a cat's name" -Value    @{name = 'Puma'; petType = 'Dog'; color = 'Black'; gender = 'Female'; breed = 'Mixed' } |
                            New-PodeOAExample -MediaType 'application/json' -Reference 'frog-example'
                        )
                    ) -PassThru |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -Content (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
                    Add-PodeOAResponse -StatusCode 4XX -Description 'Method Not Allowed' -Content  (@{  'application/json' = '' ; 'application/xml' = '' })


            Add-PodeRoute -PassThru -Method Put -Path '/paet4/:petId' -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet) {
                    Write-PodeJsonResponse -Value @{} -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -Value @{} -StatusCode 405
                }
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet4' -PassThru |
                Set-PodeOARequest  -Parameters @(
                          (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required -ContentType 'application/json')
                ) -RequestBody (New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'Pet' } -Examples (
                        New-PodeOAExample -MediaType 'application/json' -Name 'cat' -Summary   'An example of a cat' -Value    @{name = 'Fluffy'; petType = 'Cat'; color = 'White'; gender = 'male'; breed = 'Persian' } |
                            New-PodeOAExample -MediaType 'application/json' -Name 'dog' -Summary   "An example of a dog with a cat's name" -Value    @{name = 'Puma'; petType = 'Dog'; color = 'Black'; gender = 'Female'; breed = 'Mixed' } |
                            New-PodeOAExample -MediaType 'application/json' -Reference 'frog-example'
                        )

                    ) -PassThru |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content '') -PassThru |
                    Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -Content  (@{  'application/json' = '' ; 'application/xml' = '' })

        }
    }
    Add-PodeAuthMiddleware -Name test -Authentication 'test' -Route '/api/*'
    Select-PodeOADefinition -Tag 'v3.1', 'v3' -Scriptblock {
        Add-PodeRouteGroup -Path '/api/v3'    -Routes {
            #PUT
            Add-PodeRoute -PassThru -Method Put -Path '/pet' -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $JsonPet -SchemaReference 'Pet'
                if ($Validate.result) {
                    $Pet = $WebEvent.data
                    $Pet.tags.id = Get-Random -Minimum 1 -Maximum 9999999
                    Write-PodeJsonResponse -Value ($Pet | ConvertTo-Json -Depth 20 ) -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -StatusCode 405 -Value @{
                        result  = $Validate.result
                        message = $Validate.message -join ', '
                    }
                }
            } | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru |
                Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'PetBodySchema' ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -Content @{
                    'application/json' = (New-PodeOAObjectProperty -Properties @((New-PodeOAStringProperty -Name 'result'), (New-PodeOAStringProperty -Name 'message')))
                }

            Add-PodeRoute -PassThru -Method Post -Path '/pet'  -Authentication 'Login-OAuth2' -Scope 'write'  -ScriptBlock {

                $JsonPet = ConvertTo-Json $WebEvent.data
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $JsonPet -SchemaReference 'Pet'
                if ($Validate.result) {
                    $Pet = $WebEvent.data
                    $Pet.tags.id = Get-Random -Minimum 1 -Maximum 9999999
                    Write-PodeJsonResponse -Value ($Pet | ConvertTo-Json -Depth 20 ) -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -StatusCode 405 -Value @{
                        result  = $Validate.result
                        message = $Validate.message -join ', '
                    }
                }
            } | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' -Tags 'pet' -OperationId 'addPet' -PassThru |
                Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'PetBodySchema' ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -Content @{
                    'application/json' = (New-PodeOAObjectProperty -Properties @((New-PodeOAStringProperty -Name 'result'), (New-PodeOAStringProperty -Name 'message')))
                }

            Add-PodeRoute -PassThru -Method Post -Path '/petcallback'  -Authentication 'Login-OAuth2' -Scope 'write'  -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $JsonPet -SchemaReference 'Pet'
                if ($Validate.result) {
                    $Pet = $WebEvent.data
                    $Pet.tags.id = Get-Random -Minimum 1 -Maximum 9999999
                    Write-PodeJsonResponse -Value ($Pet | ConvertTo-Json -Depth 20 ) -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -StatusCode 405 -Value @{
                        result  = $Validate.result
                        message = $Validate.message -join ', '
                    }
                }
            } | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' -Tags 'pet' -OperationId 'addPetcallback' -PassThru |
                Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'PetBodySchema' ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -Content @{
                    'application/json' = (New-PodeOAObjectProperty -Properties @((New-PodeOAStringProperty -Name 'result'), (New-PodeOAStringProperty -Name 'message')))
                } -PassThru |
                Add-PodeOACallBack -Name 'test' -Path '{$request.body#/id}' -Method Post  -RequestBody (New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id') } ) `
                    -Response (
                    New-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' -Array) |
                        New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
                        New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
                        New-PodeOAResponse -Default   -Description 'Something is wrong'
                    )

            #Define CallBack Reference

            Add-PodeOAComponentCallBack -Name 'test' -Path '{$request.body#/id}' -Method Post  -RequestBody (New-PodeOARequestBody -Content @{'*/*' = (New-PodeOAStringProperty -Name 'id') } ) `
                -Response (
                New-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' -Array) |
                    New-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' |
                    New-PodeOAResponse -StatusCode 404 -Description 'Pet not found' |
                    New-PodeOAResponse -Default   -Description 'Something is wrong'
            )


            Add-PodeRoute -PassThru -Method Post -Path '/petcallbackReference'  -Authentication 'Login-OAuth2' -Scope 'write'  -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $JsonPet -SchemaReference 'Pet'
                if ($Validate.result) {
                    $Pet = $WebEvent.data
                    $Pet.tags.id = Get-Random -Minimum 1 -Maximum 9999999
                    Write-PodeJsonResponse -Value ($Pet | ConvertTo-Json -Depth 20 ) -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -StatusCode 405 -Value @{
                        result  = $Validate.result
                        message = $Validate.message -join ', '
                    }
                }
            } | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' -Tags 'pet' -OperationId 'petcallbackReference' -PassThru |
                Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Reference 'PetBodySchema' ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -Content @{
                    'application/json' = ( New-PodeOAStringProperty -Name 'result' | New-PodeOAStringProperty -Name 'message' | New-PodeOAObjectProperty )
                } -PassThru |
                Add-PodeOACallBack -Name 'test1'   -Reference 'test'


            Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'Login-OAuth2' -Scope 'read' -AllowAnon -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(
                (  New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') | ConvertTo-PodeOAParameter -In Query )
                ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' -Array) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'









            Add-PodeRoute -PassThru -Method get -Path '/pet/findByTag' -Authentication 'test' -Scope 'read' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Finds Pets by tags' -Description 'Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.' -Tags 'pet' -OperationId 'findPetsByTags' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(
                    (  New-PodeOAStringProperty -Name 'tag' -Description 'Tags to filter by' -Array | ConvertTo-PodeOAParameter -In Query -Explode)
                ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru | #missing array   application/json:
                # schema:
                #  type: array
                #  items:
                #     $ref: '#/components/schemas/Pet'
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value' -PassThru |
                Add-PodeOAResponse -Default  -Description 'Unexpected error' -Content  (New-PodeOAContentMediaType -MediaType 'application/json'  -Content 'ErrorModel' )

            Add-PodeRoute -PassThru -Method Get -Path '/pet/:petId' -Authentication 'Login-OAuth2' -Scope 'read' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Find pet by ID' -Description 'Returns a single pet.' -Tags 'pet' -OperationId 'getPetById' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found'

            Add-PodeRoute -PassThru -Method post -Path '/pet/:petId' -Authentication 'Login-OAuth2' -Scope 'write' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePetWithForm' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ),
                            (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                            (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query )
                ) -RequestBody (
                    New-PodeOARequestBody -Properties -Content @{
                        'multipart/form-data' = (New-PodeOAStringProperty -Name 'file' -Format binary -Array)
                    }) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'



            Add-PodeRoute -PassThru -Method post -Path '/pet2/:petId' -Authentication 'Login-OAuth2' -Scope 'write' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePet2WithForm' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ),
                                (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                                (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query )
                ) -RequestBody (
                    New-PodeOARequestBody   -Content    @{
                        'application/x-www-form-urlencoded' = (New-PodeOAObjectProperty -Properties @(
                         (New-PodeOAStringProperty -name 'id' -format 'uuid'), (New-PodeOAObjectProperty -name 'address' -NoProperties)))

                    }) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

            Add-PodeRoute -PassThru -Method post -Path '/pet3/:petId' -Authentication 'Login-OAuth2' -Scope 'write' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePet3WithForm' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ),
                                    (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                                    (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query )
                ) -RequestBody (New-PodeOARequestBody -Content @{'multipart/form-data' =
                        New-PodeOAStringProperty -name 'id' -format 'uuid' |
                            New-PodeOAObjectProperty -name 'address' -NoProperties |
                            New-PodeOAStringProperty -name 'children' -array |
                            New-PodeOASchemaProperty -Name 'addresses' -Reference 'Address' -Array |
                            New-PodeOAObjectProperty
                        }) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
                    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                    Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'


            Add-PodeRoute -PassThru -Method post -Path '/pet4/:petId' -Authentication 'Login-OAuth2' -Scope 'write' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePet4WithForm' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ),
                                            (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                                            (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query )
                ) -RequestBody (New-PodeOARequestBody -Content @{'multipart/form-data' =
                        New-PodeOAStringProperty -name 'id' -format 'uuid' |
                            New-PodeOAObjectProperty -name 'address' -NoProperties |
                            New-PodeOAObjectProperty -name 'historyMetadata' -Description 'metadata in XML format' -NoProperties |
                            New-PodeOAStringProperty -name 'profileImage' -Format Binary |
                            New-PodeOAObjectProperty
                        } -Encoding (
                            New-PodeOAEncodingObject -Name 'historyMetadata' -ContentType 'application/xml; charset=utf-8' |
                                New-PodeOAEncodingObject -Name 'profileImage' -ContentType 'image/png, image/jpeg' -Headers (
                                    New-PodeOAIntProperty -name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period' -Default 3 -Enum @(1, 2, 3) -Maximum 3 |
                                        New-PodeOAIntProperty -Name 'X-Rate-Limit-Reset' -Description 'The number of seconds left in the current period' -Minimum 2
                                    )
                                )
                            ) | Add-PodeOAResponse -StatusCode 200 -PassThru  -Description 'A simple string response'   -Content (  New-PodeOAContentMediaType -MediaType 'text/plain' -Content ( New-PodeOAStringProperty)) |
                            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'



            Add-PodeRoute -PassThru -Method post -Path '/pet/:petId/uploadImage2' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Uploads an image' -Description 'Updates a pet in the store with a new image' -Tags 'pet' -OperationId 'uploadFile2' -PassThru |
                Set-PodeOARequest -Parameters @(
                                            (  New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of pet that needs to be updated' -Required | ConvertTo-PodeOAParameter -In Path ),
                                            (  New-PodeOAStringProperty -Name 'additionalMetadata' -Description 'Additional Metadata' | ConvertTo-PodeOAParameter -In Query )
                ) -RequestBody (New-PodeOARequestBody -Required -Content @{   'multipart/form-data' = New-PodeOAObjectProperty -Properties @( (New-PodeOAStringProperty -Name 'image' -Format Binary  )) } ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'A simple string response' -Content  (
                    New-PodeOAContentMediaType -MediaType 'text/plain' -Content ( New-PodeOAStringProperty -Example 'whoa!')) -Headers (
                    New-PodeOAIntProperty -Name 'X-Rate-Limit-Limit' -Description 'The number of allowed requests in the current period' |
                        New-PodeOAIntProperty -Name 'X-Rate-Limit-Remaining' -Description 'The number of remaining requests in the current period' |
                        New-PodeOAIntProperty -Name 'X-Rate-Limit-Reset' -Description 'The number of seconds left in the current period' -Maximum 3
                    )

            Add-PodeRoute -PassThru -Method Delete -Path '/pet/:petId' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Deletes a pet' -Description 'Deletes a pet.' -Tags 'pet' -OperationId 'deletePet' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found'

            Add-PodeRoute -PassThru -Method post -Path '/pet/:petId/uploadmultiImage' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Uploads an image' -Description 'Updates a pet in the store with a new image' -Tags 'pet' -OperationId 'uploadFilemulti' -PassThru |
                Set-PodeOARequest -Parameters @(
                                (  New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of pet that needs to be updated' -Required | ConvertTo-PodeOAParameter -In Path ),
                                (  New-PodeOAStringProperty -Name 'additionalMetadata' -Description 'Additional Metadata' | ConvertTo-PodeOAParameter -In Query )
                ) -RequestBody (
                    New-PodeOARequestBody -Required -Content  ( New-PodeOAContentMediaType -MediaType 'multipart/form-data' -Upload -PartContentMediaType 'application/octect-stream' -Content (
                            New-PodeOAIntProperty  -name 'orderId' | New-PodeOAStringProperty -Name 'image' -Format Binary | New-PodeOAObjectProperty  ))
                ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = 'ApiResponse' } -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'


            Add-PodeRoute -PassThru -Method post -Path '/pet/:petId/uploadImageOctet' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Uploads an image' -Description 'Updates a pet in the store with a new image' -Tags 'pet' -OperationId 'uploadFileOctet' -PassThru |
                Set-PodeOARequest -Parameters @(
                                    (  New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of pet that needs to be updated' -Required | ConvertTo-PodeOAParameter -In Path ),
                                    (  New-PodeOAStringProperty -Name 'additionalMetadata' -Description 'Additional Metadata' | ConvertTo-PodeOAParameter -In Query )
                ) -RequestBody (
                    New-PodeOARequestBody -Required -Content  ( New-PodeOAContentMediaType -MediaType 'application/octet-stream' -Upload )
                ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = 'ApiResponse' } -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

            Add-PodeRoute -PassThru -Method Get -Path '/store/inventory' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Returns pet inventories by status' -Description 'Returns a map of status codes to quantities' -Tags 'store' -OperationId 'getInventory' -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{  'application/json' = New-PodeOAObjectProperty -Properties @(New-PodeOAStringProperty -Name 'none'  ) }  #missing additionalProperties


            Add-PodeRoute -PassThru -Method post -Path '/store/order' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Deprecated -Summary 'Place an order for a pet' -Description 'Place a new order in the store' -Tags 'store' -OperationId 'placeOrder' -PassThru |
                Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'Order'  )) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (@{  'application/json' = 'Order' ; 'application/xml' = 'Order' }) -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

            Add-PodeRoute -PassThru -Method Get -Path '/store/order/:orderId' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } |
                Add-PodeOAExternalRoute -Servers (
                    New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
                        New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13' |
                        New-PodeOAServerEndpoint -Url 'http://ext14.server.com/api/v12' -Description 'ext test server 14'
                    ) -PassThru |
                    Set-PodeOARouteInfo -Summary 'Find purchase order by ID' -Description 'For valid response try integer IDs with value <= 5 or > 10. Other values will generate exceptions.' -Tags 'store' -OperationId 'getOrderById' -PassThru |
                    Set-PodeOARequest -PassThru -Parameters @(
                            (  New-PodeOAIntProperty -Name 'orderId' -Format Int64 -Description 'ID of order that needs to be fetched' -Required | ConvertTo-PodeOAParameter -In Path )
                    ) |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'Order'  ) -PassThru |
                    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                    Add-PodeOAResponse -StatusCode 404 -Description 'Order not found'

            Add-PodeRoute -PassThru -Method Delete -Path '/store/order/:orderId' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Delete purchase order by ID' -Description 'For valid response try integer IDs with value < 1000. Anything above 1000 or nonintegers will generate API errors.' -Tags 'store' -OperationId 'deleteOrder' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(
                                (  New-PodeOAIntProperty -Name 'orderId' -Format Int64 -Description ' ID of the order that needs to be deleted' -Required | ConvertTo-PodeOAParameter -In Path )
                ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'Order not found'


            Add-PodeRoute -PassThru -Method post -Path '/user' -ScriptBlock {
                $JsonUser = ConvertTo-Json $WebEvent.data
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $JsonUser -SchemaReference 'User'
                if ($Validate.result) {
                    $User = $WebEvent.data
                    $User.id = Get-Random -Minimum 1 -Maximum 9999999
                    Write-PodeJsonResponse -Value ($User | ConvertTo-Json -Depth 20 ) -StatusCode 200
                }
                else {
                    Write-PodeJsonResponse -StatusCode 405 -Value @{
                        result  = $Validate.result
                        message = $Validate.message -join ', '
                    }
                }
            } | Set-PodeOARouteInfo -Summary 'Create user.' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'createUser' -PassThru |
                Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input' -Content @{
                    'application/json' = (New-PodeOAObjectProperty -Properties @((New-PodeOAStringProperty -Name 'result'), (New-PodeOAStringProperty -Name 'message')))
                }

            Add-PodeRoute -PassThru -Method post -Path '/user/createWithList' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Creates list of users with given input array.' -Description 'Creates list of users with given input array.' -Tags 'user' -OperationId 'createUsersWithListInput' -PassThru |
                Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

            Add-PodeRoute -PassThru -Method Get -Path '/user/login' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Logs user into the system.' -Description 'Logs user into the system.' -Tags 'user' -OperationId 'loginUser' -PassThru |
                Set-PodeOARequest -PassThru -Parameters @(
                            (  New-PodeOAStringProperty -Name 'username' -Description 'The user name for login' | ConvertTo-PodeOAParameter -In Query )
                            (  New-PodeOAStringProperty -Name 'password' -Description 'The password for login in clear text' -Format Password | ConvertTo-PodeOAParameter -In Query )
                ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml' -Content 'string' ) `
                    -Header @('X-Rate-Limit', 'X-Expires-After') -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username/password supplied'


            Add-PodeRoute -PassThru -Method Get -Path '/user/logout' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Logs out current logged in user session.' -Description 'Logs out current logged in user session.' -Tags 'user' -OperationId 'logoutUser' -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'

            Add-PodeRoute -PassThru -Method Get -Path '/user/:username' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Get user by user name' -Description 'Get user by user name.' -Tags 'user' -OperationId 'getUserByName' -PassThru |
                Set-PodeOARequest -Parameters @(
                            (  New-PodeOAStringProperty -Name 'username' -Description 'The name that needs to be fetched. Use user1 for testing.' -Required | ConvertTo-PodeOAParameter -In Path )
                ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'User not found'

            $Responses = New-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' |
                New-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' |
                New-PodeOAResponse -StatusCode 404 -Description 'User not found' |
                New-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'


            Add-PodeRoute -PassThru -Method Put -Path '/user_1/:username' -OAResponses $Responses -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Update user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'updateUser_1' -PassThru |
                Set-PodeOARequest -Parameters @(
                (  New-PodeOAStringProperty -Name 'username' -Description ' name that need to be updated.' -Required | ConvertTo-PodeOAParameter -In Path )
                ) -RequestBody (New-PodeOARequestBody -Required -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'StructPart' ))


            Add-PodeRoute -PassThru -Method Put -Path '/user/:username' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Update user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'updateUser' -PassThru |
                Set-PodeOARequest -Parameters @(
            (  New-PodeOAStringProperty -Name 'username' -Description ' name that need to be updated.' -Required | ConvertTo-PodeOAParameter -In Path )
                ) -RequestBody (New-PodeOARequestBody -Required -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'User not found' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'



            Add-PodeRoute -PassThru -Method Put -Path '/userLink/:username' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Update user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'updateUserLink' -PassThru |
                Set-PodeOARequest -Parameters @(
                (  New-PodeOAStringProperty -Name 'username' -Description ' name that need to be updated.' -Required | ConvertTo-PodeOAParameter -In Path )
                ) -RequestBody (New-PodeOARequestBody -Required -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User' }  -PassThru `
                    -Links (New-PodeOAResponseLink -Name address -OperationId 'getUserByName' -Parameters  @{'username' = '$request.path.username' } ) |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'User not found' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

            #Add link reference
            Add-PodeOAComponentResponseLink -Name 'address' -OperationId 'getUserByName' -Parameters  @{'username' = '$request.path.username' }

            #use link reference
            Add-PodeRoute -PassThru -Method Put -Path '/userLinkByRef/:username' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Update user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'updateUserLinkByRef' -PassThru |
                Set-PodeOARequest -Parameters @(
                (  New-PodeOAStringProperty -Name 'username' -Description ' name that need to be updated.' -Required | ConvertTo-PodeOAParameter -In Path )
                ) -RequestBody (New-PodeOARequestBody -Required -Content (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Content @{'application/json' = 'User' }  -PassThru `
                    -Links (New-PodeOAResponseLink -Name 'address2' -Reference 'address' ) |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'User not found' -PassThru |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'



            Add-PodeRoute -PassThru -Method Delete -Path '/usera/:username' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Delete user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'deleteUser' -PassThru |
                Set-PodeOARequest -Parameters @(
                                (  New-PodeOAStringProperty -Name 'username' -Description 'The name that needs to be deleted.' -Required | ConvertTo-PodeOAParameter -In Path )
                ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'User not found'


            Remove-PodeRoute -Method Delete -Path '/api/v3/usera/:username'


            Add-PodeRoute -PassThru -Method Delete -Path '/user/:username' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 200
            } | Set-PodeOARouteInfo -Summary 'Delete user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'deleteUser' -PassThru |
                Set-PodeOARequest -Parameters @(
                                    (  New-PodeOAStringProperty -Name 'username' -Description 'The name that needs to be deleted.' -Required | ConvertTo-PodeOAParameter -In Path )
                ) -PassThru |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'User not found'



            Add-PodeOAExternalRoute -Method Get -Path '/stores/order/:orderId' -Servers (
                New-PodeOAServerEndpoint -Url 'http://ext.server.com/api/v12' -Description 'ext test server' |
                    New-PodeOAServerEndpoint -Url 'http://ext13.server.com/api/v12' -Description 'ext test server 13' |
                    New-PodeOAServerEndpoint -Url 'http://ext14.server.com/api/v12' -Description 'ext test server 14'
                ) -PassThru | Set-PodeOARouteInfo -Summary 'Find purchase order by ID' -Description 'For valid response try integer IDs with value <= 5 or > 10. Other values will generate exceptions.' -Tags 'store' -OperationId 'getOrderExternalById' -PassThru |
                    Set-PodeOARequest -PassThru -Parameters @(
                                (  New-PodeOAIntProperty -Name 'orderId' -Format Int64 -Description 'ID of order that needs to be fetched' -Required | ConvertTo-PodeOAParameter -In Path )
                    ) |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  (New-PodeOAContentMediaType -MediaType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'Order'  ) -PassThru |
                    Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                    Add-PodeOAResponse -StatusCode 404 -Description 'Order not found'
        }
    }
    Select-PodeOADefinition -Tag 'v3.1' -Scriptblock {
        Add-PodeRouteGroup -Path '/api/v5'    -Routes {

            Add-PodeRoute  -Method Get -Path '/petbyRef/:petId' -Authentication 'api_key' -Scope 'read' -OAReference 'GetPetByIdWithRef' -ScriptBlock {
                Write-PodeJsonResponse -Value 'done' -StatusCode 2005
            }

        }
    }


    $yaml = Get-PodeOADefinition -Format Yaml -DefinitionTag 'v3.1'
    $json = Get-PodeOADefinition -Format Json -DefinitionTag 'v3'

    Write-PodeHost "`rYAML Tag: v3.1  Output:`r $yaml"

    Write-PodeHost "`rJSON Tag: v3 Output:`r $json"
}