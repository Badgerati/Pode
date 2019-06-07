$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Test-PodeHeaderExists' {
    Context 'WebServer' {
        $serverless = $false

        It 'Returns true' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'value'
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Test-PodeHeaderExists -Name 'test' | Should Be $true
        }

        It 'Returns false for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Test-PodeHeaderExists -Name 'test' | Should Be $false
        }

        It 'Returns false for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Test-PodeHeaderExists -Name 'test' | Should Be $false
        }
    }

    Context 'Serverless' {
        $serverless = $true

        It 'Returns true' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'value'
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Test-PodeHeaderExists -Name 'test' | Should Be $true
        }

        It 'Returns false for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Test-PodeHeaderExists -Name 'test' | Should Be $false
        }

        It 'Returns false for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{}
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Test-PodeHeaderExists -Name 'test' | Should Be $false
        }
    }
}

Describe 'Get-PodeHeader' {
    Context 'WebServer' {
        $serverless = $false

        It 'Returns null for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns null for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns a header' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'example'
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            $h = Get-PodeHeader -Name 'test'
            $h | Should Be 'example'
        }
    }

    Context 'Serverless' {
        $serverless = $true

        It 'Returns null for no value' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns null for not existing' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = $null
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            Get-PodeHeader -Name 'test' | Should Be $null
        }

        It 'Returns a header' {
            $WebEvent = @{ 'Request' = @{
                'Headers' = @{
                    'test' = 'example'
                }
            };
            'Server' =@{
                'IsServerless' = $serverless
            } }

            $h = Get-PodeHeader -Name 'test'
            $h | Should Be 'example'
        }
    }
}

Describe 'Set-PodeHeader' {
    Context 'WebServer' {
        $serverless = $false

        It 'Sets a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            };
            'Server' = @{
                'IsServerless' = $serverless
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
        $serverless = $true

        It 'Sets a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            };
            'Server' = @{
                'IsServerless' = $serverless
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
        $serverless = $false

        It 'Adds a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            };
            'Server' = @{
                'IsServerless' = $serverless
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
        $serverless = $true

        It 'Adds a header to response' {
            $script:WebEvent = @{ 'Response' = @{
                'Headers' = @{}
            };
            'Server' = @{
                'IsServerless' = $serverless
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

Describe 'Header' {
    It 'Throws invalid action error' {
        { Header -Action 'MOO' -Name 'test' } | Should Throw "Cannot validate argument on parameter 'Action'"
    }

    It 'Throws error for null name' {
        { Header -Action Set -Name $null } | Should Throw "because it is an empty string"
    }

    It 'Throws error for empty name' {
        { Header -Action Set -Name ([string]::Empty) } | Should Throw "because it is an empty string"
    }

    It 'Calls set method' {
        Mock Set-PodeHeader { }
        Header -Action Set -Name 'test' -Value 'example'
        Assert-MockCalled Set-PodeHeader -Times 1 -Scope It
    }

    It 'Calls add method' {
        Mock Add-PodeHeader { }
        Header -Action Add -Name 'test' -Value 'example'
        Assert-MockCalled Add-PodeHeader -Times 1 -Scope It
    }

    It 'Calls get method' {
        Mock Get-PodeHeader { return 'header' }
        $h = Header -Action Get -Name 'test'
        $h | Should Be 'header'
        Assert-MockCalled Get-PodeHeader -Times 1 -Scope It
    }

    It 'Calls exists method' {
        Mock Test-PodeHeaderExists { return $true }
        Header -Action Exists -Name 'test' | Should Be $true
        Assert-MockCalled Test-PodeHeaderExists -Times 1 -Scope It
    }
}