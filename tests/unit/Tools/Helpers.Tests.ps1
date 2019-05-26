$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeType' {
    Context 'No value supplied' {
        It 'Return the null' {
            Get-PodeType -Value $null | Should Be $null
        }
    }

    Context 'Valid value supplied' {
        It 'String type' {
            $result = (Get-PodeType -Value [string]::Empty)
            $result | Should Not Be $null
            $result.Name | Should Be 'string'
            $result.BaseName | Should Be 'object'
        }

        It 'Boolean type' {
            $result = (Get-PodeType -Value $true)
            $result | Should Not Be $null
            $result.Name | Should Be 'boolean'
            $result.BaseName | Should Be 'valuetype'
        }

        It 'Int32 type' {
            $result = (Get-PodeType -Value 1)
            $result | Should Not Be $null
            $result.Name | Should Be 'int32'
            $result.BaseName | Should Be 'valuetype'
        }

        It 'Int64 type' {
            $result = (Get-PodeType -Value 1l)
            $result | Should Not Be $null
            $result.Name | Should Be 'int64'
            $result.BaseName | Should Be 'valuetype'
        }

        It 'Hashtable type' {
            $result = (Get-PodeType -Value @{})
            $result | Should Not Be $null
            $result.Name | Should Be 'hashtable'
            $result.BaseName | Should Be 'object'
        }

        It 'Array type' {
            $result = (Get-PodeType -Value @())
            $result | Should Not Be $null
            $result.Name | Should Be 'object[]'
            $result.BaseName | Should Be 'array'
        }

        It 'ScriptBlock type' {
            $result = (Get-PodeType -Value {})
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
        It 'Return true for an empty arraylist' {
            Test-Empty -Value ([System.Collections.ArrayList]::new()) | Should Be $true
        }

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

        It 'Return true for an empty scriptblock' {
            Test-Empty -Value {} | Should Be $true
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

        It 'Return false for a scriptblock' {
            Test-Empty -Value { write-host '' } | Should Be $false
        }
    }
}

Describe 'Get-PodePSVersionTable' {
    It 'Returns valid hashtable' {
        $table = Get-PodePSVersionTable
        $table | Should Not Be $null
        $table | Should BeOfType System.Collections.Hashtable
    }
}

Describe 'Test-IsUnix' {
    It 'Returns false for non-unix' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Windows' } }
        Test-IsUnix | Should Be $false
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for unix' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Unix' } }
        Test-IsUnix | Should Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }
}

Describe 'Test-IsWindows' {
    It 'Returns false for non-windows' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Unix' } }
        Test-IsWindows | Should Be $false
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for windows and desktop' {
        Mock Get-PodePSVersionTable { return @{ 'PSEdition' = 'Desktop' } }
        Test-IsWindows | Should Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for windows and core' {
        Mock Get-PodePSVersionTable { return @{ 'Platform' = 'Win32NT'; 'PSEdition' = 'Core' } }
        Test-IsWindows | Should Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }
}

Describe 'Test-IsPSCore' {
    It 'Returns false for non-core' {
        Mock Get-PodePSVersionTable { return @{ 'PSEdition' = 'Desktop' } }
        Test-IsPSCore | Should Be $false
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }

    It 'Returns true for unix' {
        Mock Get-PodePSVersionTable { return @{ 'PSEdition' = 'Core' } }
        Test-IsPSCore | Should Be $true
        Assert-MockCalled Get-PodePSVersionTable -Times 1
    }
}

Describe 'Get-PodeHostIPRegex' {
    It 'Returns valid Hostname regex' {
        Get-PodeHostIPRegex -Type Hostname | Should Be '(?<host>(([a-z]|\*\.)(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])+))'
    }

    It 'Returns valid IP regex' {
        Get-PodeHostIPRegex -Type IP | Should Be '(?<host>(\[[a-f0-9\:]+\]|((\d+\.){3}\d+)|\:\:\d+|\*|all))'
    }

    It 'Returns valid IP and Hostname regex' {
        Get-PodeHostIPRegex -Type Both | Should Be '(?<host>(\[[a-f0-9\:]+\]|((\d+\.){3}\d+)|\:\:\d+|\*|all|([a-z]|\*\.)(([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])\.)*([a-z0-9]|[a-z0-9][a-z0-9\-]*[a-z0-9])+))'
    }
}

Describe 'Get-PortRegex' {
    It 'Returns valid port regex' {
        Get-PortRegex | Should Be '(?<port>\d+)'
    }
}

Describe 'Test-PodeIPAddress' {
    Context 'Values that are for any IP' {
        It 'Returns true for no value' {
            Test-PodeIPAddress -IP $null | Should Be $true
        }

        It 'Returns true for empty value' {
            Test-PodeIPAddress -IP ([string]::Empty) | Should Be $true
        }

        It 'Returns true for asterisk' {
            Test-PodeIPAddress -IP '*' | Should Be $true
        }

        It 'Returns true for all' {
            Test-PodeIPAddress -IP 'all' | Should Be $true
        }
    }

    Context 'Values for Hostnames' {
        It 'Returns true for valid Hostname' {
            Test-PodeIPAddress -IP 'foo.com' | Should Be $true
        }

        It 'Returns false for invalid Hostname' {
            Test-PodeIPAddress -IP '~fake.net' | Should Be $false
        }
    }

    Context 'Values for IPv4' {
        It 'Returns true for valid IP' {
            Test-PodeIPAddress -IP '127.0.0.1' | Should Be $true
        }

        It 'Returns false for invalid IP' {
            Test-PodeIPAddress -IP '256.0.0.0' | Should Be $false
        }
    }

    Context 'Values for IPv6' {
        It 'Returns true for valid shorthand IP' {
            Test-PodeIPAddress -IP '[::]' | Should Be $true
        }

        It 'Returns true for valid IP' {
            Test-PodeIPAddress -IP '[0000:1111:2222:3333:4444:5555:6666:7777]' | Should Be $true
        }

        It 'Returns false for invalid IP' {
            Test-PodeIPAddress -IP '[]' | Should Be $false
        }
    }
}

Describe 'ConvertTo-PodeIPAddress' {
    Context 'Null values' {
        It 'Throws error for null' {
            { ConvertTo-PodeIPAddress -Endpoint $null } | Should Throw 'the argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Returns IPAddress from IPEndpoint' {
            $_a = [System.Net.IPAddress]::Parse('127.0.0.1')
            $addr = ConvertTo-PodeIPAddress -Endpoint ([System.Net.IPEndpoint]::new($_a, 8080))
            $addr | Should Not Be $null
            $addr.ToString() | Should Be '127.0.0.1'
        }

        It 'Returns IPAddress from Endpoint' {
            $_a = [System.Net.IPAddress]::Parse('127.0.0.1')
            $_a = [System.Net.IPEndpoint]::new($_a, 8080)
            $addr = ConvertTo-PodeIPAddress -Endpoint ([System.Net.Endpoint]$_a)
            $addr | Should Not Be $null
            $addr.ToString() | Should Be '127.0.0.1'
        }
    }
}

Describe 'Test-PodeIPAddressLocal' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressLocal -IP ([string]::Empty) } | Should Throw 'because it is an empty'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressLocal -IP $null } | Should Throw 'because it is an empty'
        }
    }

    Context 'Values not localhost' {
        It 'Returns false for non-localhost IP' {
            Test-PodeIPAddressLocal -IP '192.168.10.10' | Should Be $false
        }
    }

    Context 'Values that are localhost' {
        It 'Returns true for 127.0.0.1' {
            Test-PodeIPAddressLocal -IP '127.0.0.1' | Should Be $true
        }

        It 'Returns true for localhost' {
            Test-PodeIPAddressLocal -IP 'localhost' | Should Be $true
        }
    }
}

Describe 'Test-PodeIPAddressLocalOrAny' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressLocalOrAny -IP ([string]::Empty) } | Should Throw 'because it is an empty'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressLocalOrAny -IP $null } | Should Throw 'because it is an empty'
        }
    }

    Context 'Values not localhost' {
        It 'Returns false for non-localhost IP' {
            Test-PodeIPAddressLocalOrAny -IP '192.168.10.10' | Should Be $false
        }
    }

    Context 'Values that are localhost' {
        It 'Returns true for 0.0.0.0' {
            Test-PodeIPAddressLocalOrAny -IP '0.0.0.0' | Should Be $true
        }

        It 'Returns true for asterisk' {
            Test-PodeIPAddressLocalOrAny -IP '*' | Should Be $true
        }

        It 'Returns true for all' {
            Test-PodeIPAddressLocalOrAny -IP 'all' | Should Be $true
        }

        It 'Returns true for 127.0.0.1' {
            Test-PodeIPAddressLocalOrAny -IP '127.0.0.1' | Should Be $true
        }
    }
}

Describe 'Test-PodeIPAddressAny' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressAny -IP ([string]::Empty) } | Should Throw 'because it is an empty'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressAny -IP $null } | Should Throw 'because it is an empty'
        }
    }

    Context 'Values not any' {
        It 'Returns false for non-any IP' {
            Test-PodeIPAddressAny -IP '192.168.10.10' | Should Be $false
        }
    }

    Context 'Values that are any' {
        It 'Returns true for 0.0.0.0' {
            Test-PodeIPAddressAny -IP '0.0.0.0' | Should Be $true
        }

        It 'Returns true for asterisk' {
            Test-PodeIPAddressAny -IP '*' | Should Be $true
        }

        It 'Returns true for all' {
            Test-PodeIPAddressAny -IP 'all' | Should Be $true
        }
    }
}

Describe 'Get-PodeIPAddress' {
    Context 'Values that are for any IP' {
        It 'Returns any IP for no value' {
            (Get-PodeIPAddress -IP $null).ToString() | Should Be '0.0.0.0'
        }

        It 'Returns any IP for empty value' {
            (Get-PodeIPAddress -IP ([string]::Empty)).ToString() | Should Be '0.0.0.0'
        }

        It 'Returns any IP for asterisk' {
            (Get-PodeIPAddress -IP '*').ToString() | Should Be '0.0.0.0'
        }

        It 'Returns any IP for all' {
            (Get-PodeIPAddress -IP 'all').ToString() | Should Be '0.0.0.0'
        }
    }

    Context 'Values for Hostnames' {
        It 'Returns Hostname for valid Hostname' {
            (Get-PodeIPAddress -IP 'foo.com').ToString() | Should Be 'foo.com'
        }

        It 'Throws error for invalid IP' {
            { Get-PodeIPAddress -IP '~fake.net' } | Should Throw 'invalid ip address'
        }
    }

    Context 'Values for IPv4' {
        It 'Returns IP for valid IP' {
            (Get-PodeIPAddress -IP '127.0.0.1').ToString() | Should Be '127.0.0.1'
        }

        It 'Throws error for invalid IP' {
            { Get-PodeIPAddress -IP '256.0.0.0' } | Should Throw 'invalid ip address'
        }
    }

    Context 'Values for IPv6' {
        It 'Returns IP for valid shorthand IP' {
            (Get-PodeIPAddress -IP '[::]').ToString() | Should Be '::'
        }

        It 'Returns IP for valid IP' {
            (Get-PodeIPAddress -IP '[0000:1111:2222:3333:4444:5555:6666:7777]').ToString() | Should Be '0:1111:2222:3333:4444:5555:6666:7777'
        }

        It 'Throws error for invalid IP' {
            { Get-PodeIPAddress -IP '[]' } | Should Throw 'invalid ip address'
        }
    }
}

Describe 'Test-PodeIPAddressInRange' {
    Context 'No parameters supplied' {
        It 'Throws error for no ip' {
            { Test-PodeIPAddressInRange -IP $null -LowerIP @{} -UpperIP @{} } | Should Throw 'because it is null'
        }

        It 'Throws error for no lower ip' {
            { Test-PodeIPAddressInRange -IP @{} -LowerIP $null -UpperIP @{} } | Should Throw 'because it is null'
        }

        It 'Throws error for no upper ip' {
            { Test-PodeIPAddressInRange -IP @{} -LowerIP @{} -UpperIP $null } | Should Throw 'because it is null'
        }
    }

    Context 'Valid parameters supplied' {
        It 'Returns false because families are different' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 4); 'Family' = 'different' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should Be $false
        }

        It 'Returns false because ip is above range' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 11); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should Be $false
        }

        It 'Returns false because ip is under range' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 1); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should Be $false
        }

        It 'Returns true because ip is in range' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 4); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 2); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 10); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should Be $true
        }

        It 'Returns false because ip is above range, bounds are same' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 11); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should Be $false
        }

        It 'Returns false because ip is under range, bounds are same' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 1); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should Be $false
        }

        It 'Returns true because ip is in range, bounds are same' {
            $ip = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $lower = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            $upper = @{ 'Bytes' = @(127, 0, 0, 5); 'Family' = 'test' }
            Test-PodeIPAddressInRange -IP $ip -LowerIP $lower -UpperIP $upper | Should Be $true
        }
    }
}

Describe 'Test-PodeIPAddressIsSubnetMask' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodeIPAddressIsSubnetMask -IP ([string]::Empty) } | Should Throw 'argument is null or empty'
        }

        It 'Throws error for null' {
            { Test-PodeIPAddressIsSubnetMask -IP $null } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid parameters' {
        It 'Returns false for non-subnet' {
            Test-PodeIPAddressIsSubnetMask -IP '127.0.0.1' | Should Be $false
        }

        It 'Returns true for subnet' {
            Test-PodeIPAddressIsSubnetMask -IP '10.10.0.0/24' | Should Be $true
        }
    }
}

Describe 'Get-PodeSubnetRange' {
    Context 'Valid parameter supplied' {
        It 'Returns valid subnet range' {
            $range = Get-PodeSubnetRange -SubnetMask '10.10.0.0/24'
            $range.Lower | Should Be '10.10.0.0'
            $range.Upper | Should Be '10.10.0.255'
            $range.Range | Should Be '0.0.0.255'
            $range.Netmask | Should Be '255.255.255.0'
            $range.IP | Should Be '10.10.0.0'
        }
    }
}

Describe 'Iftet' {
    Context 'Valid values' {
        It 'Returns Value2 for False Check' {
            iftet -Check $false -Value1 'test' -Value2 'hello' | Should Be 'hello'
        }

        It 'Returns Value1 for True Check' {
            iftet -Check $true -Value1 'test' -Value2 'hello' | Should Be 'test'
        }
    }
}

Describe 'Get-PodeFileExtension' {
    Context 'Valid values' {
        It 'Returns extension for file' {
            Get-PodeFileExtension -Path 'test.txt' | Should Be '.txt'
        }

        It 'Returns extension for file with no period' {
            Get-PodeFileExtension -Path 'test.txt' -TrimPeriod | Should Be 'txt'
        }

        It 'Returns extension for path' {
            Get-PodeFileExtension -Path 'this/is/some/test.txt' | Should Be '.txt'
        }

        It 'Returns extension for path with no period' {
            Get-PodeFileExtension -Path 'this/is/some/test.txt' -TrimPeriod | Should Be 'txt'
        }
    }
}

Describe 'Get-PodeFileName' {
    Context 'Valid values' {
        It 'Returns name for file with extension' {
            Get-PodeFileName -Path 'test.txt' | Should Be 'test.txt'
        }

        It 'Returns name for file with no period with extension' {
            Get-PodeFileName -Path 'test.txt' -WithoutExtension | Should Be 'test'
        }

        It 'Returns name for path' {
            Get-PodeFileName -Path 'this/is/some/test.txt' | Should Be 'test.txt'
        }

        It 'Returns name for path with no period with extension' {
            Get-PodeFileName -Path 'this/is/some/test.txt' -WithoutExtension | Should Be 'test'
        }
    }
}

Describe 'Test-PodeValidNetworkFailure' {
    Context 'Valid values' {
        It 'Returns true for network name' {
            $ex = @{ 'Message' = 'the network name is no longer available for use' }
            Test-PodeValidNetworkFailure -Exception $ex | Should Be $true
        }

        It 'Returns true for network connection' {
            $ex = @{ 'Message' = 'a nonexistent network connection was detected' }
            Test-PodeValidNetworkFailure -Exception $ex | Should Be $true
        }

        It 'Returns true for network pipe' {
            $ex = @{ 'Message' = 'network connection fail: broken pipe' }
            Test-PodeValidNetworkFailure -Exception $ex | Should Be $true
        }

        It 'Returns false for empty' {
            $ex = @{ 'Message' = '' }
            Test-PodeValidNetworkFailure -Exception $ex | Should Be $false
        }

        It 'Returns false for null' {
            $ex = @{ 'Message' = $null }
            Test-PodeValidNetworkFailure -Exception $ex | Should Be $false
        }
    }
}

Describe 'ConvertFrom-PodeRequestContent' {
    Context 'Valid values' {
        It 'Returns xml data' {
            $value = '<root><value>test</value></root>'
            Mock Read-PodeStreamToEnd { return $value }

            $result = ConvertFrom-PodeRequestContent -Request @{
                'ContentEncoding' = [System.Text.Encoding]::UTF8;
            } -ContentType 'text/xml'

            $result.Data | Should Not Be $null
            $result.Data.root | Should Not Be $null
            $result.Data.root.value | Should Be 'test'
        }

        It 'Returns json data' {
            $value = '{ "value": "test" }'
            Mock Read-PodeStreamToEnd { return $value }

            $result = ConvertFrom-PodeRequestContent -Request @{
                'ContentEncoding' = [System.Text.Encoding]::UTF8;
            } -ContentType 'application/json'

            $result.Data | Should Not Be $null
            $result.Data.value | Should Be 'test'
        }

        It 'Returns csv data' {
            $value = "value`ntest"
            Mock Read-PodeStreamToEnd { return $value }

            $result = ConvertFrom-PodeRequestContent -Request @{
                'ContentEncoding' = [System.Text.Encoding]::UTF8;
            } -ContentType 'text/csv'

            $result | Should Not Be $null
            $result.Data[0].value | Should Be 'test'
        }

        It 'Returns original data' {
            $value = "test"
            Mock Read-PodeStreamToEnd { return $value }
            
            (ConvertFrom-PodeRequestContent -Request @{
                'ContentEncoding' = [System.Text.Encoding]::UTF8;
            } -ContentType 'text/custom').Data | Should Be 'test'
        }
    }
}

Describe 'Test-PodePathIsFile' {
    Context 'Valid values' {
        It 'Returns true for a file' {
            Test-PodePathIsFile -Path './some/path/file.txt' | Should Be $true
        }

        It 'Returns false for a directory' {
            Test-PodePathIsFile -Path './some/path/folder' | Should Be $false
        }

        It 'Returns false for a wildcard' {
            Test-PodePathIsFile -Path './some/path/*' -FailOnWildcard | Should Be $false
        }
    }
}

Describe 'Test-PodePathIsWildcard' {
        It 'Returns true for a wildcard' {
            Test-PodePathIsWildcard -Path './some/path/*' | Should Be $true
        }

        It 'Returns false for no wildcard' {
            Test-PodePathIsWildcard -Path './some/path/folder' | Should Be $false
        }
}

Describe 'Test-PodePathIsDirectory' {
    Context 'Null values' {
        It 'Throws error for empty' {
            { Test-PodePathIsDirectory -Path ([string]::Empty) } | Should Throw 'argument is null or empty'
        }

        It 'Throws error for null' {
            { Test-PodePathIsDirectory -Path $null } | Should Throw 'argument is null or empty'
        }
    }

    Context 'Valid values' {
        It 'Returns true for a directory' {
            Test-PodePathIsDirectory -Path './some/path/folder' | Should Be $true
        }

        It 'Returns false for a file' {
            Test-PodePathIsDirectory -Path './some/path/file.txt' | Should Be $false
        }

        It 'Returns false for a wildcard' {
            Test-PodePathIsDirectory -Path './some/path/*' -FailOnWildcard | Should Be $false
        }
    }
}

Describe 'Remove-PodeEmptyItemsFromArray' {
    It 'Returns an empty array for no array passed' {
        Remove-PodeEmptyItemsFromArray @() | Should Be @()
    }

    It 'Returns an empty array for an array of empty items' {
        Remove-PodeEmptyItemsFromArray @('', $null) | Should Be @()
    }

    It 'Returns a single item array' {
        Remove-PodeEmptyItemsFromArray @('app', '', $null) | Should Be @('app')
    }

    It 'Returns a multi item array' {
        Remove-PodeEmptyItemsFromArray @('app', 'test', '', $null) | Should Be @('app', 'test')
    }
}

Describe 'Join-PodePaths' {
    It 'Returns valid for 0 items' {
        Join-PodePaths @() | Should Be ([string]::Empty)
    }

    It 'Returns valid for 1 item' {
        Join-PodePaths @('this') | Should Be 'this'
    }

    It 'Returns valid for 2 items' {
        Join-PodePaths @('this', 'is') | Should Be (Join-Path 'this' 'is')
    }

    It 'Returns valid for 2+ items' {
        $result = (Join-Path (Join-Path (Join-Path 'this' 'is') 'a') 'path')
        Join-PodePaths @('this', 'is', 'a', 'path') | Should Be $result
    }
}

Describe 'Get-PodeEndpointInfo' {
    It 'Returns null for no endpoint' {
        Get-PodeEndpointInfo -Endpoint ([string]::Empty) | Should Be $null
    }

    It 'Throws an error for an invalid IP endpoint' {
        { Get-PodeEndpointInfo -Endpoint '700.0.0.a' } | Should Throw 'Failed to parse'
    }

    It 'Throws an error for an out-of-range IP endpoint' {
        { Get-PodeEndpointInfo -Endpoint '700.0.0.0' } | Should Throw 'The IP address supplied is invalid'
    }

    It 'Throws an error for an invalid Hostname endpoint' {
        { Get-PodeEndpointInfo -Endpoint '@test.host.com' } | Should Throw 'Failed to parse'
    }
}

Describe 'Test-PodeHostname' {
    It 'Returns true for a valid hostname' {
        Test-PodeHostname -Hostname 'test.host.com' | Should Be $true
    }

    It 'Returns false for a valid hostname' {
        Test-PodeHostname -Hostname 'test.ho@st.com' | Should Be $false
    }
}

Describe 'Remove-PodeEmptyItemsFromArray' {
    It 'Returns an empty array for no entries' {
        Remove-PodeEmptyItemsFromArray -Array @() | Should Be @()
    }

    It 'Returns en empty array for an array with null entries' {
        Remove-PodeEmptyItemsFromArray -Array @($null) | Should Be @()
    }

    It 'Filters out the null entries' {
        Remove-PodeEmptyItemsFromArray -Array @('bill', $null, 'bob') | Should Be @('bill', 'bob')
    }

    It 'Returns an empty array for a null array' {
        Remove-PodeEmptyItemsFromArray -Array $null | Should Be @()
    }
}

Describe 'Invoke-ScriptBlock' {
    It 'Runs scriptblock unscoped, unsplatted, no-args' {
        Invoke-ScriptBlock -ScriptBlock { return 7 } -Return | Should Be 7
    }

    It 'Runs scriptblock unscoped, unsplatted, args' {
        Invoke-ScriptBlock -ScriptBlock { param($i) return $i } -Arguments 5 -Return | Should Be 5
    }

    It 'Runs scriptblock scoped, unsplatted, no-args' {
        Invoke-ScriptBlock -ScriptBlock { return 7 } -Scoped -Return | Should Be 7
    }

    It 'Runs scriptblock scoped, unsplatted, args' {
        Invoke-ScriptBlock -ScriptBlock { param($i) return $i } -Scoped -Arguments 5 -Return | Should Be 5
    }

    It 'Runs scriptblock unscoped, splatted, no-args' {
        Invoke-ScriptBlock -ScriptBlock { return 7 } -Splat -Return | Should Be 7
    }

    It 'Runs scriptblock unscoped, splatted, args' {
        Invoke-ScriptBlock -ScriptBlock { param($i) return $i } -Splat -Arguments @(5) -Return | Should Be 5
    }

    It 'Runs scriptblock scoped, splatted, no-args' {
        Invoke-ScriptBlock -ScriptBlock { return 7 } -Scoped -Splat -Return | Should Be 7
    }

    It 'Runs scriptblock scoped, splatted, args' {
        Invoke-ScriptBlock -ScriptBlock { param($i) return $i } -Scoped -Splat -Arguments @(5) -Return | Should Be 5
    }
}

Describe 'ConvertFrom-PodeNameValueToHashTable' {
    It 'Returns null for no collection' {
        ConvertFrom-PodeNameValueToHashTable -Collection $null | Should Be $null
    }

    It 'Returns a hashtable from a NameValue collection' {
        $c = [System.Collections.Specialized.NameValueCollection]::new()
        $c.Add('colour', 'blue')

        $r = ConvertFrom-PodeNameValueToHashTable -Collection $c
        $r.GetType().Name | Should Be 'Hashtable'
        $r.colour | Should Be 'blue'
    }
}

Describe 'Get-PodeCertificate' {
    It 'Throws error as certificate does not exist' {
        Mock Get-ChildItem { return $null }
        { Get-PodeCertificate -Certificate 'name' } | Should Throw 'failed to find'
    }

    It 'Returns a certificate thumbprint' {
        Mock Get-ChildItem { return @(@{ 'Subject' = 'name'; 'Thumbprint' = 'some-thumbprint' }) }
        Get-PodeCertificate -Certificate 'name' | Should Be 'some-thumbprint'
    }
}

Describe 'Set-PodeCertificate' {
    It 'Throws an error for a non-windows machine' {
        Mock Test-IsWindows { return $false }
        Mock Write-Host { }

        Set-PodeCertificate -Address 'localhost' -Port 8080 -Certificate 'name' | Out-Null

        Assert-MockCalled Write-Host -Times 1 -Scope It
    }
}

Describe 'Get-PodeUrl' {
    It 'Returns a url from the web event' {
        $WebEvent = @{
            'Protocol' = 'http';
            'Endpoint' = 'foo.com/';
            'Path' = 'about'
        }

        Get-PodeUrl | Should Be 'http://foo.com/about'
    }
}

Describe 'Convert-PodePathPatternToRegex' {
    It 'Convert a path to regex' {
        Convert-PodePathPatternToRegex -Path '/api*' | Should Be '^[\\/]api.*?$'
    }

    It 'Convert a path to regex non-strict' {
        Convert-PodePathPatternToRegex -Path '/api*' -NotStrict | Should Be '[\\/]api.*?'
    }

    It 'Convert a path to regex, but not slashes' {
        Convert-PodePathPatternToRegex -Path '/api*' -NotSlashes | Should Be '^/api.*?$'
    }

    It 'Convert a path to regex, but not slashes and non-strict' {
        Convert-PodePathPatternToRegex -Path '/api*' -NotSlashes -NotStrict | Should Be '/api.*?'
    }
}

Describe 'Convert-PodePathPatternsToRegex' {
    It 'Convert paths to regex' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') | Should Be '^([\\/]api.*?|[\\/]users.*?)$'
    }

    It 'Convert paths to regex non-strict' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') -NotStrict | Should Be '([\\/]api.*?|[\\/]users.*?)'
    }

    It 'Convert paths to regex, but not slashes' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') -NotSlashes | Should Be '^(/api.*?|/users.*?)$'
    }

    It 'Convert paths to regex, but not slashes and non-strict' {
        Convert-PodePathPatternsToRegex -Paths @('/api*', '/users*') -NotSlashes -NotStrict | Should Be '(/api.*?|/users.*?)'
    }
}

Describe 'ConvertFrom-PodeFile' {
    It 'Generates dynamic content' {
        $content = 'Value = $(1+1)'
        ConvertFrom-PodeFile -Content $content | Should Be 'Value = 2'
    }

    It 'Generates dynamic content, using parameters' {
        $content = 'Value = $($data["number"])'
        ConvertFrom-PodeFile -Content $content -Data @{ 'number' = 3 } | Should Be 'Value = 3'
    }
}

Describe 'Test-PodePathIsRelative' {
    It 'Returns true for .' {
        Test-PodePathIsRelative -Path '.' | Should Be $true
    }

    It 'Returns true for ..' {
        Test-PodePathIsRelative -Path '..' | Should Be $true
    }

    It 'Returns true for relative file' {
        Test-PodePathIsRelative -Path './file.txt' | Should Be $true
    }

    It 'Returns true for relative folder' {
        Test-PodePathIsRelative -Path '../folder' | Should Be $true
    }

    It 'Returns false for literal windows path' {
        Test-PodePathIsRelative -Path 'c:/path' | Should Be $false
    }

    It 'Returns false for literal nix path' {
        Test-PodePathIsRelative -Path '/path' | Should Be $false
    }
}

Describe 'Get-PodeRelativePath' {
    $PodeContext = @{ 'Server' = @{ 'Root' = 'c:/' } }

    It 'Returns back a literal path' {
        Mock Test-PodePathIsRelative { return $false }
        Get-PodeRelativePath -Path 'c:/path' | Should Be 'c:/path'
    }

    It 'Returns null for non-existent literal path when resolving' {
        Mock Test-PodePathIsRelative { return $false }
        Mock Resolve-Path { return $null }
        Get-PodeRelativePath -Path 'c:/path' -Resolve | Should Be ([string]::Empty)
    }

    It 'Returns path for literal path when resolving' {
        Mock Test-PodePathIsRelative { return $false }
        Mock Resolve-Path { return @{ 'Path' = 'c:/path' } }
        Get-PodeRelativePath -Path 'c:/path' -Resolve | Should Be 'c:/path'
    }

    It 'Returns back a relative path' {
        Mock Test-PodePathIsRelative { return $true }
        Get-PodeRelativePath -Path './path' | Should Be './path'
    }

    It 'Returns null for a non-existent relative path when resolving' {
        Mock Test-PodePathIsRelative { return $true }
        Mock Resolve-Path { return $null }
        Get-PodeRelativePath -Path './path' -Resolve | Should Be ([string]::Empty)
    }

    It 'Returns path for a relative path when resolving' {
        Mock Test-PodePathIsRelative { return $true }
        Mock Resolve-Path { return @{ 'Path' = 'c:/path' } }
        Get-PodeRelativePath -Path './path' -Resolve | Should Be 'c:/path'
    }

    It 'Returns path for a relative path joined to default root' {
        Mock Test-PodePathIsRelative { return $true }
        Mock Join-Path { return 'c:/path' }
        Get-PodeRelativePath -Path './path' -JoinRoot | Should Be 'c:/path'
    }

    It 'Returns resolved path for a relative path joined to default root when resolving' {
        Mock Test-PodePathIsRelative { return $true }
        Mock Join-Path { return 'c:/path' }
        Mock Resolve-Path { return @{ 'Path' = 'c:/path' } }
        Get-PodeRelativePath -Path './path' -JoinRoot -Resolve | Should Be 'c:/path'
    }

    It 'Returns path for a relative path joined to passed root' {
        Mock Test-PodePathIsRelative { return $true }
        Mock Join-Path { return 'e:/path' }
        Get-PodeRelativePath -Path './path' -JoinRoot -RootPath 'e:/' | Should Be 'e:/path'
    }

    It 'Throws error for path ot existing' {
        Mock Test-PodePathIsRelative { return $false }
        Mock Test-PodePath { return $false }
        { Get-PodeRelativePath -Path './path' -TestPath } | Should Throw 'The path does not exist'
    }
}

Describe 'Get-PodeWildcardFiles' {
    Mock Get-PodeRelativePath { return $Path }
    Mock Get-ChildItem {
        $ext = [System.IO.Path]::GetExtension($Path)
        return @(@{ 'FullName' = "./file1$($ext)" })
    }

    It 'Get files after adding a wildcard to a directory' {
        $result = @(Get-PodeWildcardFiles -Path './path' -Wildcard '*.ps1')
        $result.Length | Should Be 1
        $result[0] | Should Be './file1.ps1'
    }

    It 'Get files for wildcard path' {
        $result = @(Get-PodeWildcardFiles -Path './path/*.png')
        $result.Length | Should Be 1
        $result[0] | Should Be './file1.png'
    }

    It 'Returns null for non-wildcard path' {
        Get-PodeWildcardFiles -Path './some/path/file.txt' | Should Be $null
    }
}