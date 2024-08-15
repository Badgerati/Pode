[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()
BeforeAll {
    Add-Type -AssemblyName 'System.Net.Http' -ErrorAction SilentlyContinue

    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
    if (!([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Pode' })) {
        $frameworkDescription = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        $loaded = $false
        if ($frameworkDescription -match '(\d+)\.(\d+)\.(\d+)') {
            $majorVersion = [int]$matches[1]

            for ($version = $majorVersion; $version -ge 6; $version--) {
                $dllPath = "$($src)/Libs/net$version.0/Pode.dll"
                if (Test-Path $dllPath) {
                    Add-Type -LiteralPath $dllPath -ErrorAction Stop
                    $loaded = $true
                    break
                }
            }
        }

        if (-not $loaded) {
            Add-Type -LiteralPath "$($src)/Libs/netstandard2.0/Pode.dll" -ErrorAction Stop
        }
    }
    function Compare-Hashtable {
        param (
            [hashtable]$Hashtable1,
            [hashtable]$Hashtable2
        )

        # Function to compare two hashtable values
        function Compare-Value($value1, $value2) {
            if ($value1 -is [hashtable] -and $value2 -is [hashtable]) {
                return Compare-Hashtable -Hashtable1 $value1 -Hashtable2 $value2
            }
            else {
                return $value1 -eq $value2
            }
        }

        $keys1 = $Hashtable1.Keys
        $keys2 = $Hashtable2.Keys

        # Check if both hashtables have the same keys
        if ($keys1.Count -ne $keys2.Count) {
            return $false
        }

        foreach ($key in $keys1) {
            if (-not $Hashtable2.ContainsKey($key)) {
                return $false
            }
            if ($Hashtable2[$key] -is [hashtable]) {
                if (-not (Compare-Hashtable -Hashtable1 $Hashtable1[$key] -Hashtable2 $Hashtable2[$key])){
                    return $false
                }
            }
            elseif (-not (Compare-Value $Hashtable1[$key] $Hashtable2[$key])) {
                return $false
            }
        }

        return $true
    }


     # Mocking the external function ConvertFrom-Yaml
     function ConvertFrom-Yaml   {
        return @{ openapi = '3.0.3'; info = @{ title = 'Async test - OpenAPI 3.0'; version = '0.0.1' }; paths = @{ '/task/{taskId}' = @{ get = @{ summary = 'Get Pode Task Info' } } } }
    }
}

Describe 'ConvertTo-PodeYaml Tests' {
    BeforeAll {
        $PodeContext = @{ Server = @{InternalCache = @{} } }
    }
    Context 'When converting basic types' {
        It 'Converts strings correctly' {
            $result = 'hello world' | ConvertTo-PodeYaml
            $result | Should -Be 'hello world'
        }

        It 'Converts arrays correctly' {
            $result = @('one', 'two', 'three') | ConvertTo-PodeYaml
            $expected = (@'
- one
- two
- three
'@)
            $result | Should -Be $expected.Trim()# -Replace "`r`n", "`n")
        }

        It 'Converts hashtables correctly' {
            $hashTable = [ordered]@{
                key1 = 'value1'
                key2 = 'value2'
            }
            $result = $hashTable | ConvertTo-PodeYaml
            $result | Should -Be "key1: value1$([Environment]::NewLine)key2: value2"
        }
    }

    Context 'When converting complex objects' {
        It 'Handles nested hashtables' {
            $nestedHash = @{
                parent = @{
                    child = 'value'
                }
            }
            $result = $nestedHash | ConvertTo-PodeYaml

            $result | Should -Be "parent: $([Environment]::NewLine)  child: value"
        }
    }

    Context 'Error handling' {
        It 'Returns empty string for null input' {
            $result = $null | ConvertTo-PodeYaml
            $result | Should -Be ''
        }
    }
}

# Requires -Version 5.5

Describe 'ConvertFrom-PodeYaml test' {

    Context 'YAML Module' {
        BeforeAll {
            # Mocking the internal function ConvertFrom-PodeYamlInternal
            Mock -CommandName ConvertFrom-PodeYamlInternal -MockWith {
                return [ordered]@{ openapi = '3.0.3'; info = @{ title = 'Async test - OpenAPI 3.0'; version = '0.0.1' }; paths = @{ '/task/{taskId}' = @{ get = @{ summary = 'Get Pode Task Info' } } } }
            }

            # Mocking the external function ConvertFrom-Yaml
            Mock -CommandName ConvertFrom-Yaml -MockWith {
                return [ordered]@{ openapi = '3.0.3'; info = @{ title = 'Async test - OpenAPI 3.0'; version = '0.0.1' }; paths = @{ '/task/{taskId}' = @{ get = @{ summary = 'Get Pode Task Info' } } } }
            }

            # Mocking the Test-PodeModuleInstalled function
            Mock -CommandName Test-PodeModuleInstalled -MockWith { return $false }
        }
        Context 'When no YAML module is available' {
            BeforeAll {
                $PodeContext = @{
                    Server = @{
                        Web           = @{
                            OpenApi = @{
                                UsePodeYamlInternal = $true
                            }
                        }
                        InternalCache = @{
                            YamlModuleImported = $false
                        }
                    }
                }
            }

            It 'Should use the internal converter if no YAML module is available' {
                $yamlString = @'
            openapi: 3.0.3
            info:
                title: Async test - OpenAPI 3.0
                version: 0.0.1
            paths:
                /task/{taskId}:
                    get:
                        summary: Get Pode Task Info
'@

                $result = ConvertFrom-PodeYaml -InputObject $yamlString

               # Assert-MockCalled -CommandName ConvertFrom-PodeYamlInternal -Times 1
                Assert-MockCalled -CommandName ConvertFrom-Yaml -Times 0
                $result | Should -BeOfType 'System.Collections.Specialized.OrderedDictionary'
                $result.openapi | Should -Be '3.0.3'
            }
        }

        Context 'When a YAML module is available' {
            BeforeAll {
                $PodeContext = @{
                    Server = @{
                        Web           = @{
                            OpenApi = @{
                                UsePodeYamlInternal = $false
                            }
                        }
                        InternalCache = @{
                            YamlModuleImported = $true
                        }
                    }
                }

            }

            It 'Should use the external converter if a YAML module is available' {
                $yamlString = @'
            openapi: 3.0.3
            info:
                title: Async test - OpenAPI 3.0
                version: 0.0.1
            paths:
                /task/{taskId}:
                    get:
                        summary: Get Pode Task Info
'@

                $result = ConvertFrom-PodeYaml -InputObject $yamlString

                Assert-MockCalled -CommandName ConvertFrom-Yaml -Times 1
              #  Assert-MockCalled -CommandName ConvertFrom-PodeYamlInternal -Times 0
                $result | Should -BeOfType 'System.Collections.Specialized.OrderedDictionary'
                $result.openapi | Should -Be '3.0.3'
            }
        }


    }

    Context 'When an objects is provided' {
        BeforeAll {
            $PodeContext = @{
                Server = @{
                    Web           = @{
                        OpenApi = @{
                            UsePodeYamlInternal = $true
                        }
                    }
                    InternalCache = @{
                        YamlModuleImported = $false
                    }
                }
            }
        }

        It 'single input object' {
            $yamlString1 = @'
            openapi: 3.0.3
            info:
                title: Async test - OpenAPI 3.0
                version: 0.0.1
            paths:
                /task/{taskId}:
                    get:
                        summary: Get Pode Task Info
'@



            $result = $yamlString1 | ConvertFrom-PodeYaml
            $result | Should -BeOfType 'System.Collections.Specialized.OrderedDictionary'
            Compare-Hashtable  -Hashtable1 $result -Hashtable2 ( @{
                    openapi = '3.0.3'
                    info    = @{
                        title   = 'Async test - OpenAPI 3.0'
                        version = '0.0.1'
                    }
                    paths   = @{
                        '/task/{taskId}' = @{
                            get = @{
                                summary = 'Get Pode Task Info'
                            }
                        }
                    }
                }) | Should -BeTrue
        }
    }

    Context 'When multiple pipeline objects are provided' {
        BeforeAll {
            $PodeContext = @{
                Server = @{
                    Web           = @{
                        OpenApi = @{
                            UsePodeYamlInternal = $true
                        }
                    }
                    InternalCache = @{
                        YamlModuleImported = $false
                    }
                }
            }
        }

        It 'Should combine pipeline objects into a single input object' {
            $yamlString1 = @'
            openapi: 3.0.3
            info:
                title: Async test - OpenAPI 3.0
                version: 0.0.1
            paths:
                /task/{taskId}:
                    get:
                        summary: Get Pode Task Info
'@

            $yamlString2 = @'
            openapi: 3.0.3
            info:
                title: Another test - OpenAPI 3.0
                version: 0.0.2
            paths:
                /task/{taskId}:
                    get:
                        summary: Get Another Task Info
'@

            $result = $yamlString1, $yamlString2 | ConvertFrom-PodeYaml
            $result | Should -BeOfType 'System.Collections.Specialized.OrderedDictionary'
        }
    }

}
