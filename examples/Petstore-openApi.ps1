$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop


function test
{
    param (
        [Switch]$test
    )
    
    if ($test.IsPresent)
    {
        Write-Host 'is a test'
    }
}

Start-PodeServer -Threads 2 -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http  
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

    $ExtraInfo = @{  
        'termsOfService' = 'http://swagger.io/terms/'

        'contact'        = @{
            'name'  = 'API Support'
            'email' = 'apiteam@swagger.io'
            'url'   = 'http://example.com/support'
        }
        'license'        = @{
            'name' = 'Apache 2.0'
            'url'  = 'http://www.apache.org/licenses/LICENSE-2.0.html'
        }
    }
    $ExternalDocs = @{
            'description' = 'Find out more about Swagger'
            'url'         = 'http://swagger.io'
        }  

    Enable-PodeOpenApi -Path '/docs/openapi' -Title 'Swagger Petstore - OpenAPI 3.0' -Version 1.0.17 -Description $InfoDescription -RestrictRoutes -RouteFilter '/api/v3/*' -ExtraInfo $ExtraInfo -ExternalDocs $ExternalDocs
    Enable-PodeOpenApiViewer -Type Swagger -Path '/docs/swagger'  
    # or ReDoc at the default "/redoc"
    Enable-PodeOpenApiViewer -Type ReDoc  


    Add-PodeOAComponentSchema -Name 'Order' -Schema (
        New-PodeOAObjectProperty -Name 'Order' -Xml @{'name' = 'order' } -Properties @(
            (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10),
            (New-PodeOAIntProperty -Name 'petId' -Format Int64 -Example 198772),  
            (New-PodeOAIntProperty -Name 'quantity' -Format Int32 -Example 7),  
            (New-PodeOAStringProperty -Name 'shipDate' -Format Date-Time ),
            (New-PodeOAStringProperty -Name 'status' -description 'Order Status' -example 'approved' -Enum @('placed', 'approved', 'delivered')),
            (New-PodeOABoolProperty -Name 'complete') 
        ))  

    Add-PodeOAComponentSchema -Name 'Address' -Schema (
        New-PodeOAObjectProperty -Name 'Address' -Xml @{'name' = 'address' } -Properties @(
                (New-PodeOAStringProperty -Name 'street' -Example '437 Lytton'),
                (New-PodeOAStringProperty -Name 'city' -Example 'Palo Alto'),  
                (New-PodeOAStringProperty -Name 'state' -Example 'CA'),  
                (New-PodeOAStringProperty -Name 'zip' -Example '94031') 
        ))

    Add-PodeOAComponentSchema -Name 'Category' -Schema (
        New-PodeOAObjectProperty -Name 'Category' -Xml @{'name' = 'category' } -Properties @(
                (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1),
                    (New-PodeOAStringProperty -Name 'name' -Example 'Dogs') 
        ))
    
    <# 
        User:
            type: object
            properties:
            id:
                type: integer
                format: int64
                example: 10
            username:
                type: string
                example: theUser
            firstName:
                type: string
                example: John
            lastName:
                type: string
                example: James
            email:
                type: string
                example: john@email.com
            password:
                type: string
                example: '12345'
            phone:
                type: string
                example: '12345'
            userStatus:
                type: integer
                description: User Status
                format: int32
                example: 1
            xml:
            name: user
    #>
    Add-PodeOAComponentSchema -Name 'User' -Schema (
        New-PodeOAObjectProperty -Name 'User' -Xml @{'name' = 'user' } -Properties @(
                    (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 1),
                        (New-PodeOAStringProperty -Name 'username' -Example 'theUser'),
                        (New-PodeOAStringProperty -Name 'firstName' -Example 'John'),
                        (New-PodeOAStringProperty -Name 'lastName' -Example 'James'),
                        (New-PodeOAStringProperty -Name 'email' -format email -Example 'john@email.com'),
                        (New-PodeOAStringProperty -Name 'lastName' -Example 'James'),
                        (New-PodeOAStringProperty -Name 'password' -format Password -Example '12345'),
                        (New-PodeOAStringProperty -Name 'phone' -Example '12345'), 
                        (New-PodeOAIntProperty -Name 'userStatus'-Format int32 -description 'User Status' -Example 1)
        )) 

    <# 
        Tag:
            type: object
            properties:
            id:
                type: integer
                format: int64
            name:
                type: string
            xml:
            name: tag
    #>
    Add-PodeOAComponentSchema -Name 'Tag' -Schema (
        New-PodeOAObjectProperty -Name 'Tag' -Xml @{'name' = 'tag' } -Properties @(
                        (New-PodeOAIntProperty -Name 'id'-Format Int64  ),
                            (New-PodeOAStringProperty -Name 'name' ) 
        ))

    <#
        Pet:
        required:
            - name
            - photoUrls
        type: object
        properties:
            id:
                type: integer
                format: int64
                example: 10
            name:
                type: string
                example: doggie
            category:
                $ref: '#/components/schemas/Category'
            photoUrls:
                type: array
                xml:
                    wrapped: true
                items:
                    type: string
                    xml:
                    name: photoUrl
            tags:
                type: array
            xml:
                wrapped: true
            items:
                $ref: '#/components/schemas/Tag'
            status:
                type: string
                description: pet status in the store
                enum:
                    - available
                    - pending
                    - sold
        xml:
            name: pet
    #>
    Add-PodeOAComponentSchema -Name 'Pet' -Schema (
        New-PodeOAObjectProperty -Name 'Pet' -Xml @{'name' = 'pet' } -Properties @(
                    (New-PodeOAIntProperty -Name 'id'-Format Int64 -Example 10 -ReadOnly),
                        (New-PodeOAStringProperty -Name 'name' -Example 'doggie'),
                        (New-PodeOASchemaProperty -Name 'category' -Reference 'Category') 
                        (New-PodeOAStringProperty -Name 'photoUrls' -Array),
                        (New-PodeOASchemaProperty -Name 'tags' -Reference 'Tag') 
                        (New-PodeOAStringProperty -Name 'status' -description 'pet status in the store' -Enum @('available', 'pending', 'sold')) 
        )) 
    
    
    <#
        ApiResponse:
            type: object
            properties:
            code:
                type: integer
                format: int32
            type:
                type: string
            message:
                type: string
            xml:
                name: '##default' 
    #>
    Add-PodeOAComponentSchema -Name 'ApiResponse' -Schema (
        New-PodeOAObjectProperty -Name 'ApiResponse' -Xml @{'name' = '##default' } -Properties @(
                    (New-PodeOAIntProperty -Name 'code'-Format Int32  ),
                        (New-PodeOAStringProperty -Name 'type' -Example 'doggie'),  
                        (New-PodeOAStringProperty -Name 'message' ) )) 


    # setup apikey authentication to validate a user
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'Authenticate' -Sessionless -ScriptBlock {
        param($key)
        if ($key)
        {
            # here you'd check a real storage, this is just for example
            if ($key -eq 'test-key')
            {
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
        else
        { 
            return @{
                Message = 'No Authorization header found'
                Code    = 401
            }
            
        }
    }



    Add-PodeRouteGroup -Path '/api/v3' -Authentication 'Authenticate' -Routes {  
        #PUT
        Add-PodeRoute -PassThru -Method Put -Path '/pet' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Update an existing pet' -Description 'Update an existing pet by Id' -Tags 'pet' -OperationId 'updatePet' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -required -ContentSchemas @{   'application/x-www-form-urlencoded' = 'Pet' ; 'application/xml' = 'Pet'; 'application/json' = 'Pet' }) -PassThru | # missing -description 'Update an existent pet in the store' 
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{'application/xml' = 'Pet'; 'application/json' = 'Pet' } -PassThru |  
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru | 
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found' -PassThru |
            Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' 

        Add-PodeRoute -PassThru -Method Post -Path '/pet' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Add a new pet to the store' -Description 'Add a new pet to the store' -Tags 'pet' -OperationId 'addPet' -PassThru |
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -required -ContentSchemas @{   'application/x-www-form-urlencoded' = 'Pet' ; 'application/xml' = 'Pet'; 'application/json' = 'Pet' }) -PassThru | # missing -description 'Create a new pet in the store' 
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{'application/xml' = 'Pet'; 'application/json' = 'Pet' } -PassThru |  
            Add-PodeOAResponse -StatusCode 405 -Description 'Validation exception' 
 
        Add-PodeRoute -PassThru -Method get -Path '/pet/findByStatus' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Finds Pets by status' -Description 'Multiple status values can be provided with comma separated strings' -Tags 'pet' -OperationId 'findPetsByStatus' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                (  New-PodeOAStringProperty -Name 'status' -Description 'Status values that need to be considered for filter' -Default 'available' -Enum @('available', 'pending', 'sold') | ConvertTo-PodeOAParameter -In Query )
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{'application/xml' = 'Pet'; 'application/json' = 'Pet' } -PassThru | #missing array   application/json:
            # schema:
            #  type: array
            #  items:
            #     $ref: '#/components/schemas/Pet'
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value' 
 
        Add-PodeRoute -PassThru -Method get -Path '/pet/findByTag' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Finds Pets by tags' -Description 'Multiple tags can be provided with comma separated strings. Use tag1, tag2, tag3 for testing.' -Tags 'pet' -OperationId 'findPetsByTags' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                    (  New-PodeOAStringProperty -Name 'tag' -Description 'Tags to filter by' -Array -Explode | ConvertTo-PodeOAParameter -In Query )    
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{'application/xml' = 'Pet'; 'application/json' = 'Pet' } -PassThru | #missing array   application/json:
            # schema:
            #  type: array
            #  items:
            #     $ref: '#/components/schemas/Pet'
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid status value' 
 
        
        Add-PodeRoute -PassThru -Method Get -Path '/pet/:petId' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Find pet by ID' -Description 'Returns a single pet.' -Tags 'pet' -OperationId 'getPetById' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                        (  New-PodeOAIntProperty -Name 'petId' -format Int64 -Description 'ID of pet to return' -Required | ConvertTo-PodeOAParameter -In Path )  
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{'application/xml' = 'Pet'; 'application/json' = 'Pet' } -PassThru | 
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru | 
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found'    

        Add-PodeRoute -PassThru -Method post -Path '/pet/:petId' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Updates a pet in the store' -Description 'Updates a pet in the store with form data' -Tags 'pet' -OperationId 'updatePetWithForm' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                            (  New-PodeOAIntProperty -Name 'petId' -format Int64 -Description 'ID of pet that needs to be updated' -Required | ConvertTo-PodeOAParameter -In Path ),
                            (  New-PodeOAStringProperty -Name 'name' -Description 'Name of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query ) ,
                            (  New-PodeOAStringProperty -Name 'status' -Description 'Status of pet that needs to be updated' | ConvertTo-PodeOAParameter -In Query )    
            ) | 
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru |
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru | 
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'    
    
        
        Add-PodeRoute -PassThru -Method Delete -Path '/pet/:petId' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Deletes a pet' -Description 'Deletes a pet.' -Tags 'pet' -OperationId 'deletePet' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                            (  New-PodeOAIntProperty -Name 'petId' -format Int64 -Description 'Pet id to delete' -Required | ConvertTo-PodeOAParameter -In Path )  
            ) |
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -PassThru | 
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru | 
            Add-PodeOAResponse -StatusCode 404 -Description 'Pet not found'    

        Add-PodeRoute -PassThru -Method post -Path '/pet/:petId/uploadImage' -ScriptBlock {
            $Script = $WebEvent.data  
            Write-PodeJsonResponse -Value $script 
        } | Set-PodeOARouteInfo -Summary 'Uploads an image' -Description 'Updates a pet in the store with a new image' -Tags 'pet' -OperationId 'uploadFile' -PassThru |
            Set-PodeOARequest -PassThru -Parameters @(
                                (  New-PodeOAIntProperty -Name 'petId' -format Int64 -Description 'ID of pet that needs to be updated' -Required | ConvertTo-PodeOAParameter -In Path ),
                                (  New-PodeOAStringProperty -Name 'additionalMetadata' -Description 'Additional Metadata' | ConvertTo-PodeOAParameter -In Query ) ) |    
            Set-PodeOARequest -RequestBody (New-PodeOARequestBody -required -ContentSchemas @{   'multipart/form-data' = New-PodeOAObjectProperty -Properties @( (New-PodeOAStringProperty -Name 'image' -Format Binary  )) } ) -PassThru | #missing simple properties             
            Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -ContentSchemas @{'application/json' = 'ApiResponse' } -PassThru | 
            Add-PodeOAResponse -StatusCode 400 -Description 'Invalid ID supplied' -PassThru | 
            Add-PodeOAResponse -StatusCode 405 -Description 'Invalid Input'    


    }

    
}

 
 