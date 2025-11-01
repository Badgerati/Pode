using namespace System.Security.Cryptography

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}

Describe 'New-PodeJwtSignature Function Tests' -Tags 'JWT' {
    BeforeAll {
        # Sample data
        $testValue = 'TestData'

        $testSecret = [System.Text.Encoding]::UTF8.GetBytes('SuperSecretKey')

        $testPath = $(Split-Path -Parent -Path $(Split-Path -Parent -Path $path))
        $certificateTypes = @{
            'RS256' = @{
                KeyType          = 'RSA'
                KeyLength        = 2048
                RsaPaddingScheme = 'Pkcs1V15'
            }
            'RS384' = @{
                KeyType          = 'RSA'
                KeyLength        = 3072
                RsaPaddingScheme = 'Pkcs1V15'
            }
            'RS512' = @{
                KeyType          = 'RSA'
                KeyLength        = 4096
                RsaPaddingScheme = 'Pkcs1V15'
            }
            'PS256' = @{
                KeyType          = 'RSA'
                KeyLength        = 2048
                RsaPaddingScheme = 'Pss'
            }
            'PS384' = @{
                KeyType          = 'RSA'
                KeyLength        = 3072
                RsaPaddingScheme = 'Pss'
            }
            'PS512' = @{
                KeyType          = 'RSA'
                KeyLength        = 4096
                RsaPaddingScheme = 'Pss'
            }
            'ES256' = @{
                KeyType   = 'ECDSA'
                KeyLength = 256
            }
            'ES384' = @{
                KeyType   = 'ECDSA'
                KeyLength = 384
            }
            'ES512' = @{
                KeyType   = 'ECDSA'
                KeyLength = 521
            }
        }

        $PrivateKey = @{}

        foreach ($alg in $certificateTypes.keys) {
            $PrivateKey[$alg] = New-PodeSelfSignedCertificate -Loopback -KeyType $certificateTypes[$alg].KeyType -KeyLength $certificateTypes[$alg].KeyLength -CertificatePurpose CodeSigning -Ephemeral
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
            $result = New-PodeJwtSignature   -Token $testValue -X509Certificate $PrivateKey[$alg]
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid RSA-SHA384 signature' {
            $result = New-PodeJwtSignature -Token $testValue -X509Certificate $PrivateKey['RS384']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid RSA-SHA512 signature' {
            $result = New-PodeJwtSignature -Token $testValue  -X509Certificate $PrivateKey['RS512']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }
    }

    Context 'ECDSA Signing Tests' -Tag 'No_DesktopEdition' {
        It 'Should generate a valid ECDSA-SHA256 signature' {
            $result = New-PodeJwtSignature -Token $testValue  -X509Certificate $PrivateKey['ES256']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid ECDSA-SHA384 signature' {
            $result = New-PodeJwtSignature -Token $testValue   -X509Certificate $PrivateKey['ES384']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }

        It 'Should generate a valid ECDSA-SHA512 signature' {
            $result = New-PodeJwtSignature -Token $testValue  -X509Certificate $PrivateKey['ES512']
            $result | Should -Match '^[A-Za-z0-9_-]+$'
        }
    }

    Context 'Algorithm NONE Tests' {
        It 'Should throw an error if a secret is provided with NONE' {
            { New-PodeJwtSignature -Token $testValue -Algorithm NONE -SecretBytes $testSecret } | Should -Throw
        }

    }

}