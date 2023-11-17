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



    Enable-PodeOpenApi -Path '/docs/openapi'     -OpenApiVersion '3.0.3' -EnableSchemaValidation -DisableMinimalDefinitions
    New-PodeOAExternalDoc -Name 'SwaggerDocs' -Description 'Find out more about Swagger' -Url 'http://swagger.io'
    Add-PodeOAExternalDoc -Reference 'SwaggerDocs'
    Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription  -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io' -ContactUrl 'http://example.com/support'
    Add-PodeOAServerEndpoint -url '/api/v3' -Description 'default endpoint'

    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode

    Enable-PodeOAViewer -Type Bookmarks -Path '/docs'



    Add-PodeOATag -Name 'user' -Description 'Operations about user' -ExternalDoc 'SwaggerDocs'
    Add-PodeOATag -Name 'store' -Description 'Access to Petstore orders' -ExternalDoc 'SwaggerDocs'
    Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc 'SwaggerDocs'

    <#   Add-PodeOAComponentSchema -Name 'Address' -Schema (
        New-PodeOAObjectProperty -Name 'Address' -Xml @{'name' = 'address' } -Description 'Shipping Address' -Properties (
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
        New-PodeOAObjectProperty -Name 'User' -Xml @{'name' = 'user' } -Properties  (
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
        New-PodeOAObjectProperty -Name 'Address' -Xml @{'name' = 'address' } -Description 'Shipping Address' |
        Add-PodeOAComponentSchema -Name 'Address'


    New-PodeOAIntProperty -Name 'id'-Format Int64 -ReadOnly -Example 10 |
        New-PodeOAIntProperty -Name 'petId' -Format Int64 -Example 198772 |
        New-PodeOAIntProperty -Name 'quantity' -Format Int32 -Example 7 |
        New-PodeOAStringProperty -Name 'shipDate' -Format Date-Time |
        New-PodeOAStringProperty -Name 'status' -Description 'Order Status' -Example 'approved' -Enum @('placed', 'approved', 'delivered') |
        New-PodeOABoolProperty -Name 'complete' |
        New-PodeOASchemaProperty -Name 'Address' -ComponentSchema 'Address' |
        New-PodeOAObjectProperty -Name 'Order' -Xml @{'name' = 'order' } |
        Add-PodeOAComponentSchema -Name 'Order'



    Add-PodeOAComponentSchema -Name 'Category' -Schema (
        New-PodeOAObjectProperty -Name 'Category' -Xml @{'name' = 'category' } -Properties  (
            New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
                New-PodeOAStringProperty -Name 'name' -Example 'Dogs'
        ))

    Add-PodeOAComponentSchema -Name 'User' -Schema (
        New-PodeOAObjectProperty -Name 'User' -Xml @{'name' = 'user' } -Properties  (
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

    Add-PodeOAComponentSchema -Name 'Tag' -Schema (
        New-PodeOAObjectProperty -Name 'Tag' -Xml @{'name' = 'tag' } -Properties  (
            New-PodeOAIntProperty -Name 'id'-Format Int64 |
                New-PodeOAStringProperty -Name 'name'
        ))

    Add-PodeOAComponentSchema -Name 'Pet' -Schema (
        New-PodeOAObjectProperty -Name 'Pet' -Xml @{'name' = 'pet' } -Properties  (
            New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly |
                New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required |
                New-PodeOASchemaProperty -Name 'category' -ComponentSchema 'Category' |
                New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required |
                New-PodeOAStringProperty -Name 'photoUrls' -Array |
                New-PodeOASchemaProperty -Name 'tags' -ComponentSchema 'Tag' |
                New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold')
        ))



    <#   Alternative :
        Add-PodeOAComponentSchema -Name 'Pet' -Schema (
        New-PodeOAObjectProperty -Name 'Pet' -Xml @{'name' = 'pet' } -Properties @(
                    (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly),
                        (New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required),
                        (New-PodeOASchemaProperty -Name 'category' -ComponentSchema 'Category'),
                        (New-PodeOAStringProperty -Name 'petType' -Example 'dog' -Required),
                        (New-PodeOAStringProperty -Name 'photoUrls' -Array),
                        (New-PodeOASchemaProperty -Name 'tags' -ComponentSchema 'Tag')
                        (New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold'))
        ))  #>

    <#    Add-PodeOAComponentSchema -Name 'Cat' -Schema (   New-PodeOAObjectProperty  -Name 'testcat' -Description 'Type of cat' -Properties (
            New-PodeOAStringProperty -Name 'breed' -Description 'Type of Breed' -Enum @(  'Abyssinian', 'Balinese-Javanese', 'Burmese', 'British Shorthair') |
                Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions @( 'Pet',
                (New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @(  'clueless', 'lazy', 'adventurous', 'aggressive') -Object)
                )
        )
    )#>


    New-PodeOAStringProperty -Name 'huntingSkill' -Description 'The measured skill for hunting' -Enum @(  'clueless', 'lazy', 'adventurous', 'aggressive') -Object |
        Merge-PodeOAProperty  -Type AllOf  -ObjectDefinitions 'Pet' |
        New-PodeOAStringProperty -Name 'breed' -Description 'Type of Breed' -Enum @(  'Abyssinian', 'Balinese-Javanese', 'Burmese', 'British Shorthair') |

        New-PodeOAObjectProperty   -Description 'Type of cat' | Add-PodeOAComponentSchema -Name 'Cat'





    Add-PodeOAComponentSchema -Name 'Dog' -Schema (
        Merge-PodeOAProperty  -Type AllOf -ObjectDefinitions @( 'Pet', ( New-PodeOAObjectProperty -Properties (
                    New-PodeOAStringProperty -Name 'breed' -Description 'Type of Breed' -Enum @(  'Dingo', 'Husky', 'Retriever', 'Shepherd') |
                        New-PodeOABoolProperty -Name 'bark'
                ))
        )
    )


    Add-PodeOAComponentSchema -Name 'Pets' -Schema (
        Merge-PodeOAProperty  -Type OneOf -ObjectDefinitions @( 'Cat', 'Dog') -Discriminator 'petType')


    Add-PodeOAComponentSchema -Name 'ApiResponse' -Schema (
        New-PodeOAObjectProperty -Name 'ApiResponse' -Xml @{'name' = '##default' } -Properties  (
            New-PodeOAIntProperty -Name 'code'-Format Int32 |
                New-PodeOAStringProperty -Name 'type' -Example 'doggie' |
                New-PodeOAStringProperty -Name 'message'
        )
    )


    Add-PodeRoute -PassThru -Method Get -Path '/peta/:id' -ScriptBlock {
        Write-PodeJsonResponse -Value (Get-Pet -Id $WebEvent.Parameters['id']) -StatusCode 200
    } |
        Set-PodeOARouteInfo -Summary 'Find pets by ID' -Description 'Returns pets based on ID'  -OperationId 'getPetsById' -PassThru |
        Set-PodeOARequest -PassThru -Parameters @(
        (  New-PodeOAStringProperty -Name 'id' -Description 'ID of pet to use' -array | ConvertTo-PodeOAParameter -In Path -Style Simple -Required )) |
        Add-PodeOAResponse -StatusCode 200 -Description 'pet response'   -ContentSchemas (@{  '*/*' = New-PodeOASchemaProperty   -ComponentSchema 'Pet' -array }) -PassThru |
        Add-PodeOAResponse -Default  -Description 'error payload' -ContentSchemas (@{  'text/html' = 'ApiResponse' }) -PassThru






    Add-PodeOAComponentHeaderSchema -Name 'X-Rate-Limit' -Schema (New-PodeOAIntProperty -Format Int32 -Description 'calls per hour allowed by the user' )
    Add-PodeOAComponentHeaderSchema -Name 'X-Expires-After' -Schema (New-PodeOAStringProperty -Format Date-Time -Description 'date in UTC when token expires'  )

    #define '#/components/responses/'
    Add-PodeOAComponentResponse -Name 'UserOpSuccess' -Description 'Successful operation' -ContentSchemas (@{'application/json' = 'User' ; 'application/xml' = 'User' })

    Add-PodeOAComponentRequestBody -Name 'PetBodySchema' -Required -Description 'Pet in the store' -ContentSchemas (@{ 'application/json' = 'Pets'; 'application/xml' = 'Pets'; 'application/x-www-form-urlencoded' = 'Pets' })


    #define '#/components/parameters/'
    Add-PodeOAComponentParameter -Name 'PetIdParam' -Parameter ( New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of the pet' -Required | ConvertTo-PodeOAParameter -In Path )

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
        } else {
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
    $tenantId = '56456232'

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
    New-PodeOAExample -MediaType 'application/json' -Name 'user' -Summary   'User Example' -ExternalValue  'http://foo.bar/examples/user-example.json'  |
        New-PodeOAExample -MediaType 'application/xml' -Name 'user' -Summary   'User Example in XML' -ExternalValue  'http://foo.bar/examples/user-example.xml'  |
        New-PodeOAExample -MediaType 'text/plain' -Name 'user' -Summary   'User Example in Plain text' -ExternalValue 'http://foo.bar/examples/user-example.txt' |
        New-PodeOAExample -MediaType '*/*' -Name 'user' -Summary   'User example in other forma' -ExternalValue  'http://foo.bar/examples/user-example.whatever'


    Add-PodeRoute -PassThru -Method Put -Path '/pat/:petId' -ScriptBlock {
        $JsonPet = ConvertTo-Json $WebEvent.data
        if ( Update-Pet -Id $WebEvent.Parameters['petId'] -Data  $JsonPet) {
            Write-PodeJsonResponse -Value @{} -StatusCode 200
        } else {
            Write-PodeJsonResponse -Value @{} -StatusCode 405
        }
    } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatePasdadaetWithForm' -PassThru |
        Set-PodeOARequest  -Parameters @(
            (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
        ) -RequestBody (
            New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'User'; 'application/xml' = 'User' }  -Examples  $ex

        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -ContentSchemas (@{  'application/json' = '' ; 'application/xml' = '' })  -PassThru |
        Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -ContentSchemas  (@{  'application/json' = '' ; 'application/xml' = '' })

    Add-PodeRoute -PassThru -Method Put -Path '/paet/:petId' -ScriptBlock {
        $JsonPet = ConvertTo-Json $WebEvent.data
        if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet) {
            Write-PodeJsonResponse -Value @{} -StatusCode 200
        } else {
            Write-PodeJsonResponse -Value @{} -StatusCode 405
        }
    } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet' -PassThru |
        Set-PodeOARequest  -Parameters @(
          (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required -Examples (
            New-PodeOAExample   -Name 'user' -Summary   'User Example' -Value  'http://foo.bar/examples/user-example.json'  |
          New-PodeOAExample   -Name 'user1' -Summary   'User Example in XML' -Value  'http://foo.bar/examples/user-example.xml'  |
          New-PodeOAExample   -Name 'user2' -Summary   'User Example in Plain text' -Value 'http://foo.bar/examples/user-example.txt' |
          New-PodeOAExample  -Name 'user3' -Summary   'User example in other forma' -Value  'http://foo.bar/examples/user-example.whatever' ))
        ) -RequestBody (New-PodeOARequestBody -Required -Content (@{
                    'application/x-www-form-urlencoded' = New-PodeOAObjectProperty -Properties @(
              (New-PodeOAStringProperty -Name 'name' -Description 'Updated name of the pet'),
              (New-PodeOAStringProperty -Name 'status' -Description 'Updated status of the pet' -Required)
                    )
                })
        ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -ContentSchemas (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
        Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -ContentSchemas  (@{  'application/json' = '' ; 'application/xml' = '' })


    Add-PodeRoute -PassThru -Method Put -Path '/paet2/:petId' -ScriptBlock {
        $JsonPet = ConvertTo-Json $WebEvent.data
        if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet) {
            Write-PodeJsonResponse -Value @{} -StatusCode 200
        } else {
            Write-PodeJsonResponse -Value @{} -StatusCode 405
        }
    } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet2' -PassThru |
        Set-PodeOARequest  -Parameters @(
              (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
        ) -RequestBody (New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'text/plain' = New-PodeOAStringProperty   -array } ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -ContentSchemas (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
        Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -ContentSchemas  (@{  'application/json' = '' ; 'application/xml' = '' })



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
        } else {
            Write-PodeJsonResponse -Value @{} -StatusCode 405
        }
    } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet3' -PassThru |
        Set-PodeOARequest  -Parameters @(
                  (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required)
        ) -RequestBody (New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'Pet' } -Examples (
                New-PodeOAExample -MediaType 'application/json' -Name 'cat' -Summary   'An example of a cat' -Value    @{name = 'Fluffy'; petType = 'Cat'; color = 'White'; gender = 'male'; breed = 'Persian' } |
                    New-PodeOAExample -MediaType 'application/json' -Name 'dog' -Summary   "An example of a dog with a cat's name" -Value    @{name = 'Puma'; petType = 'Dog'; color = 'Black'; gender = 'Female'; breed = 'Mixed' } |
                    New-PodeOAExample -MediaType 'application/json' -Reference 'frog-example'
                )

            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -ContentSchemas (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -ContentSchemas  (@{  'application/json' = '' ; 'application/xml' = '' })


            Add-PodeRoute -PassThru -Method Put -Path '/paet4/:petId' -ScriptBlock {
                $JsonPet = ConvertTo-Json $WebEvent.data
                if ( Update-Pet -Id $WebEvent.Parameters['id'] -Data  $JsonPet) {
                    Write-PodeJsonResponse -Value @{} -StatusCode 200
                } else {
                    Write-PodeJsonResponse -Value @{} -StatusCode 405
                }
            } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store with form data'   -Tags 'pet' -OperationId 'updatepaet4' -PassThru |
                Set-PodeOARequest  -Parameters @(
                          (New-PodeOAStringProperty -Name 'petId' -Description 'ID of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Path -Required -ContentType "application/json")
                ) -RequestBody (New-PodeOARequestBody -Description 'user to add to the system' -Content @{ 'application/json' = 'Pet' } -Examples (
                        New-PodeOAExample -MediaType 'application/json' -Name 'cat' -Summary   'An example of a cat' -Value    @{name = 'Fluffy'; petType = 'Cat'; color = 'White'; gender = 'male'; breed = 'Persian' } |
                            New-PodeOAExample -MediaType 'application/json' -Name 'dog' -Summary   "An example of a dog with a cat's name" -Value    @{name = 'Puma'; petType = 'Dog'; color = 'Black'; gender = 'Female'; breed = 'Mixed' } |
                            New-PodeOAExample -MediaType 'application/json' -Reference 'frog-example'
                        )

                    ) -PassThru |
                    Add-PodeOAResponse -StatusCode 200 -Description 'Pet updated.' -ContentSchemas (@{  'application/json' = '' ; 'application/xml' = '' }) -PassThru |
                    Add-PodeOAResponse -StatusCode 405 -Description 'Method Not Allowed' -ContentSchemas  (@{  'application/json' = '' ; 'application/xml' = '' })



    Add-PodeAuthMiddleware -Name test -Authentication 'test' -Route '/api/*'
    Add-PodeRouteGroup -Path '/api/v3'   -Routes {
        #PUT
        Add-PodeRoute -PassThru -Method Put -Path '/pet' -ScriptBlock {
            $JsonPet = ConvertTo-Json $WebEvent.data
            $Validate = Test-PodeOARequestSchema -Json $JsonPet -SchemaReference 'Pet'
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
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Schema 'PetBodySchema' ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -ContentSchemas @{
                'application/json' = (New-PodeOAObjectProperty -Properties @(    (New-PodeOAStringProperty -Name 'result'), (New-PodeOAStringProperty -Name 'message')  ))
            }

        Add-PodeRoute -PassThru -Method Post -Path '/pet'  -Authentication 'Login-OAuth2' -Scope 'write'  -ScriptBlock {

            $JsonPet = ConvertTo-Json $WebEvent.data
            $Validate = Test-PodeOARequestSchema -Json $JsonPet -SchemaReference 'Pet'
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
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Schema 'PetBodySchema' ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' -ContentSchemas @{
                'application/json' = (New-PodeOAObjectProperty -Properties @(    (New-PodeOAStringProperty -Name 'result'), (New-PodeOAStringProperty -Name 'message')  ))
            }

        Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'Login-OAuth2' -Scope 'read' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                (  New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') | ConvertTo-PodeOAParameter -In Query )
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentArray -ContentSchemas (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) -PassThru |
            # schema:
            #  type: array
            #  items:
            #     $ref: '#/components/schemas/Pet'
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'

        Add-PodeRoute -PassThru -Method get -Path '/pet/findByTag' -Authentication 'test' -Scope 'read' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Finds Pets by tags' -Description 'Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.' -Tags 'pet' -OperationId 'findPetsByTags' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                    (  New-PodeOAStringProperty -Name 'tag' -Description 'Tags to filter by' -Array | ConvertTo-PodeOAParameter -In Query -Explode)
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) -PassThru | #missing array   application/json:
            # schema:
            #  type: array
            #  items:
            #     $ref: '#/components/schemas/Pet'
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value'

        Add-PodeRoute -PassThru -Method Get -Path '/pet/:petId' -Authentication 'Login-OAuth2' -Scope 'read' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Find pet by ID' -Description 'Returns a single pet.' -Tags 'pet' -OperationId 'getPetById' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas (@{  'application/json' = 'Pet' ; 'application/xml' = 'Pet' }) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found'

        Add-PodeRoute -PassThru -Method post -Path '/pet/:petId' -Authentication 'Login-OAuth2' -Scope 'write' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePetWithForm' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ),
                            (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                            (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query )
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'


        Add-PodeRoute -PassThru -Method Delete -Path '/pet/:petId' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Deletes a pet' -Description 'Deletes a pet.' -Tags 'pet' -OperationId 'deletePet' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @( ConvertTo-PodeOAParameter -Reference 'PetIdParam'  ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found'

        Add-PodeRoute -PassThru -Method post -Path '/pet/:petId/uploadImage' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Uploads an image' -Description 'Updates a pet in the store with a new image' -Tags 'pet' -OperationId 'uploadFile' -PassThru |
            Set-PodeOARequest -Parameters @(
                                (  New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of pet that needs to be updated' -Required | ConvertTo-PodeOAParameter -In Path ),
                                (  New-PodeOAStringProperty -Name 'additionalMetadata' -Description 'Additional Metadata' | ConvertTo-PodeOAParameter -In Query )
            ) -RequestBody (New-PodeOARequestBody -Required -Content @{   'multipart/form-data' = New-PodeOAObjectProperty -Properties @( (New-PodeOAStringProperty -Name 'image' -Format Binary  )) } ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{'application/json' = 'ApiResponse' } -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

        Add-PodeRoute -PassThru -Method Get -Path '/store/inventory' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Returns pet inventories by status' -Description 'Returns a map of status codes to quantities' -Tags 'store' -OperationId 'getInventory' -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{  'application/json' = New-PodeOAObjectProperty -Properties @(New-PodeOAStringProperty -Name 'none'  ) }  #missing additionalProperties


        Add-PodeRoute -PassThru -Method post -Path '/store/order' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Deprecated -Summary 'Place an order for a pet' -Description 'Place a new order in the store' -Tags 'store' -OperationId 'placeOrder' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content (@{ 'application/json' = 'Order'; 'application/xml' = 'Order'; 'application/x-www-form-urlencoded' = 'Order' } )) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas (@{  'application/json' = 'Order' ; 'application/xml' = 'Order' }) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

        Add-PodeRoute -PassThru -Method Get -Path '/store/order/:orderId' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Find purchase order by ID' -Description 'For valid response try integer IDs with value <= 5 or > 10. Other values will generate exceptions.' -Tags 'store' -OperationId 'getOrderById' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                            (  New-PodeOAIntProperty -Name 'orderId' -Format Int64 -Description 'ID of order that needs to be fetched' -Required | ConvertTo-PodeOAParameter -In Path )
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas (@{  'application/json' = 'Order' ; 'application/xml' = 'Order' }) -PassThru |
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
            $Validate = Test-PodeOARequestSchema -Json $JsonUser -SchemaReference 'User'
            if ($Validate.result) {
                $User = $WebEvent.data
                $User.id = Get-Random -Minimum 1 -Maximum 9999999
                Write-PodeJsonResponse -Value ($User | ConvertTo-Json -Depth 20 ) -StatusCode 200
            } else {
                Write-PodeJsonResponse -StatusCode 405 -Value @{
                    result  = $Validate.result
                    message = $Validate.message -join ', '
                }
            }
        } | Set-PodeOARouteInfo -Summary 'Create user.' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'createUser' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content (@{ 'application/json' = 'User'; 'application/xml' = 'User'; 'application/x-www-form-urlencoded' = 'User' } )) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input' -ContentSchemas @{
                'application/json' = (New-PodeOAObjectProperty -Properties @(    (New-PodeOAStringProperty -Name 'result'), (New-PodeOAStringProperty -Name 'message')  ))
            }

        Add-PodeRoute -PassThru -Method post -Path '/user/createWithList' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Creates list of users with given input array.' -Description 'Creates list of users with given input array.' -Tags 'user' -OperationId 'createUsersWithListInput' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content (@{ 'application/json' = 'User'; 'application/xml' = 'User'; 'application/x-www-form-urlencoded' = 'User' } )) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

        Add-PodeRoute -PassThru -Method Get -Path '/user/login' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Logs user into the system.' -Description 'Logs user into the system.' -Tags 'user' -OperationId 'loginUser' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                            (  New-PodeOAStringProperty -Name 'username' -Description 'The user name for login' | ConvertTo-PodeOAParameter -In Query )
                            (  New-PodeOAStringProperty -Name 'password' -Description 'The password for login in clear text' -Format Password | ConvertTo-PodeOAParameter -In Query )
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas (@{'application/json' = 'string'; 'application/xml' = 'string' })  `
                -HeaderSchemas @('X-Rate-Limit', 'X-Expires-After') -PassThru |
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

        Add-PodeRoute -PassThru -Method Put -Path '/user/:username' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Update user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'updateUser' -PassThru |
            Set-PodeOARequest -Parameters @(
            (  New-PodeOAStringProperty -Name 'username' -Description ' name that need to be updated.' -Required | ConvertTo-PodeOAParameter -In Path )
            ) -RequestBody (New-PodeOARequestBody -Required -Content (@{ 'application/json' = 'User'; 'application/xml' = 'User'; 'application/x-www-form-urlencoded' = 'User' } )) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Reference 'UserOpSuccess' -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'User not found' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

        Add-PodeRoute -PassThru -Method Delete -Path '/user/:username' -ScriptBlock {
            Write-PodeJsonResponse -Value 'done' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Delete user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'deleteUser' -PassThru |
            Set-PodeOARequest -Parameters @(
                                (  New-PodeOAStringProperty -Name 'username' -Description 'The name that needs to be deleted.' -Required | ConvertTo-PodeOAParameter -In Path )
            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'User not found'

    }


    $yaml = PodeOADefinition -Format Yaml
    # $json=  PodeOADefinition -Format Json
}