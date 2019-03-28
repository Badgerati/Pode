$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Invoke-PodeHMACSHA256Hash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeHMACSHA256Hash -Value $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-PodeHMACSHA256Hash -Value '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-PodeHMACSHA256Hash -Value 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-PodeHMACSHA256Hash -Value 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns encrypted data' {
            Invoke-PodeHMACSHA256Hash -Value 'value' -Secret 'key' | Should Be 'kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE='
        }
    }
}

Describe 'Invoke-PodeSHA256Hash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeSHA256Hash -Value $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-PodeSHA256Hash -Value '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns encrypted data' {
            Invoke-PodeSHA256Hash -Value 'value' | Should Be 'zUJATVKtVcz6mspK3IKKpYAK2dOFoGcfvL9yQRgyBhk='
        }
    }
}

Describe 'Invoke-PodeCookieSign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeCookieSign -Value $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-PodeCookieSign -Value '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-PodeCookieSign -Value 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-PodeCookieSign -Value 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-PodeCookieSign -Value 'value' -Secret 'key' | Should Be 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE='
        }
    }
}

Describe 'Invoke-PodeCookieUnsign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-PodeCookieUnsign -Signature $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-PodeCookieUnsign -Signature '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-PodeCookieUnsign -Signature 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-PodeCookieUnsign -Signature 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-PodeCookieUnsign -Signature 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE=' -Secret 'key' | Should Be 'value'
        }
    }
}