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



Describe 'New-PodeJwtSignature Function Tests' -Tags 'JWT' {
    BeforeAll {
        # Sample data
        $testValue = 'TestData'

        $testSecret = [System.Text.Encoding]::UTF8.GetBytes('SuperSecretKey')

        $testPath = $(Split-Path -Parent -Path $(Split-Path -Parent -Path $path))
        # Load test keys from PEM files (Assume these exist in the test environment)
        $algorithms = 'ES256', 'ES384', 'ES512'
        if ($PSEdition -eq 'Core') {
            $algorithms += 'RS256', 'RS384', 'RS512'
        }
        $PrivateKey = @{}
        foreach ($alg in $algorithms) {
            $PrivateKey[$alg] = Get-Content "$testPath/certs/$alg-private.pem" -Raw | ConvertTo-SecureString -AsPlainText -Force
        }
    }

    Context 'HMAC Signing Tests' {
        It 'Should generate a valid HMAC-SHA256 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm HS256 -SecretBytes $testSecret
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid HMAC-SHA384 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm HS384 -SecretBytes $testSecret
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid HMAC-SHA512 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm HS512 -SecretBytes $testSecret
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }
    }

    Context 'RSA Signing Tests' -Tag 'No_DesktopEdition' {
        It 'Should generate a valid RSA-SHA256 signature' {
            $alg = 'RS256'
            $result = New-PodeJwtSignature   -Token $testValue -Algorithm $alg -PrivateKey $PrivateKey[$alg]
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid RSA-SHA384 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm RS384 -PrivateKey $PrivateKey['RS384']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid RSA-SHA512 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm RS512 -PrivateKey $PrivateKey['RS512']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }
    }

    Context 'ECDSA Signing Tests' -Tag 'No_DesktopEdition' {
        It 'Should generate a valid ECDSA-SHA256 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm ES256 -PrivateKey $PrivateKey['ES256']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid ECDSA-SHA384 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm ES384 -PrivateKey $PrivateKey['ES384']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid ECDSA-SHA512 signature' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm ES512 -PrivateKey $PrivateKey['ES512']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }
    }

    Context 'Algorithm NONE Tests' {
        It 'Should return an empty signature when algorithm is NONE' {
            $result = New-PodeJwtSignature -Token $testValue -Algorithm NONE
            $result | Should -BeExactly ''
        }

        It 'Should throw an error if a secret is provided with NONE' {
            { New-PodeJwtSignature -Token $testValue -Algorithm NONE -SecretBytes $testSecret } | Should -Throw
        }

        It 'Should throw an error if a private key is provided with NONE' {
            { New-PodeJwtSignature -Token $testValue -Algorithm NONE -PrivateKey $PrivateKey['ES512'] } | Should -Throw
        }
    }

    Context 'Invalid Inputs' {
        It 'Should throw an error for missing secret in HMAC' {
            { New-PodeJwtSignature -Token $testValue -Algorithm HS256 } | Should -Throw
        }

        It 'Should throw an error for missing private key in RSA' {
            { New-PodeJwtSignature -Token $testValue -Algorithm RS256 } | Should -Throw
        }

        It 'Should throw an error for an unsupported algorithm' {
            { New-PodeJwtSignature -Token $testValue -Algorithm 'INVALID' -Secret $testSecret } | Should -Throw
        }
    }
}
