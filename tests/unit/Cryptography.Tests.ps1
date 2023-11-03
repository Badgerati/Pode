BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
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
            { Invoke-PodeSHA256Hash -Value $null } | Should -Throw -ExpectedMessage '*argument is null or empty*'
        }

        It 'Throws empty value error' {
            { Invoke-PodeSHA256Hash -Value '' } | Should -Throw -ExpectedMessage '*argument is null or empty*'
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
        Mock Get-PodeRandomBytes { return @(10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10) }
        New-PodeGuid -Secure -Length 16 | Should -Be '0a0a0a0a-0a0a-0a0a-0a0a-0a0a0a0a0a0a'
    }
}

Describe 'Get-PodeRandomBytes' {
    It 'Returns an array of bytes' {
        $b = (Get-PodeRandomBytes -Length 16)
        $b | Should -Not -Be $null
        $b.Length | Should -Be 16
    }
}

Describe 'New-PodeSalt' {
    It 'Returns a salt' {
        Mock Get-PodeRandomBytes { return @(10, 10, 10) }
        New-PodeSalt -Length 3 | Should -Be 'CgoK'
    }
}