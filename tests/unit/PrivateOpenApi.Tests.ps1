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
                    OpenAPI  = @{
                        SelectedDefinitionTag = 'default'
                        Definitions           = @{
                            default = Get-PodeOABaseObject
                        }
                    }
                }
            }
        }
        $global:PodeContext = GetPodeContext

    }


    Describe 'New-PodeOAPropertyInternal' {
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
                    AdditionalProperties   =  @{
                        'property1' = @{ 'type' = 'string'; 'description' = 'Description for property1' }
                        'property2' = @{ 'type' = 'integer'; 'format' = 'int32' }
                    }
                }
                { New-PodeOAPropertyInternal -Type 'string' -Params $params } | Should -Throw
            }
        }
    }

    Describe 'ConvertTo-PodeOAHeaderProperties' {
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


}