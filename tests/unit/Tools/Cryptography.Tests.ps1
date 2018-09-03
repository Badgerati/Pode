$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Invoke-HMACSHA256Hash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-HMACSHA256Hash -Value $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-HMACSHA256Hash -Value '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-HMACSHA256Hash -Value 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-HMACSHA256Hash -Value 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns encrypted data' {
            Invoke-HMACSHA256Hash -Value 'value' -Secret 'key' | Should Be 'kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE='
        }
    }
}

Describe 'Invoke-SHA256Hash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-SHA256Hash -Value $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-SHA256Hash -Value '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns encrypted data' {
            Invoke-SHA256Hash -Value 'value' | Should Be 'zUJATVKtVcz6mspK3IKKpYAK2dOFoGcfvL9yQRgyBhk='
        }
    }
}

Describe 'Invoke-CookieSign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-CookieSign -Value $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-CookieSign -Value '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-CookieSign -Value 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-CookieSign -Value 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-CookieSign -Value 'value' -Secret 'key' | Should Be 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE='
        }
    }
}

Describe 'Invoke-CookieUnsign' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Invoke-CookieUnsign -Signature $null -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty value error' {
            { Invoke-CookieUnsign -Signature '' -Secret 'key' } | Should Throw 'argument is null or empty'
        }

        It 'Throws null secret error' {
            { Invoke-CookieUnsign -Signature 'value' -Secret $null } | Should Throw 'argument is null or empty'
        }

        It 'Throws empty secret error' {
            { Invoke-CookieUnsign -Signature 'value' -Secret '' } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns signed encrypted data' {
            Invoke-CookieUnsign -Signature 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE=' -Secret 'key' | Should Be 'value'
        }
    }
}