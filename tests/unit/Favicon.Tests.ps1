BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}

Describe 'Add-PodeFavicon' {

    BeforeEach {
        $script:PodeContext = @{
            Server = @{
                Endpoints = @{
                    'default' = @{ Protocol = 'Http'; Favicon = $null; Default = $true }
                    'api'     = @{ Protocol = 'Http'; Favicon = $null; Default = $false }
                }
            }
        }
    }

    Context 'Using -Default parameter' {
        It 'adds the default favicon to all HTTP endpoints' {
            Mock Get-PodeModuleMiscPath { return "$($src)Misc" }
            Mock Get-PodeImageContentType { return 'image/x-icon' }



            Add-PodeFavicon -Default

            foreach ($endpoint in $PodeContext.Server.Endpoints.Values) {
                $endpoint.Favicon | Should -Not -BeNullOrEmpty
                $endpoint.Favicon.ContentType | Should -Be 'image/x-icon'
                $endpoint.Favicon.Bytes.GetType() | Should -Be 'byte[]'
            }
        }
    }

    Context 'Using -Path parameter' {
        It 'adds a custom favicon from file' {
            Mock Get-PodeRelativePath { return "$($src)Misc/favicon.ico" }
            Mock Get-PodeImageContentType { return 'image/x-icon' }


            Add-PodeFavicon -Path 'relative/path/to/favicon.ico'

            foreach ($endpoint in $PodeContext.Server.Endpoints.Values) {
                $endpoint.Favicon.Bytes.GetType() | Should -Be 'byte[]'
                $endpoint.Favicon.ContentType | Should -Be 'image/x-icon'
            }
        }
    }

    Context 'Using -Binary parameter' {
        It 'adds a binary favicon to specific endpoint' {
            Mock Get-PodeImageContentType { return 'image/png' }
            $bytes = [byte[]](1, 2, 3)

            Add-PodeFavicon -Binary $bytes -EndpointName 'api'

            $PodeContext.Server.Endpoints['api'].Favicon.Bytes | Should -Be $bytes
            $PodeContext.Server.Endpoints['api'].Favicon.ContentType | Should -Be 'image/png'

            $PodeContext.Server.Endpoints['default'].Favicon | Should -BeNullOrEmpty
        }
    }

    Context 'Using -DefaultEndpoint switch' {

        It 'adds favicon only to endpoints marked as default' {
            Mock Get-PodeModuleMiscPath { return "$($src)Misc" }
            Mock Get-PodeImageContentType { return 'image/x-icon' }

            Add-PodeFavicon -Default -DefaultEndpoint

            $PodeContext.Server.Endpoints['default'].Favicon | Should -Not -BeNullOrEmpty
            $PodeContext.Server.Endpoints['api'].Favicon | Should -BeNullOrEmpty
        }

        It 'skips all endpoints if none are marked as default' {
            $PodeContext.Server.Endpoints['default'].Default = $false
            $PodeContext.Server.Endpoints['api'].Default = $false

            Mock Get-PodeModuleMiscPath { return "$($src)Misc" }
            Mock Get-PodeImageContentType { return 'image/x-icon' }

            Add-PodeFavicon -Default -DefaultEndpoint

            foreach ($ep in $PodeContext.Server.Endpoints.Values) {
                $ep.Favicon | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Invalid endpoint' {
        It 'throws if endpoint name does not exist' {
            { Add-PodeFavicon -Binary @(0x01) -EndpointName 'bad-endpoint' } | Should -Throw  ($Podelocale.endpointNameNotExistExceptionMessage -f 'bad-endpoint')
        }
    }
}

Describe 'Test-PodeFavicon' {

    BeforeEach {
        # Setup a clean mock PodeContext
        $script:PodeContext = @{
            Server = @{
                Endpoints = @{
                    'default' = @{ Protocol = 'Http'; Favicon = $null; Default = $true }
                    'api'     = @{ Protocol = 'Http'; Favicon = $null; Default = $false }
                }
            }
        }
    }

    Context 'When checking all endpoints' {
        It 'returns $false if no favicons are set' {
            Test-PodeFavicon | Should -BeFalse
        }

        It 'returns $true if all endpoints have favicons' {
            $PodeContext.Server.Endpoints['default'].Favicon = @{ Bytes = @(0x00); ContentType = 'image/x-icon' }
            $PodeContext.Server.Endpoints['api'].Favicon = @{ Bytes = @(0x00); ContentType = 'image/x-icon' }

            Test-PodeFavicon | Should -BeTrue
        }

        It 'returns $false if at least one endpoint is missing favicon' {
            $PodeContext.Server.Endpoints['api'].Favicon = @{ Bytes = @(0x00); ContentType = 'image/x-icon' }

            Test-PodeFavicon | Should -BeFalse
        }
    }

    Context 'When checking a specific endpoint' {
        It 'returns $true if the endpoint has a favicon' {
            $PodeContext.Server.Endpoints['api'].Favicon = @{ Bytes = @(0x00); ContentType = 'image/x-icon' }

            Test-PodeFavicon -EndpointName 'api' | Should -BeTrue
        }

        It 'returns $false if the endpoint does not have a favicon' {
            Test-PodeFavicon -EndpointName 'default' | Should -BeFalse
        }

        It 'throws if the endpoint does not exist' {
            { Test-PodeFavicon -EndpointName 'bad-endpoint' } | Should -Throw  ($Podelocale.endpointNameNotExistExceptionMessage -f 'bad-endpoint')
        }
    }

    Context 'Using -DefaultEndpoint' {
        It 'returns $true only if all default endpoints have a favicon' {
            $PodeContext.Server.Endpoints['default'].Favicon = @{ Bytes = @(0xFF) }

            Test-PodeFavicon -DefaultEndpoint | Should -BeTrue
        }

        It 'returns $false if any default endpoint is missing a favicon' {
            Test-PodeFavicon -DefaultEndpoint | Should -BeFalse
        }

        It 'ignores non-default endpoints' {
            $PodeContext.Server.Endpoints['default'].Favicon = @{ Bytes = @(0xAA) }
            $PodeContext.Server.Endpoints['api'].Favicon = $null

            Test-PodeFavicon -DefaultEndpoint | Should -BeTrue
        }
    }
}


Describe 'Get-PodeFavicon' {

    BeforeEach {
        # Set up mock PodeContext with two endpoints
        $script:PodeContext = @{
            Server = @{
                Endpoints = @{
                    'default' = @{ Protocol = 'Http'; Favicon = $null; Default = $true }
                    'api'     = @{ Protocol = 'Http'; Favicon = $null; Default = $false }
                }
            }
        }
    }
    Context 'Without parameters' {
        It 'returns empty hashtable when no favicons are set' {
            $result = Get-PodeFavicon
            $result.Count | Should -Be 0
        }

        It 'returns favicons for all endpoints that have them' {
            $PodeContext.Server.Endpoints['default'].Favicon = @{ Bytes = @(0x01); ContentType = 'image/x-icon' }
            $PodeContext.Server.Endpoints['api'].Favicon = @{ Bytes = @(0x02); ContentType = 'image/png' }

            $result = Get-PodeFavicon
            $result.Keys.Count | Should -Be 2
            $result['default'].ContentType | Should -Be 'image/x-icon'
            $result['api'].Bytes | Should -Be @(0x02)
        }
    }

    Context 'With -EndpointName' {
        It 'returns favicon for the specified endpoint if set' {
            $PodeContext.Server.Endpoints['api'].Favicon = @{ Bytes = @(0xAA); ContentType = 'image/png' }

            $result = Get-PodeFavicon -EndpointName 'api'
            $result.Count | Should -Be 1
            $result['api'].Bytes | Should -Be @(0xAA)
        }

        It 'returns empty hashtable if endpoint has no favicon' {
            $result = Get-PodeFavicon -EndpointName 'api'
            $result.Count | Should -Be 0
        }

        It 'throws if the endpoint does not exist' {
            { Get-PodeFavicon -EndpointName 'not-found' } | Should -Throw  ($Podelocale.endpointNameNotExistExceptionMessage -f 'not-found')
        }
    }

    Context 'With -DefaultEndpoint' {
        It 'returns only favicons from endpoints marked as default' {
            $PodeContext.Server.Endpoints['default'].Favicon = @{ Bytes = @(0xFE); ContentType = 'image/x-icon' }
            $PodeContext.Server.Endpoints['api'].Favicon = @{ Bytes = @(0xDE); ContentType = 'image/png' }

            $result = Get-PodeFavicon -DefaultEndpoint
            $result.Count | Should -Be 1
            $result.ContainsKey('default') | Should -BeTrue
            $result.ContainsKey('api') | Should -BeFalse
        }

        It 'returns empty if no default endpoints have a favicon' {
            $result = Get-PodeFavicon -DefaultEndpoint
            $result.Count | Should -Be 0
        }

        It 'ignores non-default endpoints with favicons' {
            $PodeContext.Server.Endpoints['api'].Favicon = @{ Bytes = @(0xDD); ContentType = 'image/png' }

            $result = Get-PodeFavicon -DefaultEndpoint
            $result.Count | Should -Be 0
        }
    }
}


Describe 'Remove-PodeFavicon' {

    BeforeEach {
        $script:PodeContext = @{
            Server = @{
                Endpoints = @{
                    'default' = @{ Protocol = 'Http'; Favicon = @{ Bytes = @(0x01); ContentType = 'image/x-icon' }; Default = $true }
                    'api'     = @{ Protocol = 'Http'; Favicon = @{ Bytes = @(0x02); ContentType = 'image/png' }; Default = $false }

                }
            }
        }
    }

    Context 'Removing from all endpoints' {
        It 'clears favicons from all endpoints' {
            Remove-PodeFavicon

            foreach ($endpoint in $PodeContext.Server.Endpoints.Values) {
                $endpoint.Favicon | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Removing from a specific endpoint' {
        It 'clears favicon from the specified endpoint only' {
            Remove-PodeFavicon -EndpointName 'api'

            $PodeContext.Server.Endpoints['api'].Favicon | Should -BeNullOrEmpty
            $PodeContext.Server.Endpoints['default'].Favicon | Should -Not -BeNullOrEmpty
        }

        It 'does nothing if the endpoint has no favicon' {
            $PodeContext.Server.Endpoints['default'].Favicon = $null

            { Remove-PodeFavicon -EndpointName 'default' } | Should -Not -Throw
            $PodeContext.Server.Endpoints['default'].Favicon | Should -BeNull
        }
    }

    Context 'Using -DefaultEndpoint switch' {
        It 'removes favicon only from endpoints marked as default' {
            Remove-PodeFavicon -DefaultEndpoint

            $PodeContext.Server.Endpoints['default'].Favicon | Should -BeNullOrEmpty
            $PodeContext.Server.Endpoints['api'].Favicon | Should -Not -BeNullOrEmpty
        }

        It 'does not remove from endpoints that are not marked as default' {
            $PodeContext.Server.Endpoints['default'].Default = $false
            Remove-PodeFavicon -DefaultEndpoint

            foreach ($ep in $PodeContext.Server.Endpoints.Values) {
                $ep.Favicon | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Invalid endpoint name' {
        It 'throws if the endpoint does not exist' {
            { Remove-PodeFavicon -EndpointName 'invalid' } | Should -Throw  ($Podelocale.endpointNameNotExistExceptionMessage -f 'invalid')
        }
    }
}
