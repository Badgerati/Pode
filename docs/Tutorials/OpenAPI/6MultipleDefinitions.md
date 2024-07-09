
# Multiple definitions

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

There is also [`Select-PodeOADefinition`](../../../Functions/OpenApi/Select-PodeOADefinition), which simplifies the selection of which OpenAPI definition to use as a wrapper around multiple OpenAPI functions, or Route functions. Meaning you don't have to specify `-DefinitionTag` on embedded OpenAPI/Route calls:

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
            DefaultDefinitionTag= 'NewDefault'
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
