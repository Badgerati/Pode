BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}
Describe 'Test-PodeHeader' {
    Context 'WebServer' {
        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

        It 'Returns true' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'value'
                }
            } }

            Test-PodeHeader -Name 'test' | Should -Be $true
        }

        It 'Returns false for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should -Be $false
        }

        It 'Returns false for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should -Be $false
        }
    }

    Context 'Serverless' {
        BeforeEach{
        $PodeContext = @{ 'Server' = @{ 'Type' = 'azurefunctions' } }}

        It 'Returns true' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'value'
                }
            } }

            Test-PodeHeader -Name 'test' | Should -Be $true
        }

        It 'Returns false for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should -Be $false
        }

        It 'Returns false for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should -Be $false
        }
    }
}

Describe 'Get-PodeHeader' {
    Context 'WebServer' {BeforeEach{
        $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }}

        It 'Returns null for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should -Be $null
        }

        It 'Returns null for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should -Be $null
        }

        It 'Returns a header' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'example'
                }
            } }

            $h = Get-PodeHeader -Name 'test'
            $h | Should -Be 'example'
        }
    }

    Context 'Serverless' {
        BeforeEach{
        $PodeContext = @{ 'Server' = @{ 'Type' = 'azurefunctions' } }}

        It 'Returns null for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should -Be $null
        }

        It 'Returns null for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should -Be $null
        }

        It 'Returns a header' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'example'
                }
            } }

            $h = Get-PodeHeader -Name 'test'
            $h | Should -Be 'example'
        }
    }
}

Describe 'Set-PodeHeader' {
    Context 'WebServer' { 
        It 'Sets a header to response' {
            $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }

            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            $WebEvent.Response.Headers | Add-Member -MemberType ScriptMethod -Name 'Set' -Value {
                param($n, $v)
                $script:WebEvent.Response.Headers[$n] = $v
            }

            Set-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should -Be 'example'
        }
    }

    Context 'Serverless' {
        It 'Sets a header to response' {
            $PodeContext = @{ 'Server' = @{ ServerlessType = 'azurefunctions'; IsServerless = $true } }

            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            Set-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should -Be 'example'
        }
    }
}

Describe 'Set-PodeServerHeader' {
    It 'Sets the server header to response' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        } }

        $WebEvent.Response.Headers | Add-Member -MemberType ScriptMethod -Name 'Set' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        Set-PodeServerHeader -Type 'Example'
        $WebEvent.Response.Headers['Server'] | Should -Be 'Pode - Example'
    }
}

Describe 'Add-PodeHeader' {
    Context 'WebServer' {

        It 'Adds a header to response' {
            $PodeContext = @{ 'Server' = @{ 'Type' = 'http' } }
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
                param($n, $v)
                $script:WebEvent.Response.Headers[$n] = $v
            }

            Add-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should -Be 'example'
        }
    }

    Context 'Serverless' {
        It 'Adds a header to response' {
            $PodeContext = @{ 'Server' = @{ 'Type' = 'azurefunctions' } }
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
                param($n, $v)
                $script:WebEvent.Response.Headers[$n] = $v
            }

            Add-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should -Be 'example'
        }
    }
}