$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

Describe 'Test-PodeHeader' {
    Context 'WebServer' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $false } }

        It 'Returns true' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'value'
                }
            } }

            Test-PodeHeader -Name 'test' | Should Be $true
        }

        It 'Returns false for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should Be $false
        }

        It 'Returns false for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should Be $false
        }
    }

    Context 'Serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }

        It 'Returns true' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'value'
                }
            } }

            Test-PodeHeader -Name 'test' | Should Be $true
        }

        It 'Returns false for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should Be $false
        }

        It 'Returns false for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            } }

            Test-PodeHeader -Name 'test' | Should Be $false
        }
    }
}

Describe 'Get-PodeHeader' {
    Context 'WebServer' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $false } }

        It 'Returns null for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns null for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns a header' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'example'
                }
            } }

            $h = Get-PodeHeader -Name 'test'
            $h | Should Be 'example'
        }
    }

    Context 'Serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }

        It 'Returns null for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns null for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns a header' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'example'
                }
            } }

            $h = Get-PodeHeader -Name 'test'
            $h | Should Be 'example'
        }
    }
}

Describe 'Set-PodeHeader' {
    Context 'WebServer' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $false } }

        It 'Sets a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AddHeader' -Value {
                param($n, $v)
                $script:WebEvent.Response.Headers[$n] = $v
            }

            Set-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should Be 'example'
        }
    }

    Context 'Serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }

        It 'Sets a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AddHeader' -Value {
                param($n, $v)
                $script:WebEvent.Response.Headers[$n] = $v
            }

            Set-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should Be 'example'
        }
    }
}

Describe 'Set-PodeServerHeader' {
    It 'Sets the server header to response' {
        $script:WebEvent = @{ 'Response' = @{
            'Headers' = @{}
        } }

        $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AddHeader' -Value {
            param($n, $v)
            $script:WebEvent.Response.Headers[$n] = $v
        }

        Set-PodeServerHeader -Type 'Example'
        $WebEvent.Response.Headers['Server'] | Should Be 'Pode - Example'
    }
}

Describe 'Add-PodeHeader' {
    Context 'WebServer' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $false } }

        It 'Adds a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
                param($n, $v)
                $script:WebEvent.Response.Headers[$n] = $v
            }

            Add-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should Be 'example'
        }
    }

    Context 'Serverless' {
        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }

        It 'Adds a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            } }

            $WebEvent.Response | Add-Member -MemberType ScriptMethod -Name 'AppendHeader' -Value {
                param($n, $v)
                $script:WebEvent.Response.Headers[$n] = $v
            }

            Add-PodeHeader -Name 'test' -Value 'example'
            $WebEvent.Response.Headers['test'] | Should Be 'example'
        }
    }
}