[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()
BeforeAll {
    Add-Type -AssemblyName "System.Net.Http" -ErrorAction SilentlyContinue
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}

Describe 'Get-PodeType' {
    Context 'No value supplied' {
        It 'Return the null' {
            Get-PodeType -Value $null | Should -Be $null
        }
    }

    Context 'Valid value supplied' {
        It 'String type' {
            $result = (Get-PodeType -Value [string]::Empty)
            $result | Should -Not -Be $null
            $result.Name | Should -Be 'string'
            $result.BaseName | Should -Be 'object'
        }

        It 'Boolean type' {
            $result = (Get-PodeType -Value $true)
            $result | Should -Not -Be $null
            $result.Name | Should -Be 'boolean'
            $result.BaseName | Should -Be 'valuetype'
        }

        It 'Int32 type' {
            $result = (Get-PodeType -Value 1)
            $result | Should -Not -Be $null
            $result.Name | Should -Be 'int32'
            $result.BaseName | Should -Be 'valuetype'
        }

        It 'Int64 type' {
            $result = (Get-PodeType -Value 1l)
            $result | Should -Not -Be $null
            $result.Name | Should -Be 'int64'
            $result.BaseName | Should -Be 'valuetype'
        }

        It 'Hashtable type' {
            $result = (Get-PodeType -Value @{})
            $result | Should -Not -Be $null
            $result.Name | Should -Be 'hashtable'
            $result.BaseName | Should -Be 'object'
        }

        It 'Array type' {
            $result = (Get-PodeType -Value @())
            $result | Should -Not -Be $null
            $result.Name | Should -Be 'object[]'
            $result.BaseName | Should -Be 'array'
        }

        It 'ScriptBlock type' {
            $result = (Get-PodeType -Value {})
            $result | Should -Not -Be $null
            $result.Name | Should -Be 'scriptblock'
            $result.BaseName | Should -Be 'object'
        }
    }
}

Describe 'Test-PodeIsEmpty' {
    Context 'No value is passed' {
        It 'Return true for no value' {
            Test-PodeIsEmpty | Should -Be $true
        }

        It 'Return true for null value' {
            Test-PodeIsEmpty -Value $null | Should -Be $true
        }
    }

    Context 'Empty value is passed' {
        It 'Return true for an empty arraylist' {
            Test-PodeIsEmpty -Value ([System.Collections.ArrayList]::new()) | Should -Be $true
        }

        It 'Return true for an empty array' {
            Test-PodeIsEmpty -Value @() | Should -Be $true
        }

        It 'Return true for an empty hashtable' {
            Test-PodeIsEmpty -Value @{} | Should -Be $true
        }

        It 'Return true for an empty string' {
            Test-PodeIsEmpty -Value ([string]::Empty) | Should -Be $true
        }

        It 'Return true for a whitespace string' {
            Test-PodeIsEmpty -Value '  ' | Should -Be $true
        }

        It 'Return true for an empty scriptblock' {
            Test-PodeIsEmpty -Value {} | Should -Be $true
        }
    }

    Context 'Valid value is passed' {
        It 'Return false for a string' {
            Test-PodeIsEmpty -Value 'test' | Should -Be $false
        }

        It 'Return false for a number' {
            Test-PodeIsEmpty -Value 1 | Should -Be $false
        }

        It 'Return false for an array' {
            Test-PodeIsEmpty -Value @('test') | Should -Be $false
        }

        It 'Return false for a hashtable' {
            Test-PodeIsEmpty -Value @{'key' = 'value'; } | Should -Be $false
        }

        It 'Return false for a scriptblock' {
            Test-PodeIsEmpty -Value { write-host '' } | Should -Be $false
        }
    }
}

Describe 'Get-PodePSVersionTable' {
    It 'Returns valid hashtable' {
        $table = Get-PodePSVersionTable
        $table | Should -Not -Be $null
        $table | Should -BeOfType System.Collections.Hashtable
    }
}

Describe 'Test-PodeIsUnix' {
    It 'Returns false for non-unix' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Windows' } }
        Test-PodeIsUnix | Should -Be $false
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for unix' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Unix' } }
        Test-PodeIsUnix | Should -Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }
}

Describe 'Test-PodeIsWindows' {
    It 'Returns false for non-windows' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Unix' } }
        Test-PodeIsWindows | Should -Be $false
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for windows and desktop' {
        Mock Get-PodePSVersionTable { return @{ 'PSEdition' = 'Desktop' } }
        Test-PodeIsWindows | Should -Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for windows and core' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Win32NT'; 'PSEdition' = 'Core' } }
        Test-PodeIsWindows | Should -Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }
}

Describe 'Test-PodeIsPSCore' {
    It 'Returns false for non-core' {
        Mock Get-PodePSVersionTable { return @{ 'PSEdition' = 'Desktop' } }
        Test-PodeIsPSCore | Should -Be $false
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for unix' {
        Mock Get-PodePSVersionTable { return @{ 'PSEdition' = 'Core' } }
        Test-PodeIsPSCore | Should -Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }
}

Describe 'Get-PodeHostIPRegex' {
    It 'Returns valid Hostname regex' {
        Get-PodeHostIPRegex -Type Hostname | Should -Be '(?<host>(([a-z]|\*\.)(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])+))'
    }

    It 'Returns valid IP regex' {
        Get-PodeHostIPRegex -Type IP | Should -Be '(?<host>(\[?([a-f0-9]*\:){1,}[a-f0-9]*((\d+\.){3}\d+)?\]?|((\d+\.){3}\d+)|\*|all))'
    }

    It 'Returns valid IP and Hostname regex' {
        Get-PodeHostIPRegex -Type Both | Should -Be '(?<host>(\[?([a-f0-9]*\:){1,}[a-f0-9]*((\d+\.){3}\d+)?\]?|((\d+\.){3}\d+)|\*|all|([a-z]|\*\.)(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])+))'
    }
}

Describe 'Get-PodePortRegex' {
    It 'Returns valid port regex' {
        Get-PodePortRegex | Should -Be '(?<port>\d+)'
    }
}

Describe 'Test-PodeIPAddress' {
    Context 'Values that are for any IP' {
        It 'Returns true for no value' {
            Test-PodeIPAddress -IP $null | Should -Be $true
        }

        It 'Returns true for empty value' {
            Test-PodeIPAddress -IP ([string]::Empty) | Should -Be $true
        }

        It 'Returns true for asterisk' {
            Test-PodeIPAddress -IP '*' | Should -Be $true
        }

        It 'Returns true for all' {
            Test-PodeIPAddress -IP 'all' | Should -Be $true
        }
    }

    Context 'Values for Hostnames' {
        It 'Returns true for valid Hostname' {
            Test-PodeIPAddress -IP 'foo.com' | Should -Be $true
        }

        It 'Returns false for invalid Hostname' {
            Test-PodeIPAddress -IP '~fake.net' | Should -Be $false
        }
    }

    Context 'Values for IPv4' {
        It 'Returns true for valid IP' {
            Test-PodeIPAddress -IP '127.0.0.1' | Should -Be $true
        }

        It 'Returns false for invalid IP' {
            Test-PodeIPAddress -IP '256.0.0.0' | Should -Be $false
        }
    }

    Context 'Values for IPv6' {
        It 'Returns true for valid shorthand IP' {
            Test-PodeIPAddress -IP '[::]' | Should -Be $true
        }

        It 'Returns true for valid IP' {
            Test-PodeIPAddress -IP '[0000:1111:2222:3333:4444:5555:6666:7777]' | Should -Be $true
        }

        It 'Returns false for invalid IP' {
            Test-PodeIPAddress -IP '[]' | Should -Be $false
        }
    }
}

Describe 'ConvertTo-PodeIPAddress' {
    Context 'Null values' {
        It 'Throws error for null' {
            { ConvertTo-PodeIPAddress -Address $null } | Should -Throw -ErrorId 'ParameterArgumentValidationError,ConvertTo-PodeIPAddress'
        }
    }

    Context 'Valid parameters' {
        It 'Returns IPAddress from IPEndpoint' {
            $_a = [System.Net.IPAddress]::Parse('127.0.0.1')
            $addr = ConvertTo-PodeIPAddress -Address ([System.Net.IPEndpoint]::new($_a, 8080))
            $addr | Should -Not -Be $null
            $addr.ToString() | Should -Be '127.0.0.1'
        }

        It 'Returns IPAddress from Endpoint' {
            $_a = [System.Net.IPAddress]::Parse('127.0.0.1')
            $_a = [System.Net.IPEndpoint]::new($_a, 8080)
            $addr = ConvertTo-PodeIPAddress -Address ([System.Net.Endpoint]$_a)
            $addr | Should -Not -Be $null
            $addr.ToString() | Should -Be '127.0.0.1'
        }
    }
}

Describe 'Test-PodeIPAddressLocal' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressLocal -IP ([string]::Empty) } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed,Test-PodeIPAddressLocal'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressLocal -IP $null } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed,Test-PodeIPAddressLocal'
        }
    }

    Context 'Values not localhost' {
        It 'Returns false for non-localhost IP' {
            Test-PodeIPAddressLocal -IP '192.168.10.10' | Should -Be $false
        }
    }

    Context 'Values that are localhost' {
        It 'Returns true for 127.0.0.1' {
            Test-PodeIPAddressLocal -IP '127.0.0.1' | Should -Be $true
        }

        It 'Returns true for localhost' {
            Test-PodeIPAddressLocal -IP 'localhost' | Should -Be $true
        }
    }
}

Describe 'Test-PodeIPAddressLocalOrAny' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressLocalOrAny -IP ([string]::Empty) } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed,Test-PodeIPAddressLocalOrAny'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressLocalOrAny -IP $null } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed,Test-PodeIPAddressLocalOrAny'
        }
    }

    Context 'Values not localhost' {
        It 'Returns false for non-localhost IP' {
            Test-PodeIPAddressLocalOrAny -IP '192.168.10.10' | Should -Be $false
        }
    }

    Context 'Values that are localhost' {
        It 'Returns true for 0.0.0.0' {
            Test-PodeIPAddressLocalOrAny -IP '0.0.0.0' | Should -Be $true
        }

        It 'Returns true for asterisk' {
            Test-PodeIPAddressLocalOrAny -IP '*' | Should -Be $true
        }

        It 'Returns true for all' {
            Test-PodeIPAddressLocalOrAny -IP 'all' | Should -Be $true
        }

        It 'Returns true for 127.0.0.1' {
            Test-PodeIPAddressLocalOrAny -IP '127.0.0.1' | Should -Be $true
        }
    }
}

Describe 'Test-PodeIPAddressAny' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressAny -IP ([string]::Empty) } | Should -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed,Test-PodeIPAddressAny'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressAny -IP $null } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorEmptyStringNotAllowed,Test-PodeIPAddressAny'
        }
    }

    Context 'Values not any' {
        It 'Returns false for non-any IP' {
            Test-PodeIPAddressAny -IP '192.168.10.10' | Should -Be $false
        }
    }

    Context 'Values that are any' {
        It 'Returns true for 0.0.0.0' {
            Test-PodeIPAddressAny -IP '0.0.0.0' | Should -Be $true
        }

        It 'Returns true for asterisk' {
            Test-PodeIPAddressAny -IP '*' | Should -Be $true
        }

        It 'Returns true for all' {
            Test-PodeIPAddressAny -IP 'all' | Should -Be $true
        }
    }
}

Describe 'Get-PodeIPAddress' {
    Context 'Values that are for any IP' {
        It 'Returns any IP for no value' {
            (Get-PodeIPAddress -IP $null).ToString() | Should -Be '0.0.0.0'
        }

        It 'Returns any IP for empty value' {
            (Get-PodeIPAddress -IP ([string]::Empty)).ToString() | Should -Be '0.0.0.0'
        }

        It 'Returns any IP for asterisk' {
            (Get-PodeIPAddress -IP '*').ToString() | Should -Be '0.0.0.0'
        }

        It 'Returns any IP for all' {
            (Get-PodeIPAddress -IP 'all').ToString() | Should -Be '0.0.0.0'
        }
    }

    Context 'Values for Hostnames' {
        It 'Returns Hostname for valid Hostname' {
            (Get-PodeIPAddress -IP 'foo.com').ToString() | Should -Be 'foo.com'
        }

        It 'Throws error for invalid IP' {
            { Get-PodeIPAddress -IP '~fake.net' } | Should -Throw -ErrorId 'FormatException,Get-PodeIPAddress'
        }
    }

    Context 'Values for IPv4' {
        It 'Returns IP for valid IP' {
            (Get-PodeIPAddress -IP '127.0.0.1').ToString() | Should -Be '127.0.0.1'
        }

        It 'Throws error for invalid IP' {
            { Get-PodeIPAddress -IP '256.0.0.0' } | Should -Throw -ErrorId 'FormatException,Get-PodeIPAddress'
        }
    }

    Context 'Values for IPv6' {
        It 'Returns IP for valid shorthand IP' {
            (Get-PodeIPAddress -IP '[::]').ToString() | Should -Be '::'
        }

        It 'Returns IP for valid IP' {
            (Get-PodeIPAddress -IP '[0000:1111:2222:3333:4444:5555:6666:7777]').ToString() | Should -Be '0:1111:2222:3333:4444:5555:6666:7777'
        }

        It 'Throws error for invalid IP' {
            { Get-PodeIPAddress -IP '[]' } | Should -Throw -ErrorId 'FormatException,Get-PodeIPAddress'
        }
    }
}

Describe 'Test-PodeIPAddressInRange' {
    Context 'No parameters supplied' {
        It 'Throws error for no ip' {
            { Test-PodeIPAddressInRange -IP $null -LowerIP @{} -UpperIP @{} } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorNullNotAllowed,Test-PodeIPAddressInRange'
        }

        It 'Throws error for no lower ip' {
            { Test-PodeIPAddressInRange -IP @{} -LowerIP $null -UpperIP @{} } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorNullNotAllowed,Test-PodeIPAddressInRange'
        }

        It 'Throws error for no upper ip' {
            { Test-PodeIPAddressInRange -IP @{} -LowerIP @{} -UpperIP $null } | Should -Throw -ErrorId 'ParameterArgumentValidationErrorNullNotAllowed,Test-PodeIPAddressInRange'
        }
    }

    Context 'Valid parameters supplied' {
        It 'Returns false because families are different' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 4); 'Family' = 'different' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should -Be $false
        }

        It 'Returns false because ip is above range' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 11); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should -Be $false
        }

        It 'Returns false because ip is under range' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 1); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should -Be $false
        }

        It 'Returns true because ip is in range' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 4); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should -Be $true
        }

        It 'Returns false because ip is above range, bounds are same' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 11); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should -Be $false
        }

        It 'Returns false because ip is under range, bounds are same' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 1); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should -Be $false
        }

        It 'Returns true because ip is in range, bounds are same' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should -Be $true
        }
    }
}

Describe 'Test-PodeIPAddressIsSubnetMask' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressIsSubnetMask -IP ([string]::Empty) } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Test-PodeIPAddressIsSubnetMask'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressIsSubnetMask -IP $null } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Test-PodeIPAddressIsSubnetMask'
        }
    }

    Context 'Valid parameters' {
        It 'Returns false for non-subnet' {
            Test-PodeIPAddressIsSubnetMask -IP '127.0.0.1' | Should -Be $false
        }

        It 'Returns true for subnet' {
            Test-PodeIPAddressIsSubnetMask -IP '10.10.0.0/24' | Should -Be $true
        }
    }
}

Describe 'Get-PodeSubnetRange' {
    Context 'Valid parameter supplied' {
        It 'Returns valid subnet range' {
            $range = Get-PodeSubnetRange -SubnetMask '10.10.0.0/24'
            $range.Lower | Should -Be '10.10.0.0'
            $range.Upper | Should -Be '10.10.0.255'
            $range.Range | Should -Be '0.0.0.255'
            $range.Netmask | Should -Be '255.255.255.0'
            $range.IP | Should -Be '10.10.0.0'
        }
    }
}

Describe 'Resolve-PodeValue' {
    Context 'Valid values' {
        It 'Returns Value2 for False Check' {
            Resolve-PodeValue -Check $false -TrueValue 'test' -FalseValue 'hello' | Should -Be 'hello'
        }

        It 'Returns Value1 for True Check' {
            Resolve-PodeValue -Check $true -TrueValue 'test' -FalseValue 'hello' | Should -Be 'test'
        }
    }
}

Describe 'Get-PodeFileExtension' {
    Context 'Valid values' {
        It 'Returns extension for file' {
            Get-PodeFileExtension -Path 'test.txt' | Should -Be '.txt'
        }

        It 'Returns extension for file with no period' {
            Get-PodeFileExtension -Path 'test.txt' -TrimPeriod | Should -Be 'txt'
        }

        It 'Returns extension for path' {
            Get-PodeFileExtension -Path 'this/is/some/test.txt' | Should -Be '.txt'
        }

        It 'Returns extension for path with no period' {
            Get-PodeFileExtension -Path 'this/is/some/test.txt' -TrimPeriod | Should -Be 'txt'
        }
    }
}

Describe 'Get-PodeFileName' {
    Context 'Valid values' {
        It 'Returns name for file with extension' {
            Get-PodeFileName -Path 'test.txt' | Should -Be 'test.txt'
        }

        It 'Returns name for file with no period with extension' {
            Get-PodeFileName -Path 'test.txt' -WithoutExtension | Should -Be 'test'
        }

        It 'Returns name for path' {
            Get-PodeFileName -Path 'this/is/some/test.txt' | Should -Be 'test.txt'
        }

        It 'Returns name for path with no period with extension' {
            Get-PodeFileName -Path 'this/is/some/test.txt' -WithoutExtension | Should -Be 'test'
        }
    }
}

Describe 'Test-PodeValidNetworkFailure' {
    Context 'Valid values' {
        It 'Returns true for network name' {
            $ex = @{ 'Message' = 'the network name is no longer available for use' }
            Test-PodeValidNetworkFailure -Exception $ex | Should -Be $true
        }

        It 'Returns true for network connection' {
            $ex = @{ 'Message' = 'a nonexistent network connection was detected' }
            Test-PodeValidNetworkFailure -Exception $ex | Should -Be $true
        }

        It 'Returns true for network pipe' {
            $ex = @{ 'Message' = 'network connection fail: broken pipe' }
            Test-PodeValidNetworkFailure -Exception $ex | Should -Be $true
        }

        It 'Returns false for empty' {
            $ex = @{ 'Message' = '' }
            Test-PodeValidNetworkFailure -Exception $ex | Should -Be $false
        }

        It 'Returns false for null' {
            $ex = @{ 'Message' = $null }
            Test-PodeValidNetworkFailure -Exception $ex | Should -Be $false
        }
    }
}

Describe 'ConvertFrom-PodeRequestContent' {
    Context 'Valid values' {
        It 'Returns xml data' {
            $PodeContext = @{ 'Server' = @{ 'Type' = 'http'; 'BodyParsers' = @{} } }
            $value = '<root><value>test</value></root>'

            $result = ConvertFrom-PodeRequestContent -Request @{
                Body            = $value
                ContentEncoding = [System.Text.Encoding]::UTF8
            } -ContentType 'text/xml'

            $result.Data | Should -Not -Be $null
            $result.Data.root | Should -Not -Be $null
            $result.Data.root.value | Should -Be 'test'
        }

        It 'Returns json data' {
            $PodeContext = @{ 'Server' = @{ 'Type' = 'http'; 'BodyParsers' = @{} } }
            $value = '{ "value": "test" }'

            $result = ConvertFrom-PodeRequestContent -Request @{
                Body            = $value
                ContentEncoding = [System.Text.Encoding]::UTF8
            } -ContentType 'application/json'

            $result.Data | Should -Not -Be $null
            $result.Data.value | Should -Be 'test'
        }

        It 'Returns csv data' {
            $PodeContext = @{ 'Server' = @{ 'Type' = 'http'; 'BodyParsers' = @{} } }
            $value = "value`ntest"

            $result = ConvertFrom-PodeRequestContent -Request @{
                Body            = $value
                ContentEncoding = [System.Text.Encoding]::UTF8
            } -ContentType 'text/csv'

            $result | Should -Not -Be $null
            $result.Data[0].value | Should -Be 'test'
        }

        It 'Returns original data' {
            $PodeContext = @{ 'Server' = @{ 'Type' = 'http'; 'BodyParsers' = @{} } }
            $value = 'test'

            (ConvertFrom-PodeRequestContent -Request @{
                Body            = $value
                ContentEncoding = [System.Text.Encoding]::UTF8
            } -ContentType 'text/custom').Data | Should -Be 'test'
        }

        It 'Returns json data for azure-functions' {
            $PodeContext = @{ 'Server' = @{ 'ServerlessType' = 'AzureFunctions'; 'BodyParsers' = @{}; 'IsServerless' = $true } }

            $result = ConvertFrom-PodeRequestContent -Request @{
                'ContentEncoding' = [System.Text.Encoding]::UTF8
                'RawBody'         = '{ "value": "test" }'
            } -ContentType 'application/json'

            $result.Data | Should -Not -Be $null
            $result.Data.value | Should -Be 'test'
        }

        It 'Returns json data for aws-lambda' {
            $PodeContext = @{ 'Server' = @{ 'ServerlessType' = 'AwsLambda'; 'BodyParsers' = @{}; 'IsServerless' = $true } }

            $result = ConvertFrom-PodeRequestContent -Request @{
                'ContentEncoding' = [System.Text.Encoding]::UTF8
                'body'            = '{ "value": "test" }'
            } -ContentType 'application/json'

            $result.Data | Should -Not -Be $null
            $result.Data.value | Should -Be 'test'
        }
    }
}

Describe 'Test-PodePathIsFile' {
    Context 'Valid values' {
        It 'Returns true for a file' {
            Test-PodePathIsFile -Path './some/path/file.txt' | Should -Be $true
        }

        It 'Returns false for a directory' {
            Test-PodePathIsFile -Path './some/path/folder' | Should -Be $false
        }

        It 'Returns false for a wildcard' {
            Test-PodePathIsFile -Path './some/path/*' -FailOnWildcard | Should -Be $false
        }
    }
}

Describe 'Test-PodePathIsWildcard' {
    It 'Returns true for a wildcard' {
        Test-PodePathIsWildcard -Path './some/path/*' | Should -Be $true
    }

    It 'Returns false for no wildcard' {
        Test-PodePathIsWildcard -Path './some/path/folder' | Should -Be $false
    }
}

Describe 'Test-PodePathIsDirectory' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodePathIsDirectory -Path ([string]::Empty) } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Test-PodePathIsDirectory'
        }

        It 'Throws error for null' {
            { Test-PodePathIsDirectory -Path $null } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Test-PodePathIsDirectory'
        }
    }

    Context 'Valid values' {
        It 'Returns true for a directory' {
            Test-PodePathIsDirectory -Path './some/path/folder' | Should -Be $true
        }

        It 'Returns false for a file' {
            Test-PodePathIsDirectory -Path './some/path/file.txt' | Should -Be $false
        }

        It 'Returns false for a wildcard' {
            Test-PodePathIsDirectory -Path './some/path/*' -FailOnWildcard | Should -Be $false
        }
    }
}

Describe 'Remove-PodeEmptyItemsFromArray' {
    It 'Returns an empty array for no array passed' {
        Remove-PodeEmptyItemsFromArray @() | Should -Be @()
    }

    It 'Returns an empty array for an array of empty items' {
        Remove-PodeEmptyItemsFromArray @('', $null) | Should -Be @()
    }

    It 'Returns a single item array' {
        Remove-PodeEmptyItemsFromArray @('app', '', $null) | Should -Be @('app')
    }

    It 'Returns a multi item array' {
        Remove-PodeEmptyItemsFromArray @('app', 'test', '', $null) | Should -Be @('app', 'test')
    }
}

Describe 'Get-PodeEndpointInfo' {
    It 'Returns null for no endpoint' {
        Get-PodeEndpointInfo -Address ([string]::Empty) | Should -Be $null
    }

    It 'Throws an error for an invalid IP endpoint' {
        { Get-PodeEndpointInfo -Address '700.0.0.a' } | Should -Throw -ExpectedMessage ($PodeLocale.failedToParseAddressExceptionMessage -f  '700.0.0.a' ) #'*Failed to parse*'
    }

    It 'Throws an error for an out-of-range IP endpoint' {
        { Get-PodeEndpointInfo -Address '700.0.0.0' } | Should -Throw -ExpectedMessage ($PodeLocale.invalidIpAddressExceptionMessage -f '700.0.0.0' ) # '*The IP address supplied is invalid*'
    }

    It 'Throws an error for an invalid Hostname endpoint' {
        { Get-PodeEndpointInfo -Address '@test.host.com' } | Should -Throw -ExpectedMessage ($PodeLocale.failedToParseAddressExceptionMessage -f '@test.host.com') # '*Failed to parse*'
    }
}

Describe 'Test-PodeHostname' {
    It 'Returns true for a valid hostname' {
        Test-PodeHostname -Hostname 'test.host.com' | Should -Be $true
    }

    It 'Returns false for a valid hostname' {
        Test-PodeHostname -Hostname 'test.ho@st.com' | Should -Be $false
    }
}

Describe 'Remove-PodeEmptyItemsFromArray' {
    It 'Returns an empty array for no entries' {
        Remove-PodeEmptyItemsFromArray -Array @() | Should -Be @()
    }

    It 'Returns en empty array for an array with null entries' {
        Remove-PodeEmptyItemsFromArray -Array @($null) | Should -Be @()
    }

    It 'Filters out the null entries' {
        Remove-PodeEmptyItemsFromArray -Array @('bill', $null, 'bob') | Should -Be @('bill', 'bob')
    }

    It 'Returns an empty array for a null array' {
        Remove-PodeEmptyItemsFromArray -Array $null | Should -Be @()
    }
}

Describe 'Invoke-PodeScriptBlock' {
    It 'Runs scriptblock unscoped, unsplatted, no-args' {
        Invoke-PodeScriptBlock -ScriptBlock { return 7 } -Return | Should -Be 7
    }

    It 'Runs scriptblock unscoped, unsplatted, no-args, force closure for serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }
        Invoke-PodeScriptBlock -ScriptBlock { return 7 } -Return | Should -Be 7
    }

    It 'Runs scriptblock unscoped, unsplatted, args' {
        Invoke-PodeScriptBlock -ScriptBlock { param($i) return $i } -Arguments 5 -Return | Should -Be 5
    }

    It 'Runs scriptblock scoped, unsplatted, no-args' {
        Invoke-PodeScriptBlock -ScriptBlock { return 7 } -Scoped -Return | Should -Be 7
    }

    It 'Runs scriptblock scoped, unsplatted, args' {
        Invoke-PodeScriptBlock -ScriptBlock { param($i) return $i } -Scoped -Arguments 5 -Return | Should -Be 5
    }

    It 'Runs scriptblock unscoped, splatted, no-args' {
        Invoke-PodeScriptBlock -ScriptBlock { return 7 } -Splat -Return | Should -Be 7
    }

    It 'Runs scriptblock unscoped, splatted, args' {
        Invoke-PodeScriptBlock -ScriptBlock { param($i) return $i } -Splat -Arguments @(5) -Return | Should -Be 5
    }

    It 'Runs scriptblock scoped, splatted, no-args' {
        Invoke-PodeScriptBlock -ScriptBlock { return 7 } -Scoped -Splat -Return | Should -Be 7
    }

    It 'Runs scriptblock scoped, splatted, args' {
        Invoke-PodeScriptBlock -ScriptBlock { param($i) return $i } -Scoped -Splat -Arguments @(5) -Return | Should -Be 5
    }
}

Describe 'ConvertFrom-PodeNameValueToHashTable' {
    It 'Returns an empty hashtable for no collection' {
        $result = ConvertFrom-PodeNameValueToHashTable -Collection $null
        ($result -is [hashtable]) | Should -Be $true
        $result.Count | Should -Be 0
    }

    It 'Returns a hashtable from a NameValue collection' {
        $c = [System.Collections.Specialized.NameValueCollection]::new()
        $c.Add('colour', 'blue')

        $r = ConvertFrom-PodeNameValueToHashTable -Collection $c
        $r.GetType().Name | Should -Be 'Hashtable'
        $r.colour.GetType().Name | Should -Be 'string'
        $r.colour | Should -Be 'blue'
    }

    It 'Returns a hashtable from a value without key collection' {
        $c = [System.Web.HttpUtility]::ParseQueryString('?blue')

        $r = ConvertFrom-PodeNameValueToHashTable -Collection $c
        $r.GetType().Name | Should -Be 'Hashtable'
        $r.'' | Should -Be 'blue'
    }
}

Describe 'Get-PodeUrl' {
    It 'Returns a url from the web event' {
        $WebEvent = @{
            Endpoint = @{
                Protocol = 'http'
                Address  = 'foo.com/'
            }
            Path     = 'about'
        }

        Get-PodeUrl | Should -Be 'http://foo.com/about'
    }
}

Describe 'Convert-PodePathPatternToRegex' {
    It 'Convert a path to regex' {
        Convert-PodePathPatternToRegex -Path '/api*' | Should -Be '^[\\/]api.*?$'
    }

    It 'Convert a path to regex non-strict' {
        Convert-PodePathPatternToRegex -Path '/api*' -NotStrict | Should -Be '[\\/]api.*?'
    }

    It 'Convert a path to regex, but not slashes' {
        Convert-PodePathPatternToRegex -Path '/api*' -NotSlashes | Should -Be '^/api.*?$'
    }

    It 'Convert a path to regex, but not slashes and non-strict' {
        Convert-PodePathPatternToRegex -Path '/api*' -NotSlashes -NotStrict | Should -Be '/api.*?'
    }

    It 'Convert file to regex' {
        Convert-PodePathPatternToRegex -Path 'state.json' | Should -Be '^state\.json$'
    }

    It 'Convert file to regex non-strict' {
        Convert-PodePathPatternToRegex -Path 'state.json' -NotStrict | Should -Be 'state\.json'
    }

    It 'Convert empty to regex' {
        Convert-PodePathPatternToRegex -Path '' | Should -Be '^$'
    }

    It 'Convert empty to regex non-strict' {
        Convert-PodePathPatternToRegex -Path '' -NotStrict | Should -Be ''
    }

    It 'Convert extension wildcard to regex' {
        Convert-PodePathPatternToRegex -Path 'state.*' | Should -Be '^state\..*?$'
    }

    It 'Convert extension wildcard to regex non-strict' {
        Convert-PodePathPatternToRegex -Path 'state.*' -NotStrict | Should -Be 'state\..*?'
    }

    It 'Convert filename wildcard to regex' {
        Convert-PodePathPatternToRegex -Path '*.json' | Should -Be '^.*?\.json$'
    }

    It 'Convert filename wildcard to regex non-strict' {
        Convert-PodePathPatternToRegex -Path '*.json' -NotStrict | Should -Be '.*?\.json'
    }

    It 'Convert double wildcard to regex' {
        Convert-PodePathPatternToRegex -Path '*.*' | Should -Be '^.*?\..*?$'
    }

    It 'Convert double wildcard to regex non-strict' {
        Convert-PodePathPatternToRegex -Path '*.*' -NotStrict | Should -Be '.*?\..*?'
    }
}

Describe 'Convert-PodePathPatternsToRegex' {
    It 'Convert paths to regex' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') | Should -Be '^([\\/]api.*?|[\\/]users.*?)$'
    }

    It 'Convert paths to regex non-strict' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') -NotStrict | Should -Be '([\\/]api.*?|[\\/]users.*?)'
    }

    It 'Convert paths to regex, but not slashes' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') -NotSlashes | Should -Be '^(/api.*?|/users.*?)$'
    }

    It 'Convert paths to regex, but not slashes and non-strict' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') -NotSlashes -NotStrict | Should -Be '(/api.*?|/users.*?)'
    }

    It 'Convert paths to regex with empty' {
        Convert-PodePathPatternsToRegex -Paths @('', '/api*', '/users*') | Should -Be '^([\\/]api.*?|[\\/]users.*?)$'
    }

    It 'Convert paths to regex non-strict with empty' {
        Convert-PodePathPatternsToRegex -Paths @('', '/api*', '/users*') -NotStrict | Should -Be '([\\/]api.*?|[\\/]users.*?)'
    }

    It 'Convert paths to regex, but not slashes with empty' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '', '/users*') -NotSlashes | Should -Be '^(/api.*?|/users.*?)$'
    }

    It 'Convert paths to regex, but not slashes and non-strict with empty' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*', '') -NotSlashes -NotStrict | Should -Be '(/api.*?|/users.*?)'
    }

    It 'Convert empty to regex' {
        Convert-PodePathPatternsToRegex -Paths @('') | Should -Be $null
    }

    It 'Convert empty to regex' {
        Convert-PodePathPatternsToRegex -Paths @('', '') | Should -Be $null
    }

    It 'Convert extension wildcard to regex' {
        Convert-PodePathPatternsToRegex -Paths @('state.*') | Should -Be '^(state\..*?)$'
    }

    It 'Convert extension wildcard to regex non-strict' {
        Convert-PodePathPatternsToRegex -Paths @('state.*') -NotStrict | Should -Be '(state\..*?)'
    }

    It 'Convert filename wildcard to regex' {
        Convert-PodePathPatternsToRegex -Paths @('*.json') | Should -Be '^(.*?\.json)$'
    }

    It 'Convert filename wildcard to regex non-strict' {
        Convert-PodePathPatternsToRegex -Paths @('*.json') -NotStrict | Should -Be '(.*?\.json)'
    }

    It 'Convert double wildcard to regex' {
        Convert-PodePathPatternsToRegex -Paths @('*.*') | Should -Be '^(.*?\..*?)$'
    }

    It 'Convert double wildcard to regex non-strict' {
        Convert-PodePathPatternsToRegex -Paths @('*.*') -NotStrict | Should -Be '(.*?\..*?)'
    }
}

Describe 'ConvertFrom-PodeFile' {
    It 'Generates dynamic content' {
        $content = 'Value = $(1+1)'
        ConvertFrom-PodeFile -Content $content | Should -Be 'Value = 2'
    }

    It 'Generates dynamic content, using parameters' {
        $content = 'Value = $($data["number"])'
        ConvertFrom-PodeFile -Content $content -Data @{ 'number' = 3 } | Should -Be 'Value = 3'
    }
}

Describe 'Get-PodeRelativePath' {
    BeforeAll {
        $PodeContext = @{ 'Server' = @{ 'Root' = 'c:/' } }

        It 'Returns back a literal path' {
            Get-PodeRelativePath -Path 'c:/path' | Should -Be 'c:/path'
        } }

    It 'Returns path for literal path when resolving' {
        $PodeContext = @{
            Server = @{
                Root = $pwd.Path
            }
        }

        Get-PodeRelativePath -Path $pwd.Path -Resolve -JoinRoot | Should -Be $pwd.Path
    }

    It 'Returns back a relative path' {
        Get-PodeRelativePath -Path './path' | Should -Be './path'
    }

    It 'Returns path for a relative path when resolving' {
        $PodeContext = @{
            Server = @{
                Root = $pwd.Path
            }
        }

        Get-PodeRelativePath -Path '.\src' -Resolve -JoinRoot | Should -Be (Join-Path $pwd.Path 'src')
    }

    It 'Returns path for a relative path joined to default root' {
        Get-PodeRelativePath -Path './path' -JoinRoot | Should -Be 'c:/./path'
    }

    It 'Returns resolved path for a relative path joined to default root when resolving' {
        $PodeContext = @{
            Server = @{
                Root = $pwd.Path
            }
        }

        Get-PodeRelativePath -Path './src' -JoinRoot -Resolve | Should -Be (Join-Path $pwd.Path 'src')
    }

    It 'Returns path for a relative path joined to passed root' {
        Get-PodeRelativePath -Path './path' -JoinRoot -RootPath 'e:/' | Should -Be 'e:/./path'
    }

    It 'Throws error for path ot existing' {
        Mock Test-PodePath { return $false }
        { Get-PodeRelativePath -Path './path' -TestPath } | Should -Throw -ExpectedMessage ($PodeLocale.pathNotExistExceptionMessage -f './path') # '*The path does not exist*'
    }
}

Describe 'Get-PodeWildcardFile' {
    BeforeAll {
        Mock Get-PodeRelativePath { return $Path }
        Mock Get-ChildItem {
            $ext = [System.IO.Path]::GetExtension($Path)
            return @(@{ 'FullName' = "./file1$($ext)" })
        }
    }

    It 'Get files after adding a wildcard to a directory' {
        $result = @(Get-PodeWildcardFile -Path './path' -Wildcard '*.ps1')
        $result.Length | Should -Be 1
        $result[0] | Should -Be './file1.ps1'
    }

    It 'Get files for wildcard path' {
        $result = @(Get-PodeWildcardFile -Path './path/*.png')
        $result.Length | Should -Be 1
        $result[0] | Should -Be './file1.png'
    }

    It 'Returns null for non-wildcard path' {
        Get-PodeWildcardFile -Path './some/path/file.txt' | Should -Be $null
    }
}

Describe 'Test-PodeIsServerless' {
    It 'Returns true' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }
        Test-PodeIsServerless | Should -Be $true
    }

    It 'Returns false' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $false } }
        Test-PodeIsServerless | Should -Be $false
    }

    It 'Throws error if serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }
        { Test-PodeIsServerless -FunctionName 'FakeFunction' -ThrowError } | Should -Throw -ExpectedMessage ($PodeLocale.unsupportedFunctionInServerlessContextExceptionMessage -f 'FakeFunction') #'*not supported in a serverless*'
    }

    It 'Throws no error if not serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $false } }
        { Test-PodeIsServerless -FunctionName 'FakeFunction' -ThrowError } | Should -Not -Throw -ExpectedMessage ($PodeLocale.unsupportedFunctionInServerlessContextExceptionMessage -f 'FakeFunction') #'*not supported in a serverless*'
    }
}

Describe 'Close-PodeRunspace' {
    It 'Returns and does nothing if serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }
        Close-PodeRunspace -ClosePool
    }
}

Describe 'Close-PodeServerInternal' {
    BeforeAll {
        Mock Close-PodeRunspace { }
        Mock Stop-PodeFileMonitor { }
        Mock Close-PodeDisposable { }
        Mock Remove-PodePSDrive { }
        Mock Write-Host { } }

    It 'Closes out pode, but with no done flag' {
        $PodeContext = @{ 'Server' = @{ 'Types' = 'Server' } }
        Close-PodeServerInternal
        Assert-MockCalled Write-Host -Times 0 -Scope It
    }

    It 'Closes out pode, but with the done flag' {
        $PodeContext = @{ 'Server' = @{ 'Types' = 'Server' } }
        Close-PodeServerInternal -ShowDoneMessage
        Assert-MockCalled Write-Host -Times 1 -Scope It
    }

    It 'Closes out pode, but with no done flag if serverless' {
        $PodeContext = @{ 'Server' = @{ 'Types' = 'Server'; 'IsServerless' = $true } }
        Close-PodeServerInternal -ShowDoneMessage
        Assert-MockCalled Write-Host -Times 0 -Scope It
    }
}

Describe 'Get-PodeEndpointUrl' {
    It 'Returns default endpoint url' {
        $PodeContext = @{ Server = @{
                Endpoints = @{
                    Example1 = @{
                        Port         = 6000
                        Address      = '127.0.0.1'
                        FriendlyName = 'thing.com'
                        Hostname     = 'thing.com'
                        Protocol     = 'https'
                    }
                }
            }
        }

        Get-PodeEndpointUrl | Should -Be 'https://thing.com:6000'
    }

    It 'Returns a passed endpoint url' {
        $endpoint = @{
            Port         = 7000
            Address      = '127.0.0.1'
            FriendlyName = 'stuff.com'
            Hostname     = 'stuff.com'
            Protocol     = 'http'
        }

        Get-PodeEndpointUrl -Endpoint $endpoint | Should -Be 'http://stuff.com:7000'
    }

    It 'Returns a passed endpoint url, with default port for http' {
        $endpoint = @{
            Port         = 8080
            Address      = '127.0.0.1'
            FriendlyName = 'stuff.com'
            Hostname     = 'stuff.com'
            Protocol     = 'http'
        }

        Get-PodeEndpointUrl -Endpoint $endpoint | Should -Be 'http://stuff.com:8080'
    }

    It 'Returns a passed endpoint url, with default port for https' {
        $endpoint = @{
            Port         = 8443
            Address      = '127.0.0.1'
            FriendlyName = 'stuff.com'
            Hostname     = 'stuff.com'
            Protocol     = 'https'
        }

        Get-PodeEndpointUrl -Endpoint $endpoint | Should -Be 'https://stuff.com:8443'
    }

    It 'Returns a passed endpoint url, using raw url' {
        $endpoint = @{
            Url = 'https://stuff.com:8443'
        }

        Get-PodeEndpointUrl -Endpoint $endpoint | Should -Be 'https://stuff.com:8443'
    }
}

Describe 'Get-PodeCount' {
    Context 'Null' {
        It 'Null value' {
            Get-PodeCount $null | Should -Be 0
        }
    }
    Context 'String' {
        It 'Empty' {
            Get-PodeCount '' | Should -Be 0
        }

        It 'Whitespace' {
            Get-PodeCount ' ' | Should -Be 1
            Get-PodeCount '   ' | Should -Be 3
        }
    }

    Context 'Numbers' {
        It 'Number' {
            Get-PodeCount 2 | Should -Be 1
        }
    }

    Context 'Array' {
        It 'Empty' {
            Get-PodeCount @() | Should -Be 0
        }

        It 'One' {
            Get-PodeCount @(4) | Should -Be 1
            Get-PodeCount @('data') | Should -Be 1
            Get-PodeCount @(@(3)) | Should -Be 1
            Get-PodeCount @(@{}) | Should -Be 1
        }

        It 'Two' {
            Get-PodeCount @(4, 7) | Should -Be 2
            Get-PodeCount @('data', 9) | Should -Be 2
            Get-PodeCount @(@(3), @()) | Should -Be 2
            Get-PodeCount @(@{}, @{}) | Should -Be 2
        }
    }

    Context 'Hashtable' {
        It 'Empty' {
            Get-PodeCount @{} | Should -Be 0
        }

        It 'One' {
            Get-PodeCount @{'testElement1' = 4 } | Should -Be 1
            Get-PodeCount @{'testElement1' = 'test' } | Should -Be 1
            Get-PodeCount @{'testElement1' = @() } | Should -Be 1
            Get-PodeCount @{'testElement1' = @{'insideElement' = "won't count" } } | Should -Be 1
        }

        It 'Two' {
            Get-PodeCount @{'testElement1' = 4; 'testElement2' = 10 } | Should -Be 2
            Get-PodeCount @{'testElement1' = 'test'; 'testElement2' = 10 } | Should -Be 2
            Get-PodeCount @{'testElement1' = @(); 'testElement2' = @(9) } | Should -Be 2
            Get-PodeCount @{'testElement1' = @{'insideElement' = "won't count" }; 'testElement2' = @('testing') } | Should -Be 2
        }
    }
}

Describe 'Out-PodeHost' {
    BeforeAll {
        Mock Out-Default {}
    }
    It 'Writes a message to the Host by parameters' {
        Out-PodeHost -InputObject 'Hello'
        Assert-MockCalled Out-Default -Scope It -Times 1
    }

    It 'Writes a message to the Host by pipeline' {
        'Hello' | Out-PodeHost
        Assert-MockCalled Out-Default -Scope It -Times 1
    }

    It 'Writes a hashtable to the Host by pipeline' {
        @{ Name = 'Rick' } | Out-PodeHost
        Assert-MockCalled Out-Default -Scope It -Times 1
    }
}

Describe 'Remove-PodeNullKeysFromHashtable' {
    It 'Removes all null values keys' {
        $ht = @{
            Value1 = $null
            Value2 = @{
                Value3 = @()
                Value4 = $null
            }
        }

        $ht | Remove-PodeNullKeysFromHashtable

        $ht.ContainsKey('Value1') | Should -Be $false
        $ht.ContainsKey('Value2') | Should -Be $true
        $ht.Value2.ContainsKey('Value3') | Should -Be $true
        $ht.Value2.ContainsKey('Value4') | Should -Be $false
    }
}

Describe 'Get-PodeDefaultPort' {
    It 'Returns default port for http' {
        Get-PodeDefaultPort -Protocol Http | Should -Be 8080
    }

    It 'Returns default port for https' {
        Get-PodeDefaultPort -Protocol Https | Should -Be 8443
    }

    It 'Returns default port for smtp' {
        Get-PodeDefaultPort -Protocol Smtp | Should -Be 25
    }

    It 'Returns default port for smtps - implicit' {
        Get-PodeDefaultPort -Protocol Smtps -TlsMode Implicit | Should -Be 465
    }

    It 'Returns default port for smtps - explicit' {
        Get-PodeDefaultPort -Protocol Smtps -TlsMode Explicit | Should -Be 587
    }

    It 'Returns default port for tcp' {
        Get-PodeDefaultPort -Protocol Tcp | Should -Be 9001
    }

    It 'Returns default port for ws' {
        Get-PodeDefaultPort -Protocol Ws | Should -Be 9080
    }

    It 'Returns default port for wss' {
        Get-PodeDefaultPort -Protocol Wss | Should -Be 9443
    }
}

Describe 'Convert-PodeQueryStringToHashTable' {
    It 'Emty for no uri' {
        $result = Convert-PodeQueryStringToHashTable -Uri ([string]::Empty)
        $result.Count | Should -Be 0
    }

    It 'Emty for uri but no query' {
        $result = Convert-PodeQueryStringToHashTable -Uri '/api/users'
        $result.Count | Should -Be 0
    }

    It 'Hashtable for root query' {
        $result = Convert-PodeQueryStringToHashTable -Uri '/?Name=Bob'
        $result.Count | Should -Be 1
        $result['Name'] | Should -Be 'Bob'
    }

    It 'Hashtable for root query, no slash' {
        $result = Convert-PodeQueryStringToHashTable -Uri '?Name=Bob'
        $result.Count | Should -Be 1
        $result['Name'] | Should -Be 'Bob'
    }

    It 'Hashtable for root multi-query' {
        $result = Convert-PodeQueryStringToHashTable -Uri '/?Name=Bob&Age=42'
        $result.Count | Should -Be 2
        $result['Name'] | Should -Be 'Bob'
        $result['Age'] | Should -Be 42
    }

    It 'Hashtable for root multi-query, no slash' {
        $result = Convert-PodeQueryStringToHashTable -Uri '?Name=Bob&Age=42'
        $result.Count | Should -Be 2
        $result['Name'] | Should -Be 'Bob'
        $result['Age'] | Should -Be 42
    }

    It 'Hashtable for non-root query' {
        $result = Convert-PodeQueryStringToHashTable -Uri '/api/user?Name=Bob'
        $result.Count | Should -Be 1
        $result['Name'] | Should -Be 'Bob'
    }

    It 'Hashtable for non-root multi-query' {
        $result = Convert-PodeQueryStringToHashTable -Uri '/api/user?Name=Bob&Age=42'
        $result.Count | Should -Be 2
        $result['Name'] | Should -Be 'Bob'
        $result['Age'] | Should -Be 42
    }

    It 'Hashtable for non-root multi-query, end slash' {
        $result = Convert-PodeQueryStringToHashTable -Uri '/api/user/?Name=Bob&Age=42'
        $result.Count | Should -Be 2
        $result['Name'] | Should -Be 'Bob'
        $result['Age'] | Should -Be 42
    }
}

Describe 'ConvertFrom-PodeHeaderQValue' {
    It 'Returns empty' {
        $result = ConvertFrom-PodeHeaderQValue -Value ''
        $result.Count | Should -Be 0
    }

    It 'Returns values default to 1' {
        $result = ConvertFrom-PodeHeaderQValue -Value 'gzip,deflate'
        $result.Count | Should -Be 2

        $result['gzip'] | Should -Be 1.0
        $result['deflate'] | Should -Be 1.0
    }

    It 'Returns values with set quality' {
        $result = ConvertFrom-PodeHeaderQValue -Value 'gzip;q=0.1,deflate;q=0.8'
        $result.Count | Should -Be 2

        $result['gzip'] | Should -Be 0.1
        $result['deflate'] | Should -Be 0.8
    }

    It 'Returns values with mix' {
        $result = ConvertFrom-PodeHeaderQValue -Value 'gzip,deflate;q=0.8,identity;q=0'
        $result.Count | Should -Be 3

        $result['gzip'] | Should -Be 1.0
        $result['deflate'] | Should -Be 0.8
        $result['identity'] | Should -Be 0
    }
}

Describe 'Get-PodeAcceptEncoding' {
    BeforeEach {
        $PodeContext = @{
            Server = @{
                Web         = @{ Compression = @{ Enabled = $true } }
                Compression = @{ Encodings = @('gzip', 'deflate', 'x-gzip') }
            }
        } }

    It 'Returns empty for no encoding' {
        Get-PodeAcceptEncoding -AcceptEncoding '' | Should -Be ''
    }

    It 'Returns empty when disabled' {
        $PodeContext.Server.Web.Compression.Enabled = $false
        Get-PodeAcceptEncoding -AcceptEncoding '' | Should -Be ''
    }

    It 'Returns first encoding for all default' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'gzip,deflate' | Should -Be 'gzip'
    }

    It 'Returns gzip for older x-gzip' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'x-gzip' | Should -Be 'gzip'
    }

    It 'Returns empty if no encoding matches' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'br,compress' | Should -Be ''
    }

    It 'Returns empty if no encoding matches, and 1 encoding is disabled' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'br,compress,gzip;q=0' | Should -Be ''
    }

    It 'Returns encoding when no other encoding matches, and 1 encoding matches' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'br,compress,gzip' | Should -Be 'gzip'
    }

    It 'Returns highest encoding when weighted' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'gzip;q=0.1,deflate' | Should -Be 'deflate'
    }

    It 'Returns highest encoding when weighted, and identity disabled' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'gzip;q=0.1,deflate,identity;q=0' | Should -Be 'deflate'
    }

    It 'Returns encoding even when none match, and identity disabled' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'br,identity;q=0' | Should -Be ''
    }

    It 'Errors when no encoding matches, and identity disabled' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        { Get-PodeAcceptEncoding -AcceptEncoding 'br,identity;q=0' -ThrowError } | Should -Throw -ExceptionType 'System.Net.Http.HttpRequestException'
    }

    It 'Errors when no encoding matches, and wildcard disabled' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        { Get-PodeAcceptEncoding -AcceptEncoding 'br,*;q=0' -ThrowError } | Should -Throw -ExceptionType 'System.Net.Http.HttpRequestException'
    }

    It 'Returns empty if identity is allowed, but wildcard disabled' {
        $PodeContext.Server.Web.Compression.Enabled = $true
        Get-PodeAcceptEncoding -AcceptEncoding 'identity,*;q=0' | Should -Be ''
    }
}

Describe 'Get-PodeTransferEncoding' {
    $PodeContext = @{
        Server = @{
            Compression = @{ Encodings = @('gzip', 'deflate', 'x-gzip') }
        }
    }

    It 'Returns empty for no encoding' {
        Get-PodeTransferEncoding -TransferEncoding '' | Should -Be ''
    }

    It 'Returns empty when just chunked' {
        Get-PodeTransferEncoding -TransferEncoding 'chunked' | Should -Be ''
    }

    It 'Returns first encoding that matches' {
        Get-PodeTransferEncoding -TransferEncoding 'gzip,deflate' | Should -Be 'gzip'
    }

    It 'Returns encoding when chunked' {
        Get-PodeTransferEncoding -TransferEncoding 'gzip,chunked' | Should -Be 'gzip'
        Get-PodeTransferEncoding -TransferEncoding 'chunked,gzip' | Should -Be 'gzip'
    }

    It 'Returns first invalid encoding when none match' {
        Get-PodeTransferEncoding -TransferEncoding 'compress,chunked' | Should -Be 'compress'
    }

    It 'Errors when no encoding matches' {
        { Get-PodeTransferEncoding -TransferEncoding 'compress,chunked' -ThrowError } | Should -Throw -ExceptionType 'System.Net.Http.HttpRequestException'
    }
}

Describe 'Get-PodeEncodingFromContentType' {
    It 'Return utf8 for no type' {
        $enc = Get-PodeEncodingFromContentType -ContentType ''
        $enc.EncodingName | Should -Be 'Unicode (UTF-8)'
    }

    It 'Return utf8 for no charset in type' {
        $enc = Get-PodeEncodingFromContentType -ContentType 'application/json'
        $enc.EncodingName | Should -Be 'Unicode (UTF-8)'
    }

    It 'Return ascii when charset is set' {
        $enc = Get-PodeEncodingFromContentType -ContentType 'application/json;charset=ascii'
        $enc.EncodingName | Should -Be 'US-ASCII'
    }

    It 'Return utf8 when charset is set' {
        $enc = Get-PodeEncodingFromContentType -ContentType 'application/json;charset=utf-8'
        $enc.EncodingName | Should -Be 'Unicode (UTF-8)'
    }
}

Describe 'New-PodeCron' {
    It 'Returns a minutely expression' {
        New-PodeCron -Every Minute | Should -Be '* * * * *'
    }

    It 'Returns an hourly expression' {
        New-PodeCron -Every Hour | Should -Be '0 * * * *'
    }

    It 'Returns a daily expression (by day)' {
        New-PodeCron -Every Day | Should -Be '0 0 * * *'
    }

    It 'Returns a daily expression (by date)' {
        New-PodeCron -Every Date | Should -Be '0 0 * * *'
    }

    It 'Returns a monthly expression' {
        New-PodeCron -Every Month | Should -Be '0 0 1 * *'
    }

    It 'Returns a quarterly expression' {
        New-PodeCron -Every Quarter | Should -Be '0 0 1 1,4,7,10 *'
    }

    It 'Returns a yearly expression' {
        New-PodeCron -Every Year | Should -Be '0 0 1 1 *'
    }

    It 'Returns an expression for every 15mins' {
        New-PodeCron -Every Minute -Interval 15 | Should -Be '*/15 * * * *'
    }

    It 'Returns an expression for every tues/fri at 1am' {
        New-PodeCron -Every Day -Day Tuesday, Friday -Hour 1 | Should -Be '0 1 * * 2,5'
    }

    It 'Returns an expression for every 15th of the month' {
        New-PodeCron -Every Month -Date 15 | Should -Be '0 0 15 * *'
    }

    It 'Returns an expression for every other day, from the 2nd' {
        New-PodeCron -Every Date -Interval 2 -Date 2 | Should -Be '0 0 2/2 * *'
    }

    It 'Returns an expression for every june 1st' {
        New-PodeCron -Every Year -Month June | Should -Be '0 0 1 6 *'
    }

    It 'Returns an expression for every 15mins between 1am-5am' {
        New-PodeCron -Every Minute -Interval 15 -Hour 1, 2, 3, 4, 5 | Should -Be '*/15 1,2,3,4,5 * * *'
    }

    It 'Returns an expression for every hour of every monday' {
        New-PodeCron -Every Hour -Day Monday | Should -Be '0 * * * 1'
    }

    It 'Returns an expression for everyday at 5:15am' {
        New-PodeCron -Every Day -Hour 5 -Minute 15 | Should -Be '15 5 * * *'
    }

    It 'Throws an error for multiple Hours when using Interval' {
        { New-PodeCron -Every Hour -Hour 2, 4 -Interval 3 } | Should -Throw -ExpectedMessage ($PodeLocale.singleValueForIntervalExceptionMessage -f 'Hour') #'*only supply a single*'
    }

    It 'Throws an error for multiple Minutes when using Interval' {
        { New-PodeCron -Every Minute -Minute 2, 4 -Interval 15 } | Should -Throw -ExpectedMessage ($PodeLocale.singleValueForIntervalExceptionMessage -f 'Minute') #'*only supply a single*'
    }

    It 'Throws an error when using Interval without Every' {
        { New-PodeCron -Interval 3 } | Should -Throw -ExpectedMessage $PodeLocale.cannotSupplyIntervalWhenEveryIsNoneExceptionMessage #'*Cannot supply an interval*'
    }

    It 'Throws an error when using Interval for Every Quarter' {
        { New-PodeCron -Every Quarter -Interval 3 } | Should -Throw -ExpectedMessage $PodeLocale.cannotSupplyIntervalForQuarterExceptionMessage #Cannot supply interval value for every quarter.
    }

    It 'Throws an error when using Interval for Every Year' {
        { New-PodeCron -Every Year -Interval 3 } | Should -Throw -ExpectedMessage $PodeLocale.cannotSupplyIntervalForYearExceptionMessage #'Cannot supply interval value for every year'
    }
}


 


Describe 'ConvertTo-PodeYamlInternal Tests' {
    Context 'When converting basic types' {
        It 'Converts strings correctly' {

            $result = ConvertTo-PodeYamlInternal -InputObject 'hello world'
            $result | Should -Be 'hello world'
        }

        It 'Converts arrays correctly' {
            $result = ConvertTo-PodeYamlInternal -InputObject  @('one', 'two', 'three') -NoNewLine
            $expected = (@'
- one
- two
- three
'@)
            $result | Should -Be ($expected.Trim() -Replace "`r`n", "`n")
        }

        It 'Converts hashtables correctly' {
            $hashTable = [ordered]@{
                key1 = 'value1'
                key2 = 'value2'
            }
            $result = ConvertTo-PodeYamlInternal -InputObject $hashTable -NoNewLine
            $result | Should -Be "key1: value1`nkey2: value2"
        }
    }

    Context 'When converting complex objects' {
        It 'Handles nested hashtables' {
            $nestedHash = @{
                parent = @{
                    child = 'value'
                }
            }
            $result = ConvertTo-PodeYamlInternal -InputObject  $nestedHash -NoNewLine

            $result | Should -Be "parent: `n  child: value"
        }
    }

    Context 'Error handling' {
        It 'Returns empty string for null input' {
            $result = ConvertTo-PodeYamlInternal -InputObject $null
            $result | Should -Be ''
        }
    }
}
