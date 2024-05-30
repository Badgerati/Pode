[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable msgTable -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -UICulture 'en-us' -FileName 'Pode'

    $now = [datetime]::UtcNow
}

Describe 'Get-PodeSession' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            $PodeContext = @{
                Server = @{
                    Sessions = @{
                        Name = $null
                    }
                }
            }

            { Get-PodeSession } | Should -Throw -ExpectedMessage '*because it is an empty string*'
        }

        It 'Throws an empry string value error' {
            $PodeContext = @{
                Server = @{
                    Sessions = @{
                        Name = [string]::Empty
                    }
                }
            }

            { Get-PodeSession } | Should -Throw -ExpectedMessage '*because it is an empty string*'
        }
    }

    Context 'Valid parameters' {
        It 'Returns no session details for invalid sessionId' {
            $WebEvent = @{ Cookies = @{} }

            $PodeContext = @{
                Server = @{
                    Cookies  = @{}
                    Sessions = @{
                        Name   = 'pode.sid'
                        Secret = 'key'
                        Info   = @{ 'Duration' = 60 }
                    }
                }
            }

            $data = Get-PodeSession
            $data | Should -Be $null
        }

        It 'Returns no session details for invalid signed sessionId' {
            $cookie = [System.Net.Cookie]::new('pode.sid', 's:value.kPv88V5o2uJ29sqh2a7P/f3dxcg+JdZJZT3GTIE=')

            $WebEvent = @{ Cookies = @{
                    'pode.sid' = $cookie
                }
            }

            $PodeContext = @{
                Server = @{
                    Cookies  = @{}
                    Sessions = @{
                        Name   = 'pode.sid'
                        Secret = 'key'
                        Info   = @{ 'Duration' = 60 }
                    }
                }
            }

            $data = Get-PodeSession
            $data | Should -Be $null
        }

        It 'Returns session details' {
            $cookie = [System.Net.Cookie]::new('pode.sid', 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE=')

            $WebEvent = @{ Cookies = @{
                    'pode.sid' = $cookie
                }
            }

            $PodeContext = @{
                Server = @{
                    Cookies  = @{}
                    Sessions = @{
                        Name   = 'pode.sid'
                        Secret = 'key'
                        Info   = @{ 'Duration' = 60 }
                    }
                }
            }

            $data = Get-PodeSession
            $data | Should -Not -Be $null
            $data.Id | Should -Be 'value'
            $data.Name | Should -Be 'pode.sid'
        }
    }
}

Describe 'Set-PodeSessionDataHash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Set-PodeSessionDataHash } | Should -Throw -ExpectedMessage '*No session available*'
        }
    }

    Context 'Valid parameters' {
        It 'Sets a hash for no data' {
            $WebEvent = @{
                Session = @{}
            }
            Set-PodeSessionDataHash
            $WebEvent.Session.Data | Should -Not -Be $null

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($WebEvent.Session.Data | ConvertTo-Json -Depth 10 -Compress)))
            $hash = [System.Convert]::ToBase64String($hash)

            $WebEvent.Session.DataHash | Should -Be $hash
        }

        It 'Sets a hash for data' {
            $WebEvent = @{
                Session = @{ 'Data' = @{ 'Counter' = 2; } }
            }
            Set-PodeSessionDataHash
            $WebEvent.Session.Data | Should -Not -Be $null

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($WebEvent.Session.Data | ConvertTo-Json -Depth 10 -Compress)))
            $hash = [System.Convert]::ToBase64String($hash)

            $WebEvent.Session.DataHash | Should -Be $hash
        }
    }
}

Describe 'New-PodeSession' {
    BeforeAll {
        Mock 'Invoke-PodeScriptBlock' { return 'value' }
    }
    It 'Creates a new session object' {
        $WebEvent = @{
            Session = @{}
        }

        $PodeContext = @{
            Server = @{
                Cookies  = @{}
                Sessions = @{
                    Name       = 'pode.sid'
                    Secret     = 'key'
                    Info       = @{ 'Duration' = 60 }
                    GenerateId = {}
                }
            }
        }

        $WebEvent.Session = New-PodeSession
        Set-PodeSessionDataHash

        $WebEvent.Session | Should -Not -Be $null
        $WebEvent.Session.Id | Should -Be 'value'
        $WebEvent.Session.Name | Should -Be 'pode.sid'
        $WebEvent.Session.Data.Count | Should -Be 0

        $crypto = [System.Security.Cryptography.SHA256]::Create()
        $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($WebEvent.Session.Data | ConvertTo-Json -Depth 10 -Compress)))
        $hash = [System.Convert]::ToBase64String($hash)

        $WebEvent.Session.DataHash | Should -Be $hash
    }
}

Describe 'Test-PodeSessionDataHash' {
    Context 'Valid parameters' {
        It 'Returns false for no hash set' {
            $WebEvent = @{
                Session = @{}
            }
            Test-PodeSessionDataHash | Should -Be $false
        }

        It 'Returns false for invalid hash' {
            $WebEvent = @{
                Session = @{ 'DataHash' = 'fake' }
            }
            Test-PodeSessionDataHash | Should -Be $false
        }

        It 'Returns true for a valid hash' {
            $WebEvent = @{
                Session = @{
                    'Data' = @{ 'Counter' = 2; }
                }
            }

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($WebEvent.Session.Data | ConvertTo-Json -Depth 10 -Compress)))
            $hash = [System.Convert]::ToBase64String($hash)
            $WebEvent.Session.DataHash = $hash

            Test-PodeSessionDataHash | Should -Be $true
        }
    }
}

Describe 'Get-PodeSessionInMemStore' {
    It 'Returns a valid storage object' {
        $store = Get-PodeSessionInMemStore
        $store | Should -Not -Be $null

        $members = @(($store | Get-Member).Name)
        $members.Contains('Memory' ) | Should -Be $true
        $members.Contains('Delete' ) | Should -Be $true
        $members.Contains('Get' ) | Should -Be $true
        $members.Contains('Set' ) | Should -Be $true
    }
}

Describe 'Set-PodeSessionInMemClearDown' {
    It 'Adds a new schedule for clearing down' {
        $PodeContext = @{ 'Schedules' = @{ Items = @{} } }
        Set-PodeSessionInMemClearDown
        $PodeContext.Schedules.Items.Count | Should -Be 1
        $PodeContext.Schedules.Items.Contains('__pode_session_inmem_cleanup__') | Should -Be $true
    }
}

Describe 'Set-PodeSession' {
    It 'Sets a new cookie on the response' {
        Mock Set-PodeCookie { }
        Mock Get-PodeSessionExpiry { return ([datetime]::UtcNow) }

        $WebEvent = @{
            Session = @{
                'Name'   = 'name'
                'Id'     = 'sessionId'
                'Cookie' = @{}
            }
        }

        Set-PodeSession

        Assert-MockCalled Set-PodeCookie -Times 1 -Scope It
        Assert-MockCalled Get-PodeSessionExpiry -Times 1 -Scope It
    }
}

Describe 'Remove-PodeSession' {
    It 'Throws an error if sessions are not configured' {
        Mock Test-PodeSessionsEnabled { return $false }
        { Remove-PodeSession } | Should -Throw 'Sessions have not been configured'
    }

    It 'Does nothing if there is no session' {
        Mock Test-PodeSessionsEnabled { return $true }
        Mock Remove-PodeAuthSession {}

        $WebEvent = @{}
        Remove-PodeSession

        Assert-MockCalled Remove-PodeAuthSession -Times 0 -Scope It
    }

    It 'Call removes the session' {
        Mock Test-PodeSessionsEnabled { return $true }
        Mock Remove-PodeAuthSession {}

        $WebEvent = @{ Session = @{} }
        Remove-PodeSession

        Assert-MockCalled Remove-PodeAuthSession -Times 1 -Scope It
    }
}

Describe 'Save-PodeSession' {
    It 'Throws an error if sessions are not configured' {
        Mock Test-PodeSessionsEnabled { return $false }
        { Save-PodeSession } | Should -Throw 'Sessions have not been configured'
    }

    It 'Throws error if there is no session' {
        Mock Test-PodeSessionsEnabled { return $true }
        $WebEvent = @{}
        { Save-PodeSession } | Should -Throw -ExpectedMessage 'There is no session available to save'
    }

    It 'Call saves the session' {
        Mock Test-PodeSessionsEnabled { return $true }
        Mock Save-PodeSessionInternal {}

        $WebEvent = @{ Session = @{
                Save = {}
            }
        }

        Save-PodeSession
        Assert-MockCalled Save-PodeSessionInternal -Times 1 -Scope It
    }
}