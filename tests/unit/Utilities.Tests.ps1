
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

}


Describe 'ConvertTo-PodeXml' {
    BeforeEach {
        Mock Write-PodeTextResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
        $_ContentType = 'application/xml'
    }
    It 'Returns an empty value for an empty value' {
        ConvertTo-PodeXml -InputObject ([string]::Empty) | Should -Be ( '<?xml version="1.0" encoding="UTF-8"?><root/>')
    }

    It 'Returns a raw value' {
        ConvertTo-PodeXml -InputObject '<root></root>' | Should -Be '<root></root>'
    }

    It 'Converts and returns a value from a hashtable' {
        ConvertTo-PodeXml -InputObject @{ 'name' = 'john' } | Should -Be '<?xml version="1.0" encoding="UTF-8"?><root><name>john</name></root>'
    }

    It 'Converts and returns a value from a PSCustomObject' {
        $r = ConvertTo-PodeXml -InputObject ([PSCustomObject]@{
                Name = 'john'
            })
        ($r -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="name">john</Property></Object></Objects>'
    }

    It 'Converts and returns a value from a array of hashtable by pipe' {
    ((  @(@{ Name = 'Rick' }, @{ Name = 'Don' }) | ConvertTo-PodeXml) -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
    }

    It 'Converts and returns a value from a array of hashtable' {
        $r = ConvertTo-PodeXml -InputObject @(@{ Name = 'Rick' }, @{ Name = 'Don' })
        ($r -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
    }

    It 'Converts and returns a value from a array of PSCustomObject' {
        $users = @([PSCustomObject]@{
                Name = 'Rick'
            }, [PSCustomObject]@{
                Name = 'Don'
            }
        )
        $r = ConvertTo-PodeXml -InputObject $users
        ($r -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
    }

    It 'Converts and returns a value from a array of PSCustomObject passed by pipe' {
        $r = @([PSCustomObject]@{
                Name = 'Rick'
            }, [PSCustomObject]@{
                Name = 'Don'
            }
        ) | ConvertTo-PodeXml
        ($r -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
    }

}