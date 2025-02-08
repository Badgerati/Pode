[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}

Describe 'Invoke-PodeHMACSHA256Hash' {
    Context 'Valid parameters' {
        It 'Returns encrypted data' {
            Invoke-PodeHMACSHA256Hash -Value 'value' -Secret 'key' | Should -Be 'kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE='
        }
    }
}

Describe 'Invoke-PodeSHA256Hash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeSHA256Hash -Value $null } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-PodeSHA256Hash'
        }

        It 'Throws empty value error' {
            { Invoke-PodeSHA256Hash -Value '' } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-PodeSHA256Hash'
        }
    }

    Context 'Valid parameters' {
        It 'Returns encrypted data' {
            Invoke-PodeSHA256Hash -Value 'value' | Should -Be 'zUJATVKtVcz6mspK3IKKpYAK2dOFoGcfvL9yQRgyBhk='
        }
    }
}

Describe 'New-PodeGuid' {
    It 'Returns a valid guid' {
        (New-PodeGuid) | Should -Not -Be $null
    }

    It 'Returns a secure guid' {
        Mock Get-PodeRandomByte { return @(10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10) }
        New-PodeGuid -Secure -Length 16 | Should -Be '0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a'
    }
}

Describe 'Get-PodeRandomByte' {
    It 'Returns an array of bytes' {
        $b = (Get-PodeRandomByte -Length 16)
        $b | Should -Not -Be $null
        $b.Length | Should -Be 16
    }
}

Describe 'New-PodeSalt' {
    It 'Returns a salt' {
        Mock Get-PodeRandomByte { return @(10, 10, 10) }
        New-PodeSalt -Length 3 | Should -Be 'CgoK'
    }
}



Describe 'Invoke-PodeJWTSign Function Tests' -Tags 'JWT' {
    BeforeAll {
        # Sample data
        $testValue = 'TestData'
        $testSecret = [System.Text.Encoding]::UTF8.GetBytes('SuperSecretKey')

        $testPath = $(Split-Path -Parent -Path $(Split-Path -Parent -Path $path))
        # Load test keys from PEM files (Assume these exist in the test environment)
        $rsaPrivateKey = Get-Content "$testPath/certs/rsa_private.pem" -Raw
        $ecdsaPrivateKey = Get-Content "$testPath/certs/ecdsa_private.pem" -Raw
    }

    Context 'HMAC Signing Tests' {
        It 'Should generate a valid HMAC-SHA256 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm HS256 -SecretBytes $testSecret
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }

        It 'Should generate a valid HMAC-SHA384 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm HS384 -SecretBytes $testSecret
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }

        It 'Should generate a valid HMAC-SHA512 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm HS512 -SecretBytes $testSecret
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }
    }

    Context 'RSA Signing Tests' {
        It 'Should generate a valid RSA-SHA256 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm RS256 -PrivateKey $rsaPrivateKey
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }

        It 'Should generate a valid RSA-SHA384 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm RS384 -PrivateKey $rsaPrivateKey
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }

        It 'Should generate a valid RSA-SHA512 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm RS512 -PrivateKey $rsaPrivateKey
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }
    }

    Context 'ECDSA Signing Tests' {
        It 'Should generate a valid ECDSA-SHA256 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm ES256 -PrivateKey $ecdsaPrivateKey
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }

        It 'Should generate a valid ECDSA-SHA384 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm ES384 -PrivateKey $ecdsaPrivateKey
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }

        It 'Should generate a valid ECDSA-SHA512 signature' {
            $result = Invoke-PodeJWTSign -Value $testValue -Algorithm ES512 -PrivateKey $ecdsaPrivateKey
            $result | Should -Match '^[A-Za-z0-9+/]+={0,2}$'
        }
    }

    Context 'Invalid Inputs' {
        It 'Should throw an error for missing secret in HMAC' {
            { Invoke-PodeJWTSign -Value $testValue -Algorithm HS256 } | Should -Throw
        }

        It 'Should throw an error for missing private key in RSA' {
            { Invoke-PodeJWTSign -Value $testValue -Algorithm RS256 } | Should -Throw
        }

        It 'Should throw an error for an unsupported algorithm' {
            { Invoke-PodeJWTSign -Value $testValue -Algorithm 'INVALID' -Secret $testSecret } | Should -Throw
        }
    }
}
