BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}


Describe 'PrivateOpenApi' {

    BeforeEach {
        function GetPodeContext {
            return @{
                Server = @{
                    Security = @{
                        autoheaders = $false
                    }
                    Authentications=@{}
                    OpenAPI  = @{
                        SelectedDefinitionTag = 'default'
                        Definitions           = @{
                            default     = Get-PodeOABaseObject
                            alternative = Get-PodeOABaseObject
                        }
                    }
                }
            }
        }
        $global:PodeContext = GetPodeContext
    }


    Describe 'New-PodeOAPropertyInternal  Tests' {
        Context 'When valid parameters are provided' {
            It 'returns an OrderedDictionary with the correct type and properties' {
                $params = @{
                    Name        = 'TestName'
                    Description = 'Test description'
                    Type        = 'string'
                    Required    = @{
                        IsPresent = $true #emulate the [switch] type
                    }
                    Default     = 'DefaultValue'
                }
                $result = New-PodeOAPropertyInternal -Type 'string' -Params $params

                $result.type | Should -Be 'string'
                $result.name | Should -Be 'TestName'
                $result.description | Should -Be 'Test description'
                $result.required | Should -Be $true
                $result.default | Should -Be 'DefaultValue'
            }
        }

        Context 'When no type is provided in parameters' {
            It 'throws an exception' {
                { New-PodeOAPropertyInternal -Params @{} } | Should -Throw
            }
        }

        Context 'When both NoAdditionalProperties and AdditionalProperties are provided' {
            It 'throws an exception' {
                $params = @{
                    NoAdditionalProperties = @{
                        IsPresent = $true #emulate the [switch] type
                    }
                    AdditionalProperties   = @{
                        'property1' = @{ 'type' = 'string'; 'description' = 'Description for property1' }
                        'property2' = @{ 'type' = 'integer'; 'format' = 'int32' }
                    }
                }
                { New-PodeOAPropertyInternal -Type 'string' -Params $params } | Should -Throw
            }
        }
    }

    Describe 'ConvertTo-PodeOAHeaderProperties Tests' {
        It 'Converts single header with all properties' {
            $headers = @(
                @{ name = 'Content-Type'; type = 'string'; description = 'The MIME type of the body of the request' }
            )
            { ConvertTo-PodeOAHeaderProperties -Headers $headers } | Should -Not -Throw
            $result = ConvertTo-PodeOAHeaderProperties -Headers $headers
            $result['Content-Type'].schema.type | Should -Be 'string'
            $result['Content-Type'].description | Should -Be 'The MIME type of the body of the request'
        }

        It 'Converts multiple headers' {
            $headers = @(
                @{ name = 'Content-Type'; type = 'string' },
                @{ name = 'Accept'; type = 'string' }
            )
            { ConvertTo-PodeOAHeaderProperties -Headers $headers } | Should -Not -Throw
            $result = ConvertTo-PodeOAHeaderProperties -Headers $headers
            $result.Count | Should -Be 2
        }

        It 'Handles header without description' {
            $headers = @(
                @{ name = 'Authorization'; type = 'string' }
            )
            { ConvertTo-PodeOAHeaderProperties -Headers $headers } | Should -Not -Throw
            $result = ConvertTo-PodeOAHeaderProperties -Headers $headers
            $result['Authorization'].schema.type | Should -Be 'string'
            $result['Authorization'].PSObject.Properties.Name -notcontains 'description' | Should -Be $true
        }

        It 'Throws an exception for header without name' {
            $headers = @(
                @{ type = 'string'; description = 'Invalid header' }
            )
            { ConvertTo-PodeOAHeaderProperties -Headers $headers } | Should -Throw
        }

        It 'Handles additional properties in schema' {
            $headers = @(
                @{ name = 'Custom-Header'; type = 'integer'; maxLength = 10 }
            )
            { ConvertTo-PodeOAHeaderProperties -Headers $headers } | Should -Not -Throw
            $result = ConvertTo-PodeOAHeaderProperties -Headers $headers
            $result['Custom-Header'].schema.maxLength | Should -Be 10
        }
    }


    Describe 'ConvertTo-PodeOAOfProperty Tests' {
        It "Converts property with 'allOf' type" {
            $property = @{
                type    = 'allOf'
                schemas = @('Schema1', 'Schema2')
            }
            { ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default' } | Should -Not -Throw
            $result = ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default'
            $result.allOf.Count | Should -Be 2
        }

        It "Converts property with 'oneOf' type" {
            $property = @{
                type    = 'oneOf'
                schemas = @('Schema1')
            }
            { ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default' } | Should -Not -Throw
            $result = ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default'
            $result.oneOf.Count | Should -Be 1
        }

        It "Converts property with 'anyOf' type" {
            $property = @{
                type    = 'anyOf'
                schemas = @(@{ type = 'string' }, @{ type = 'number' })
            }
            { ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default' } | Should -Not -Throw
            $result = ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default'
            $result.anyOf.Count | Should -Be 2
        }

        It "Returns empty for unsupported 'Of' type" {
            $property = @{
                type    = 'noneOf'
                schemas = @('Schema1')
            }
            { ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default' } | Should -Not -Throw
            $result = ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default'
            $result.Count | Should -Be 0
        }

        It 'Handles property with discriminator' {
            $property = @{
                type          = 'allOf'
                schemas       = @('Schema1')
                discriminator = 'TestDiscriminator'
            }
            { ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default' } | Should -Not -Throw
            $result = ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default'
            $result.discriminator | Should -Be 'TestDiscriminator'
        }

        It 'Handles mixed schema types' {
            $property = @{
                type    = 'anyOf'
                schemas = @('Schema1', @{ type = 'string' })
            }
            { ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default' } | Should -Not -Throw
            $result = ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default'
            $result.anyOf.Count | Should -Be 2
        }

        It 'Handles empty schemas' {
            $property = @{
                type = 'allOf'
            }
            { ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default' } | Should -Not -Throw
            $result = ConvertTo-PodeOAOfProperty -Property $property -DefinitionTag 'default'
            $result.allOf.Count | Should -Be 0
        }
    }

    Describe 'Test-PodeOAComponentExternalPath Tests' {
        BeforeEach {
            # Mock the $PodeContext variable
            $Global:PodeContext = @{
                Server = @{
                    OpenAPI = @{
                        Definitions = @{
                            tag1 = @{
                                hiddenComponents = @{
                                    externalPath = @{
                                        'MyComponentName' = $true
                                        'OtherComponent'  = $true
                                    }
                                }
                            }
                            tag2 = @{
                                hiddenComponents = @{
                                    externalPath = @{
                                        'MyComponentName' = $true
                                        'OtherComponent'  = $true
                                    }
                                }
                            }
                            tag3 = @{
                                hiddenComponents = @{
                                    externalPath = @{
                                        'YourComponentName' = $true
                                        'OtherComponent'    = $true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        It 'Returns true when name exists in all tags' {
            $result = Test-PodeOAComponentExternalPath -Name 'MyComponentName' -DefinitionTag @('tag1', 'tag2')
            $result | Should -Be $true
        }

        It 'Returns false when name does not exist in some tags' {
            $result = Test-PodeOAComponentExternalPath -Name 'MyComponentName' -DefinitionTag @('tag1', 'tag3')
            $result | Should -Be $false
        }

        It 'Returns false when name does not exist in any tags' {
            $result = Test-PodeOAComponentExternalPath -Name 'NonExistentName' -DefinitionTag @('tag1', 'tag2', 'tag3')
            $result | Should -Be $false
        }

        It 'Handles empty definition tags' {
            { Test-PodeOAComponentExternalPath -Name 'AnyName' -DefinitionTag @() } | Should -Throw
        }

        AfterAll {
            Remove-Variable -Name 'PodeContext' -Scope Global
        }
    }

    Describe 'Set-PodeOAGlobalAuth Tests' {
        BeforeEach {
            # Mock dependent functions
            Mock Test-PodeAuthExists { return $true }
            Mock Expand-PodeAuthMerge { return @('BasicAuth') }
            Mock Get-PodeAuth { return @{ Scheme = @{ Arguments = @{ Scopes = @('read', 'write') } } } }
            Mock ConvertTo-PodeRouteRegex { return '^/api/.*$' }

        }

        It 'Successfully applies authentication to a route for a single tag' {
            { Set-PodeOAGlobalAuth -Name 'BasicAuth' -Route '/api/*' -DefinitionTag 'default' } | Should -Not -Throw
            $Global:PodeContext.Server.OpenAPI.Definitions.default.Security.Count | Should -Be 1
        }

        It 'Throws an exception for non-existent authentication method' {
            Mock Test-PodeAuthExists { return $false }
            { Set-PodeOAGlobalAuth -Name 'InvalidAuth' -Route '/api/*' -DefinitionTag 'default' } | Should -Throw
        }

        It 'Applies authentication to multiple definition tags' {
            { Set-PodeOAGlobalAuth -Name 'BasicAuth' -Route '/api/*' -DefinitionTag @('default', 'alternative') } | Should -Not -Throw
            $Global:PodeContext.Server.OpenAPI.Definitions.default.Security.Count | Should -Be 1
            $Global:PodeContext.Server.OpenAPI.Definitions.alternative.Security.Count | Should -Be 1
        }

        It 'Handles authentication methods with scopes' {
            { Set-PodeOAGlobalAuth -Name 'BasicAuth' -Route '/api/*' -DefinitionTag 'default' } | Should -Not -Throw
            $Global:PodeContext.Server.OpenAPI.Definitions.default.Security[0].Definition.BasicAuth | Should -Be @('read', 'write')
        }
    }


    Describe "Set-PodeOAAuth Tests" {
        BeforeAll {
            # Mock Test-PodeAuthExists to simulate authentication method existence
            Mock Test-PodeAuthExists { return $true }
        }

        It "Applies multiple authentication methods to a route" {
            $route = @{ OpenApi = @{} }
            { Set-PodeOAAuth -Route @($route) -Name @('BasicAuth', 'ApiKeyAuth') } | Should -Not -Throw
            $route.OpenApi.Authentication.Count | Should -Be 2
        }

        It "Throws an exception for non-existent authentication method" {
            Mock Test-PodeAuthExists { return $false }
            $route = @{ OpenApi = @{} }
            { Set-PodeOAAuth -Route @($route) -Name 'InvalidAuth' } | Should -Throw
        }

        It "Allows anonymous access" {
            $route = @{ OpenApi = @{ Authentication = @{} } }
            { Set-PodeOAAuth -Route @($route) -Name 'BasicAuth' -AllowAnon } | Should -Not -Throw
            $route.OpenApi.Authentication.keys -contains '%_allowanon_%' | Should -Be $true
            $route.OpenApi.Authentication['%_allowanon_%'] | Should -BeNullOrEmpty
        }

        It "Applies both authenticated and anonymous access to a route" {
            $route = @{ OpenApi = @{} }
            { Set-PodeOAAuth -Route @($route) -Name @('BasicAuth') -AllowAnon } | Should -Not -Throw
            $route.OpenApi.Authentication.Count | Should -Be 2
            $route.OpenApi.Authentication[0].BasicAuth | Should  -BeNullOrEmpty
            $route.OpenApi.Authentication[1].'%_allowanon_%' | Should  -BeNullOrEmpty
        }
    }

    Describe "Get-PodeOABaseObject Tests" {
        It "Returns the correct base OpenAPI object structure" {
            $baseObject = Get-PodeOABaseObject

            $baseObject | Should -BeOfType [hashtable]
            $baseObject.info | Should -BeOfType [ordered]
            $baseObject.Path | Should -BeNullOrEmpty
            $baseObject.webhooks | Should -BeOfType [ordered]
            $baseObject.components | Should -BeOfType [ordered]
            $baseObject.tags | Should -BeOfType [ordered]
            $baseObject.hiddenComponents | Should -BeOfType [hashtable]
        }
    }

    Describe "Initialize-OpenApiTable Tests" {
        It "Initializes OpenAPI table with default settings" {
            $openApiTable = Initialize-OpenApiTable

            $openApiTable | Should -BeOfType [hashtable]
            $openApiTable.DefinitionTagSelectionStack -is  [System.Collections.Generic.Stack[System.Object]]   | Should -BeTrue
            $openApiTable.DefaultDefinitionTag | Should -Be "default"
            $openApiTable.SelectedDefinitionTag | Should -Be "default"
            $openApiTable.Definitions | Should -BeOfType [hashtable]
            $openApiTable.Definitions["default"] | Should -BeOfType [hashtable]
        }

        It "Initializes OpenAPI table with custom definition tag" {
            $customTag = "api-v1"
            $openApiTable = Initialize-OpenApiTable -DefaultOADefinitionTag $customTag

            $openApiTable.DefaultDefinitionTag | Should -Be $customTag
            $openApiTable.SelectedDefinitionTag | Should -Be $customTag
            $openApiTable.Definitions | Should -BeOfType [hashtable]
            $openApiTable.Definitions[$customTag] | Should -BeOfType [hashtable]
        }
    }


}