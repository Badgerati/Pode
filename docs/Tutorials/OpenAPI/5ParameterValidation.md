
## Parameter Validation

Is possible to validate any parameter submitted by clients against an OpenAPI schema, ensuring adherence to defined standards.


First, schema validation has to be enabled using :

```powershell
Enable-PodeOpenApi -EnableSchemaValidation #any other parameters needed
```

This command activates the OpenAPI feature with schema validation enabled, ensuring strict adherence to specified schemas.

Next, is possible to validate any route using `Test-PodeOAJsonSchemaCompliance`.
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
        'application/x-www-form-urlencoded' { $user = ConvertTo- Json $WebEvent.data }
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
