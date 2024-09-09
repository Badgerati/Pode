<#
.SYNOPSIS
    PowerShell script to set up a Pode server for a Pet Store API using OpenAPI 3.0 specifications.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and uses OpenAPI 3.0 specifications
    for defining the API. It supports multiple endpoints for managing pets, orders, and users with various
    authentication methods including API key, Basic, and OAuth2.

    This example shows how to use session persistent authentication using Windows Active Directory.
    The example used here is Form authentication, sent from the <form> in HTML.

    Navigating to the 'http://localhost:8081' endpoint in your browser will auto-redirect you to the '/login'
    page. Here, you can type the details for a domain user. Clicking 'Login' will take you back to the home
    page with a greeting and a view counter. Clicking 'Logout' will purge the session and take you back to
    the login page.

.PARAMETER Reset
    Switch parameter to reset the PetData.json file and reinitialize categories, pets, orders, and users.

.EXAMPLE
    To run the sample: ./PetStore/Petstore-OpenApi.ps1

    OpenAPI Info:
    Specification:
        http://localhost:8081/openapi
    Documentation:
        http://localhost:8081/docs

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/PetStore/Petstore-OpenApi.ps1
.NOTES
    Author: Pode Team
    License: MIT License
#>

param (
    [switch]
    $Reset
)

try {
    # Determine paths for the Pode module and Pet Store
    $petStorePath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $podePath = Split-Path -Parent -Path (Split-Path -Parent -Path $petStorePath)

    # Import Pode module from source path or from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }

    # Import additional modules for PetData, Order, and UserData
    Import-Module -Name "$petStorePath/PetData.psm1" -ErrorAction Stop
    Import-Module -Name "$petStorePath/Order.psm1" -ErrorAction Stop
    Import-Module -Name "$petStorePath/UserData.psm1" -ErrorAction Stop
}
catch { throw }

# Start Pode server with specified script block
Start-PodeServer -Threads 1 -ScriptBlock {
    # Define paths for data, images, and certificates
    $script:PetDataPath = Join-Path -Path $PetStorePath -ChildPath 'data'
    If (!(Test-Path -PathType container -Path $script:PetDataPath)) {
        New-Item -ItemType Directory -Path $script:PetDataPath -Force | Out-Null
    }

    $script:PetImagesPath = Join-Path -Path $PetStorePath -ChildPath 'images'
    If (!(Test-Path -PathType container -Path $script:PetImagesPath)) {
        New-Item -ItemType Directory -Path $script:PetImagesPath -Force | Out-Null
    }

    $script:CertsPath = Join-Path -Path $PetStorePath -ChildPath 'certs'
    If (!(Test-Path -PathType container -Path $script:CertsPath)) {
        New-Item -ItemType Directory -Path $script:CertsPath -Force | Out-Null
    }

    # Load data from JSON file or initialize data if Reset switch is present

    $script:PetDataJson = Join-Path -Path $PetDataPath -ChildPath 'PetData.json'
    if ($Reset.IsPresent -or !(Test-Path -Path $script:PetDataJson -PathType Leaf )) {
        Initialize-Categories -Reset
        Initialize-Pet -Reset
        Initialize-Order -Reset
        Initialize-Users -Reset
        Save-PodeState -Path $script:PetDataJson
    }
    else {
        Initialize-Categories
        Initialize-Pet
        Initialize-Order
        Initialize-Users
		# attempt to re-initialise the state (will do nothing if the file doesn't exist)
        Restore-PodeState -Path $script:PetDataJson
    }

    # Configure Pode server endpoints
    if ((Get-PodeConfig).Protocol -eq 'Https') {
        $Certificate = Join-Path -Path $CertsPath -ChildPath (Get-PodeConfig).Certificate
        $CertificateKey = Join-Path -Path $CertsPath -ChildPath (Get-PodeConfig).CertificateKey
        Add-PodeEndpoint -Address (Get-PodeConfig).Address -Port (Get-PodeConfig).RestFulPort -Protocol Https -Certificate $Certificate -CertificateKey $CertificateKey -CertificatePassword (Get-PodeConfig).CertificatePassword -Default
    }
    else {
        Add-PodeEndpoint -Address (Get-PodeConfig).Address -Port (Get-PodeConfig).RestFulPort -Protocol Http -Default
    }

    # Enable error logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # Configure CORS
    Set-PodeSecurityAccessControl -Origin '*' -Duration 7200 -WithOptions -AuthorizationHeader -autoMethods -AutoHeader -Credentials -CrossDomainXhrRequests

    # Add static route for images

    Add-PodeStaticRoute -Path '/images' -Source $script:PetImagesPath

    # Enable OpenAPI documentation

    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3' -EnableSchemaValidation -DisableMinimalDefinitions -NoDefaultResponses

    # Add external documentation link for Swagger
    $swaggerDocs = New-PodeOAExternalDoc -Description 'Find out more about Swagger' -Url 'http://swagger.io'
    $swaggerDocs | Add-PodeOAExternalDoc

    # Add OpenAPI information
    $InfoDescription = @'
This is a sample Pet Store Server based on the OpenAPI 3.0 specification. You can find out more about Swagger at [http://swagger.io](http://swagger.io).
In the third iteration of the pet store, we've switched to the design first approach!
You can now help us improve the API whether it's by making changes to the definition itself or to the code.
That way, with time, we can improve the API in general, and expose some of the new features in OAS3.

Some useful links:
- [The Pet Store repository](https://github.com/swagger-api/swagger-petstore)
- [The source API definition for the Pet Store](https://github.com/swagger-api/swagger-petstore/blob/master/src/main/resources/openapi.yaml)
'@


    Add-PodeOAInfo -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription -TermsOfService 'http://swagger.io/terms/' -LicenseName 'Apache 2.0' `
        -LicenseUrl 'http://www.apache.org/licenses/LICENSE-2.0.html' -ContactName 'API Support' -ContactEmail 'apiteam@swagger.io'
    Add-PodeOAServerEndpoint -url '/api/v3' -Description 'default endpoint'

    # Enable OpenAPI viewers
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode

    # Enable OpenAPI editor and bookmarks
    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'

    # Setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # Define access schemes and authentication
    New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'read:pets' -Description 'read your pets'
    New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'write:pets' -Description 'modify pets in your account'
    $clientId = '123123123'
    $clientSecret = '<mysecret>'

    # OAuth2 authentication
    New-PodeAuthScheme -OAuth2 -ClientId $ClientId -ClientSecret $ClientSecret `
        -AuthoriseUrl 'https://petstore3.swagger.io/oauth/authorize' `
        -TokenUrl 'https://petstore3.swagger.io/oauth/token' `
        -Scope 'read:pets', 'write:pets' |
        Add-PodeAuth -Name 'petstore_auth' -FailureUrl 'https://petstore3.swagger.io/oauth/failure' -SuccessUrl '/' -ScriptBlock {
            param($user, $accessToken, $refreshToken)
            return @{ User = $user }
        }

    # API key authentication
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

    # Basic authentication
    New-PodeAuthScheme -Basic -Realm 'PetStore' | Add-PodeAuth -Name 'Basic' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID       = 'M0R7Y302'
                    Name     = 'Morty'
                    Type     = 'Human'
                    Username = 'm.orty'
                    Scopes   = @( 'read:pets' , 'write:pets' )
                }
            }
        }
        return @{ Message = 'Invalid details supplied' }
    }

    # Merge authentication schemes
    Merge-PodeAuth -Name 'merged_auth' -Authentication 'Basic', 'api_key' -Valid One
    Merge-PodeAuth -Name 'merged_auth_All' -Authentication 'Basic', 'api_key' -Valid All -ScriptBlock {}
    Merge-PodeAuth -Name 'merged_auth_nokey' -Authentication 'Basic' -Valid One

    # Add OpenAPI tags
    Add-PodeOATag -Name 'user' -Description 'Operations about user'
    Add-PodeOATag -Name 'store' -Description 'Access to Petstore orders' -ExternalDoc $swaggerDocs
    Add-PodeOATag -Name 'pet' -Description 'Everything about your Pets' -ExternalDoc $swaggerDocs

    # Define OpenAPI component schemas
    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -Required |
        New-PodeOAIntProperty -Name 'petId' -Format Int64 -Example 198772 -Required |
        New-PodeOAIntProperty -Name 'quantity' -Format Int32 -Example 7 -Required |
        New-PodeOAStringProperty -Name 'shipDate' -Format Date-Time |
        New-PodeOAStringProperty -Name 'status' -Description 'Order Status' -Required -Example 'approved' -Enum @('placed', 'approved', 'delivered') |
        New-PodeOABoolProperty -Name 'complete' |
        New-PodeOAObjectProperty -XmlName 'order' |
        Add-PodeOAComponentSchema -Name 'Order'

    New-PodeOAStringProperty -Name 'street' -Example '437 Lytton' -Required |
        New-PodeOAStringProperty -Name 'city' -Example 'Palo Alto' -Required |
        New-PodeOAStringProperty -Name 'state' -Example 'CA' -Required |
        New-PodeOAStringProperty -Name 'zip' -Example '94031' -Required |
        New-PodeOAObjectProperty -XmlName 'address' |
        Add-PodeOAComponentSchema -Name 'Address'

    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 100000 |
        New-PodeOAStringProperty -Name 'username' -example 'fehguy' |
        New-PodeOASchemaProperty -Name 'Address' -Reference 'Address' -Array -XmlName 'addresses' -XmlWrapped |
        New-PodeOAObjectProperty -XmlName 'customer' |
        Add-PodeOAComponentSchema -Name 'Customer'


    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1 |
        New-PodeOAStringProperty -Name 'name' -Example 'Dogs' |
        New-PodeOAObjectProperty -XmlName 'category' |
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

    New-PodeOAIntProperty -Name 'id'-Format Int64 -Example  10 -Required |
        New-PodeOAStringProperty -Name 'name' -Example 'doggie' -Required |
        New-PodeOASchemaProperty -Name 'category' -Reference 'Category' |
        New-PodeOAStringProperty -Name 'photoUrls' -Array  -XmlWrapped -XmlItemName 'photoUrl' -Required |
        New-PodeOASchemaProperty -Name 'tags' -Reference 'Tag' -Array -XmlWrapped |
        New-PodeOAStringProperty -Name 'status' -Description 'pet status in the store' -Enum @('available', 'pending', 'sold') |
        New-PodeOAObjectProperty -XmlName 'pet' |
        Add-PodeOAComponentSchema -Name 'Pet'

    New-PodeOAIntProperty -Name 'code'-Format Int32 |
        New-PodeOAStringProperty -Name 'type' |
        New-PodeOAStringProperty -Name 'message' |
        New-PodeOAObjectProperty -XmlName '##default' |
        Add-PodeOAComponentSchema -Name 'ApiResponse'

    # Add OpenAPI component request bodies
    Add-PodeOAComponentRequestBody -Name 'Pet' -Description 'Pet object that needs to be added to the store' -Content (
        New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet')

    Add-PodeOAComponentRequestBody -Name 'UserArray' -Description 'List of user object' -Content (
        New-PodeOAContentMediaType -ContentType 'application/json' -Content 'User' -Array)



    # Define API routes
    Add-PodeRouteGroup -Path '/api/v3'   -Routes {
        <#
            PUT '/pet'
        #>
        Add-PodeRoute -PassThru -Method Put -Path '/pet' -Authentication 'merged_auth_nokey' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $contentType = Get-PodeHeader -Name 'Content-Type'
            switch ($contentType) {
                'application/xml' {
                    $pet = ConvertFrom-PodeXml -node $WebEvent.data | ConvertTo-Json
                }
                'application/json' { $pet = ConvertTo-Json $WebEvent.data }
                default {
                    Write-PodeHtmlResponse -StatusCode 415
                    return
                }
            }
            if ($pet -and $WebEvent.data.id) {
                if ($contentType -eq 'application/json') {
                    $Validate = Test-PodeOAJsonSchemaCompliance -Json $pet -SchemaReference 'Pet'
                }
                else {
                    $Validate = @{'result' = $true }
                }
                if ($Validate.result) {
                    if (Update-Pet -Pet (convertfrom-json -InputObject $pet -AsHashtable)) {
                        Save-PodeState -Path $using:PetDataJson
                    }
                    else {
                        Write-PodeHtmlResponse -StatusCode 404 -Value  'Pet not found'
                    }
                }
                else {
                    Write-PodeHtmlResponse -StatusCode 405 -Value  ($Validate.message -join ', ')
                }
            }
            else {
                Write-PodeHtmlResponse -StatusCode 400 -Value 'Invalid ID supplied'
            }
        } | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru |
            Set-PodeOARequest -RequestBody (
                New-PodeOARequestBody -Description  'Update an existent pet in the store' -Required -Content (
                    New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet'  )
            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception'


        <#
            POST '/pet'
        #>
        Add-PodeRoute -PassThru -Method Post -Path '/pet'  -Authentication 'merged_auth_nokey' -Scope 'write:pets', 'read:pets'  -ScriptBlock {
            $contentType = Get-PodeHeader -Name 'Content-Type'
            switch ($contentType) {
                'application/xml' {
                    $pet = ConvertFrom-PodeXml -node $WebEvent.data | ConvertTo-Json
                }
                'application/json' { $pet = ConvertTo-Json $WebEvent.data }
                default {
                    Write-PodeHtmlResponse -StatusCode 415
                    return
                }
            }
            if ($contentType -eq 'application/json') {
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $pet -SchemaReference 'Pet'
            }
            else {
                $Validate = @{'result' = $true }
            }
            if ($Validate.result) {
                Add-Pet -Pet (convertfrom-json -InputObject $pet -AsHashtable)
                Save-PodeState -Path $using:PetDataJson
            }
            else {
                Write-PodeHtmlResponse -StatusCode 405 -Value  ($Validate.message -join ', ')
            }
        } | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' -Tags 'pet' -OperationId 'addPet' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Description 'Create a new pet in the store' -Required  -Content (
                    New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet'  )
            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet' ) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description  'Invalid input'


        <#
            GET '/pet/findByStatus'
        #>
        Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -Authentication 'merged_auth_nokey' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $status = $WebEvent.Query['status']
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            if ($status) {
                $pets = Find-PetByStatus -Status $status
                if ($null -eq $pets) {
                    $pets = @()
                }
                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $pets -StatusCode 200 }
                    'application/json' { Write-PodeJsonResponse -Value $pets -StatusCode 200 }
                    default { Write-PodeHtmlResponse -StatusCode 415 }
                }
            }
            else {
                Write-PodeHtmlResponse -Value 'Invalid status value' -StatusCode 400
            }

        } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') |
                    ConvertTo-PodeOAParameter -In Query -Explode ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet' -Array) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value' -PassThru |
                Add-PodeOAResponse -StatusCode 415

        <#
            GET '/pet/findByTags'
        #>
        Add-PodeRoute -PassThru -Method get -Path '/pet/findByTags' -Authentication 'merged_auth_nokey' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $tags = $WebEvent.Query['tags']
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            if ($tags) {
                $pets = Find-PetByTags -Tags $tags
                if ($null -eq $pets) {
                    $pets = @()
                }
                switch ($responseMediaType) {
                    'application/xml' { Write-PodeXmlResponse -Value $pets -StatusCode 200 }
                    'application/json' { Write-PodeJsonResponse -Value $pets -StatusCode 200 }
                    default { Write-PodeHtmlResponse -StatusCode 415 }
                }
            }
            else {
                Write-PodeHtmlResponse -Value 'Invalid tag value' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Finds Pets by tags' -Description 'Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.' -Tags 'pet' -OperationId 'findPetsByTags' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAStringProperty -Name 'tags' -Description 'Tags to filter by' -Array |
                    ConvertTo-PodeOAParameter -In Query -Explode ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'  -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet' -Array) -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid tag value' -PassThru |
                Add-PodeOAResponse -StatusCode 415



        <#
            GET '/pet/{petId}'
        #>
        Add-PodeRoute -PassThru -Method Get -Path '/pet/:petId' -Authentication 'merged_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $petId = $WebEvent.Parameters['petId']
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            if ($petId) {
                $pet = Get-Pet -Id $petId
                if ($pet) {
                    switch ($responseMediaType) {
                        'application/xml' { Write-PodeXmlResponse -Value $pet -StatusCode 200 }
                        'application/json' { Write-PodeJsonResponse -Value $pet -StatusCode 200 }
                        default { Write-PodeHtmlResponse -StatusCode 415 }
                    }
                }
                else {
                    Write-PodeHtmlResponse -Value 'Pet not found' -StatusCode 404
                }
            }
            else {
                Write-PodeJsonResponse -Value 'Invalid ID supplied' -StatusCode 400
            }

        } | Set-PodeOARouteInfo -Summary 'Find pet by ID' -Description 'Returns a single pet.' -Tags 'pet' -OperationId 'getPetById' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAIntProperty -Name 'petId' -Description 'ID of pet to return'  -Format Int64 |
                    ConvertTo-PodeOAParameter -In Path -Required ) |
                Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'Pet') -PassThru |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
                Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
                Add-PodeOAResponse -StatusCode 415


        <#
            POST '/pet/{petId}'
        #>

        Add-PodeRoute -PassThru -Method post -Path '/pet/:petId' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $petId = $WebEvent.Parameters['petId']
            $name = $WebEvent.Query['name']
            $status = $WebEvent.Query['status']

            if ($petId -and (Test-Pet -Id $petId)) {
                if (Update-Pet -Id $petId -Name $name -Status $status) {
                    Save-PodeState -Path $using:PetDataJson
                }
                else {
                    Write-PodeHtmlResponse -StatusCode 405 -Value 'Invalid Input'
                }
            }
            else {
                Write-PodeHtmlResponse -StatusCode 405 -Value 'Invalid Input'
            }
        } | Set-PodeOARouteInfo -Summary 'Updates pet with ID' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePetWithForm' -PassThru |
            Set-PodeOARequest -PassThru -Parameters  ( New-PodeOAIntProperty -Name 'petId' -Description 'ID of pet that needs to be updated'  -Format Int64 |
                    ConvertTo-PodeOAParameter -In Path -Required ),
                                    (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                                    (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) |
                Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

        <#
            DELETE '/pet/{petId}'
        #>
        Add-PodeRoute -PassThru -Method Delete -Path '/pet/:petId' -Authentication 'merged_auth_All' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $petId = $WebEvent.Parameters['petId']
            if ($petId -and (Test-Pet -Id $petId)) {
                Remove-Pet -Id $petId
                Save-PodeState -Path $using:PetDataJson
            }
            else {
                Write-PodeHtmlResponse -Value 'Invalid pet value' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Deletes pet by ID' -Description 'Deletes a pet.' -Tags 'pet' -OperationId 'deletePet' -PassThru |
            Set-PodeOARequest -PassThru -Parameters (
                New-PodeOAIntProperty -Name 'petId' -Description 'ID of pet that needs to be updated'  -Format Int64 |
                    ConvertTo-PodeOAParameter -In Path -Required ) |
                Add-PodeOAResponse -StatusCode 400 -Description 'Invalid pet value'



        #TO DO
        <#
            POST '/pet/{petId}/uploadImage'
        #>
        Add-PodeRoute -PassThru -Method post -Path '/pet/:petId/uploadImage' -Authentication 'petstore_auth' -Scope 'write:pets', 'read:pets' -ScriptBlock {
            $petId = $WebEvent.Parameters['petId']
            $additionalMetadata = $WebEvent.Query['additionalMetadata']
            if ($petId -and (Test-Pet -Id $petId)) {
                $pet = Get-Pet -Id $petId
                $image = "$petId-$(New-Guid).$additionalMetadata"
                $outputFilePath = Join-Path -Path $using:PetImagesPath  -AdditionalChildPath $image
                [System.IO.File]::WriteAllBytes($outputFilePath, $WebEvent.data)
                $url = "$((Get-PodeConfig).Protocol)://$((Get-PodeConfig).Address):$((Get-PodeConfig).RestFulPort)/images/$image"
                $pet.photoUrls.add($url)
                Save-PodeState -Path $using:PetDataJson
            }
            else {
                Write-PodeHtmlResponse -Value 'Invalid pet value' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Uploads an image' -Tags 'pet' -OperationId 'uploadFile' -PassThru |
            Set-PodeOARequest -Parameters @(
                                            (  New-PodeOAIntProperty -Name 'petId' -Format Int64 -Description 'ID of pet to update' -Required | ConvertTo-PodeOAParameter -In Path ),
                                            (  New-PodeOAStringProperty -Name 'additionalMetadata' -Description 'Additional Metadata' | ConvertTo-PodeOAParameter -In Query )
            ) -RequestBody (
                New-PodeOARequestBody  -Content  ( New-PodeOAContentMediaType -ContentType 'application/octet-stream' -Upload )
            ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{'application/json' = 'ApiResponse' }



        <#
            GET '/store/inventory'
        #>
        Add-PodeRoute -PassThru -Method Get -Path '/store/inventory' -Authentication 'api_key' -ScriptBlock {
            $result = Get-CountByStatus
            Write-PodeJsonResponse -Value $result -StatusCode 200

        } | Set-PodeOARouteInfo -Summary 'Returns pet inventories by status' -Description 'Returns a map of status codes to quantities' -Tags 'store' -OperationId 'getInventory' -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{  'application/json' = New-PodeOAObjectProperty -AdditionalProperties (New-PodeOAIntProperty -Format Int32  ) }


        <#
            POST '/store/order'
        #>
        Add-PodeRoute -PassThru -Method post -Path '/store/order' -ScriptBlock {
            $contentType = Get-PodeHeader -Name 'Content-Type'
            switch ($contentType) {
                'application/xml' {
                    $order = ConvertFrom-PodeXml -node $WebEvent.data | ConvertTo-Json
                }
                'application/json' { $order = ConvertTo-Json $WebEvent.data }
                'application/x-www-form-urlencoded' { $order = ConvertTo-Json $WebEvent.data }
                default {
                    Write-PodeHtmlResponse -StatusCode 415
                    return
                }
            }
            if ($contentType -eq 'application/json') {
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $order -SchemaReference 'Order'
            }
            else {
                #no test schema support for XML
                $Validate = @{'result' = $true }
            }
            if ($Validate.result) {
                Add-Order -Order (convertfrom-json -InputObject $order -AsHashtable)
                Save-PodeState -Path $using:PetDataJson
            }
            else {
                Write-PodeHtmlResponse -StatusCode 405 -Value  ($Validate.message -join ', ')
            }
        } | Set-PodeOARouteInfo -Summary 'Place an order for a pet' -Description 'Place a new order in the store' -Tags 'store' -OperationId 'placeOrder' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'Order'  )) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (@{ 'application/json' = 'Order' }) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'

        <#
            GET '/store/order/{orderId}'
        #>
        Add-PodeRoute -PassThru -Method Get -Path '/store/order/:orderId' -ScriptBlock {
            $orderId = $WebEvent.Parameters['orderId']
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            if ($orderId) {
                $order = Get-Order -Id $orderId
                if ($order) {
                    switch ($responseMediaType) {
                        'application/xml' { Write-PodeXmlResponse -Value $order -StatusCode 200 }
                        'application/json' { Write-PodeJsonResponse -Value $order -StatusCode 200 }
                        default { Write-PodeHtmlResponse -StatusCode 415 }
                    }
                }
                else {
                    Write-PodeHtmlResponse -Value 'Order not found' -StatusCode 404
                }
            }
            else {
                Write-PodeHtmlResponse -Value 'No orderId provided. Try again?' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Find purchase order by ID' -Description 'For valid response try integer IDs with value <= 5 or > 10. Other values will generate exceptions.' -Tags 'store' -OperationId 'getOrderById' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                                (  New-PodeOAIntProperty -Name 'orderId' -Format Int64 -Description 'ID of order that needs to be fetched' -Required | ConvertTo-PodeOAParameter -In Path )
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml'  -Content 'Order'  ) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'Order not found'

        <#
            DELETE '/store/order/{orderId}'
        #>
        Add-PodeRoute -PassThru -Method Delete -Path '/store/order/:orderId' -ScriptBlock {
            $orderId = $WebEvent.Parameters['orderId']
            if ($orderId ) {
                if ( Test-Order -Id $orderId) {
                    Remove-Order -Id $orderId
                    Save-PodeState -Path $using:PetDataJson
                }
                else {
                    Write-PodeHtmlResponse -Value 'Order not found' -StatusCode 404
                }
            }
            else {
                Write-PodeJsonReWrite-PodeHtmlResponsesponse -Value 'Invalid ID supplied' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Delete purchase order by ID' -Description 'For valid response try integer IDs with value < 1000. Anything above 1000 or nonintegers will generate API errors.' -Tags 'store' -OperationId 'deleteOrder' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                                    (  New-PodeOAIntProperty -Name 'orderId' -Format Int64 -Description ' ID of the order that needs to be deleted' -Required | ConvertTo-PodeOAParameter -In Path )
            ) |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'Order not found'



        <#
            POST '/user'
        #>

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
            if ($contentType -eq 'application/json') {
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $user -SchemaReference 'User'
            }
            else {
                #no test schema support for XML
                $Validate = @{'result' = $true }
            }
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
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User' )) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input' -PassThru |
            Add-PodeOAResponse -Default -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml'  -Content 'User' )


        <#
            POST '/user/createWithList'
        #>
        Add-PodeRoute -PassThru -Method post -Path '/user/createWithList' -ScriptBlock {
            $contentType = Get-PodeHeader -Name 'Content-Type'
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            $newUsers = @()
            foreach ($user in $WebEvent.data) {
                switch ($contentType) {
                    'application/json' { $userJson = ConvertTo-Json $user }
                    default {
                        Write-PodeHtmlResponse -StatusCode 415
                        return
                    }
                }
                if ($contentType -eq 'application/json') {
                    $Validate = Test-PodeOAJsonSchemaCompliance -Json $userJson -SchemaReference 'User'
                }
                else {
                    #no test schema support for XML
                    $Validate = @{'result' = $true }
                }
                if ($Validate.result) {
                    $newUsers += $user
                }
                else {
                    Write-PodeHtmlResponse -StatusCode 405 -Value  ($Validate.message -join ', ')
                    return
                }
            }
            $createdUsers = @()
            foreach ($u in $newUsers) {
                $createdUsers += Add-User -User $u
            }
            Save-PodeState -Path $using:PetDataJson
            switch ($responseMediaType) {
                'application/xml' { Write-PodeXmlResponse -Value $createdUsers -StatusCode 200 }
                'application/json' { Write-PodeJsonResponse -Value $createdUsers -StatusCode 200 }
                default { Write-PodeHtmlResponse -StatusCode 415 }
            }
        } | Set-PodeOARouteInfo -Summary 'Creates list of users with given input array.' -Description 'Creates list of users with given input array.' -Tags 'user' -OperationId 'createUsersWithListInput' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Content (New-PodeOAContentMediaType -ContentType 'application/json' -Content 'User'  -Array)) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml'  -Content 'User' -Array  ) -PassThru |
            Add-PodeOAResponse -Default -Description 'successful operation'


        <#
            GET '/user/login'
        #>
        Add-PodeRoute -PassThru -Method Get -Path '/user/login' -ScriptBlock {
            $username = $WebEvent.Query['username']
            $password = $WebEvent.Query['password']
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            if ($username) {
                $user = Get-User -Username $username
                if ($user -and $user['password'] -eq $password) {
                    Set-PodeHeader -Name 'X-Expires-After' -Value ((Get-Date).AddHours(1).ToString('yyyy-MM-ddTHH:mm:ssK'))
                    Set-PodeHeader -Name 'X-Rate-Limit' -Value '5000'
                    $result = @{'api_key' = 'test-key' }
                    switch ($responseMediaType) {
                        'application/xml' { Write-PodeXmlResponse -Value $result -StatusCode 200 }
                        'application/json' { Write-PodeJsonResponse -Value $result -StatusCode 200 }
                        default { Write-PodeHtmlResponse -StatusCode 415 }
                    }
                }
                else {
                    Write-PodeHtmlResponse -Value 'Invalid username/password supplied' -StatusCode 400
                }
            }
            else {
                Write-PodeHtmlResponse -Value 'Invalid username/password supplied' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Logs user into the system.'  -Tags 'user' -OperationId 'loginUser' -PassThru |
            Set-PodeOARequest  -Parameters  (  New-PodeOAStringProperty -Name 'username' -Description 'The user name for login' | ConvertTo-PodeOAParameter -In Query ),
                                (  New-PodeOAStringProperty -Name 'password' -Description 'The password for login in clear text' -Format Password | ConvertTo-PodeOAParameter -In Query ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'string' ) `
                -Headers (New-PodeOAIntProperty  -Name 'X-Rate-Limit' -Description 'calls per hour allowed by the user' -Format Int32),
                (New-PodeOAStringProperty -Name 'X-Expires-After' -Description 'date in UTC when token expires' -Format Date-Time) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username/password supplied'

        <#
            GET '/user/logout'
        #>
        Add-PodeRoute -PassThru -Method Get -Path '/user/logout' -ScriptBlock {
            Write-PodeJsonResponse -Value 'Successful operation' -StatusCode 200
        } | Set-PodeOARouteInfo -Summary 'Logs out current logged in user session.'  -Tags 'user' -OperationId 'logoutUser' -PassThru |
            Add-PodeOAResponse -Default -Description 'Successful operation'


        <#
            GET '/user/{username}'
        #>
        Add-PodeRoute -PassThru -Method Get -Path '/user/:username' -ScriptBlock {
            $username = $WebEvent.Parameters['username']
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            if ($username) {
                $user = Get-User -Username $username
                if ($user) {
                    switch ($responseMediaType) {
                        'application/xml' { Write-PodeXmlResponse -Value $user -StatusCode 200 }
                        'application/json' { Write-PodeJsonResponse -Value $user -StatusCode 200 }
                        default { Write-PodeHtmlResponse -StatusCode 415 }
                    }
                }
                else {
                    Write-PodeHtmlResponse -Value 'User not found' -StatusCode 404
                }
            }
            else {
                Write-PodeHtmlResponse -Value 'Invalid username supplied' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Get user by user name'   -Tags 'user' -OperationId 'getUserByName' -PassThru |
            Set-PodeOARequest -Parameters (  New-PodeOAStringProperty -Name 'username' -Description 'The name that needs to be fetched. Use user1 for testing.' -Required | ConvertTo-PodeOAParameter -In Path ) -PassThru |
            Add-PodeOAResponse -StatusCode 200 -Content (New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml' -Content 'User' ) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'User not found'

        <#
            PUT '/user/{username}'
        #>
        Add-PodeRoute -PassThru -Method Put -Path '/user/:username' -ScriptBlock {
            $contentType = Get-PodeHeader -Name 'Content-Type'
            $username = $WebEvent.Parameters['username']
            $responseMediaType = Get-PodeHeader -Name 'Accept'
            if (Test-User -Username $username) {
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
                if ($contentType -eq 'application/json') {
                    $Validate = Test-PodeOAJsonSchemaCompliance -Json $user -SchemaReference 'User'
                }
                else {
                    #no test schema support for XML
                    $Validate = @{'result' = $true }
                }
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
            }
            else {
                Write-PodeHtmlResponse -StatusCode 404 -Value   'User not found'
            }
        } | Set-PodeOARouteInfo -Summary 'Update user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'updateUser' -PassThru |
            Set-PodeOARequest -Parameters (  New-PodeOAStringProperty -Name 'username' -Description ' name that need to be updated.' -Required | ConvertTo-PodeOAParameter -In Path ) `
                -RequestBody ( New-PodeOARequestBody -Required -Description 'Update an existent user in the store' -Content (
                    New-PodeOAContentMediaType -ContentType 'application/json', 'application/xml', 'application/x-www-form-urlencoded' -Content 'User'
                )) -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'User not found' -PassThru |
            Add-PodeOAResponse -Default -Description 'successful operation'

        <#
            DELETE '/user/{username}'
        #>
        Add-PodeRoute -PassThru -Method Delete -Path '/user/:username' -ScriptBlock {
            $username = $WebEvent.Parameters['username']
            if ($username ) {
                if ( Test-User -Username $username) {
                    Remove-User -Username $orderId
                    Save-PodeState -Path $using:PetDataJson
                }
                else {
                    Write-PodeHtmlResponse -Value 'User not found' -StatusCode 404
                }
            }
            else {
                Write-PodeJsonReWrite-PodeHtmlResponsesponse -Value 'Invalid username supplied' -StatusCode 400
            }
        } | Set-PodeOARouteInfo -Summary 'Delete user' -Description 'This can only be done by the logged in user.' -Tags 'user' -OperationId 'deleteUser' -PassThru |
            Set-PodeOARequest -Parameters   (  New-PodeOAStringProperty -Name 'username' -Description 'The name that needs to be deleted.' -Required | ConvertTo-PodeOAParameter -In Path ) -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid username supplied' -PassThru |
            Add-PodeOAResponse -StatusCode 404 -Description 'User not found'
    }
}