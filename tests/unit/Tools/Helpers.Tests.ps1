$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
$sut = (Split-Path -Leaf -Path $path) -ireplace '\.Tests\.', '.'
. "$($src)\$($sut)"

Describe 'Get-Type' {
    Context 'No value supplied' {
        It 'Return the null' {
            Get-Type -Value $null | Should Be $null
        }
    }

    Context 'Valid value supplied' {
        It 'String type' {
            $result = (Get-Type -Value [string]::Empty)
            $result | Should Not Be $null
            $result.Name | Should Be 'string'
            $result.BaseName | Should Be 'object'
        }

        It 'Boolean type' {
            $result = (Get-Type -Value $true)
            $result | Should Not Be $null
            $result.Name | Should Be 'boolean'
            $result.BaseName | Should Be 'valuetype'
        }

        It 'Int32 type' {
            $result = (Get-Type -Value 1)
            $result | Should Not Be $null
            $result.Name | Should Be 'int32'
            $result.BaseName | Should Be 'valuetype'
        }

        It 'Int64 type' {
            $result = (Get-Type -Value 1l)
            $result | Should Not Be $null
            $result.Name | Should Be 'int64'
            $result.BaseName | Should Be 'valuetype'
        }

        It 'Hashtable type' {
            $result = (Get-Type -Value @{})
            $result | Should Not Be $null
            $result.Name | Should Be 'hashtable'
            $result.BaseName | Should Be 'object'
        }

        It 'Array type' {
            $result = (Get-Type -Value @())
            $result | Should Not Be $null
            $result.Name | Should Be 'object[]'
            $result.BaseName | Should Be 'array'
        }

        It 'ScriptBlock type' {
            $result = (Get-Type -Value {})
            $result | Should Not Be $null
            $result.Name | Should Be 'scriptblock'
            $result.BaseName | Should Be 'object'
        }
    }
}

Describe 'Test-Empty' {
    Context 'No value is passed' {
        It 'Return true for no value' {
            Test-Empty | Should be $true
        }
        
        It 'Return true for null value' {
            Test-Empty -Value $null | Should be $true
        }
    }

    Context 'Empty value is passed' {
        It 'Return true for an empty array' {
            Test-Empty -Value @() | Should Be $true
        }
        
        It 'Return true for an empty hashtable' {
            Test-Empty -Value @{} | Should Be $true
        }

        It 'Return true for an empty string' {
            Test-Empty -Value ([string]::Empty) | Should Be $true
        }

        It 'Return true for a whitespace string' {
            Test-Empty -Value "  " | Should Be $true
        }
    }

    Context 'Valid value is passed' {
        It 'Return false for a string' {
            Test-Empty -Value "test" | Should Be $false
        }

        It 'Return false for a number' {
            Test-Empty -Value 1 | Should Be $false
        }

        It 'Return false for an array' {
            Test-Empty -Value @('test') | Should Be $false
        }

        It 'Return false for a hashtable' {
            Test-Empty -Value @{'key'='value';} | Should Be $false
        }
    }
}

Describe 'Test-IPAddress' {
    Context 'Values that are for any IP' {
        It 'Returns true for no value' {
            Test-IPAddress -IP $null | Should Be $true
        }

        It 'Returns true for empty value' {
            Test-IPAddress -IP ([string]::Empty) | Should Be $true
        }

        It 'Returns true for asterisk' {
            Test-IPAddress -IP '*' | Should Be $true
        }
    }

    Context 'Values for IPv4' {
        It 'Returns true for valid IP' {
            Test-IPAddress -IP '127.0.0.1' | Should Be $true
        }

        It 'Returns false for invalid IP' {
            Test-IPAddress -IP '256.0.0.0' | Should Be $false
        }
    }

    Context 'Values for IPv6' {
        It 'Returns true for valid shorthand IP' {
            Test-IPAddress -IP '[::]' | Should Be $true
        }

        It 'Returns true for valid IP' {
            Test-IPAddress -IP '[0000:1111:2222:3333:4444:5555:6666:7777]' | Should Be $true
        }

        It 'Returns false for invalid IP' {
            Test-IPAddress -IP '[]' | Should Be $false
        }
    }
}

Describe 'Test-IPAddressLocal' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-IPAddressLocal -IP ([string]::Empty) } | Should Throw 'because it is an empty'
        }

        It 'Throws error for null' {
            { Test-IPAddressLocal -IP $null } | Should Throw 'because it is an empty'
        }
    }

    Context 'Values not localhost' {
        It 'Returns false for non-localhost IP' {
            Test-IPAddressLocal -IP '192.168.10.10' | Should Be $false
        }
    }

    Context 'Values that are localhost' {
        It 'Returns true for 0.0.0.0' {
            Test-IPAddressLocal -IP '0.0.0.0' | Should Be $true
        }

        It 'Returns true for asterisk' {
            Test-IPAddressLocal -IP '*' | Should Be $true
        }

        It 'Returns true for 127.0.0.1' {
            Test-IPAddressLocal -IP '127.0.0.1' | Should Be $true
        }
    }
}

Describe 'Get-IPAddress' {
    Context 'Values that are for any IP' {
        It 'Returns any IP for no value' {
            (Get-IPAddress -IP $null).ToString() | Should Be '0.0.0.0'
        }

        It 'Returns any IP for empty value' {
            (Get-IPAddress -IP ([string]::Empty)).ToString() | Should Be '0.0.0.0'
        }

        It 'Returns any IP for asterisk' {
            (Get-IPAddress -IP '*').ToString() | Should Be '0.0.0.0'
        }
    }

    Context 'Values for IPv4' {
        It 'Returns IP for valid IP' {
            (Get-IPAddress -IP '127.0.0.1').ToString() | Should Be '127.0.0.1'
        }

        It 'Throws error for invalid IP' {
            { Get-IPAddress -IP '256.0.0.0' } | Should Throw 'invalid ip address'
        }
    }

    Context 'Values for IPv6' {
        It 'Returns IP for valid shorthand IP' {
            (Get-IPAddress -IP '[::]').ToString() | Should Be '::'
        }

        It 'Returns IP for valid IP' {
            (Get-IPAddress -IP '[0000:1111:2222:3333:4444:5555:6666:7777]').ToString() | Should Be '0:1111:2222:3333:4444:5555:6666:7777'
        }

        It 'Throws error for invalid IP' {
            { Get-IPAddress -IP '[]' } | Should Throw 'invalid ip address'
        }
    }
}