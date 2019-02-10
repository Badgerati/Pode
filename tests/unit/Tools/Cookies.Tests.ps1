$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$now = [datetime]::UtcNow

Describe 'Flash' {
    Context 'Invalid parameters supplied' {
        It 'Throws invalid action error' {
            { Flash -Action 'MOO' -Key '' -Value '' } | Should Throw "Cannot validate argument on parameter 'Action'"
        }
    }

    Context 'Valid parameters' {
        It 'Throws error because sessions are not configured' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
            { Flash -Action Add -Key '' -Value '' } | Should Throw 'Sessions are required'
        }

        It 'Throws error for no key supplied on Add' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            { Flash -Action Add -Key '' } | Should Throw 'A Key is required'
        }

        It 'Throws error for no key supplied on Get' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            { Flash -Action Get -Key '' } | Should Throw 'A Key is required'
        }

        It 'Throws error for no key supplied on Remove' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            { Flash -Action Remove -Key '' } | Should Throw 'A Key is required'
        }

        It 'Adds a single key and value' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
            $WebEvent.Session.Data.Flash['Test1'] | Should Be 'Value1'
        }

        It 'Adds a single key with no value' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
            $WebEvent.Session.Data.Flash['Test1'] | Should Be ''
        }

        It 'Adds two different keys and values' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'
            Flash -Action Add -Key 'Test2' -Value 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2
            $WebEvent.Session.Data.Flash['Test1'] | Should Be 'Value1'
            $WebEvent.Session.Data.Flash['Test2'] | Should Be 'Value2'
        }

        It 'Adds two values for the same key' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'
            Flash -Action Add -Key 'Test1' -Value 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
            $WebEvent.Session.Data.Flash['Test1'].Length | Should Be 2
            $WebEvent.Session.Data.Flash['Test1'][0] | Should Be 'Value1'
            $WebEvent.Session.Data.Flash['Test1'][1] | Should Be 'Value2'
        }

        It 'Adds two keys and then Clears them all' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'
            Flash -Action Add -Key 'Test2' -Value 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2

            Flash -Action Clear

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 0
        }

        It 'Adds a single key with no value then Get it' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
            $WebEvent.Session.Data.Flash['Test1'] | Should Be ''

            $result = Flash -Action Get -Key 'Test1'
            $result.Length | Should Be 0

            $WebEvent.Session.Data.Flash.Count | Should Be 0
        }

        It 'returns empty array for Get on key that does not exist' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            $result = Flash -Action Get -Key 'Test1'
            $result.Length | Should Be 0
        }

        It 'Adds two keys and then Gets one of them' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'
            Flash -Action Add -Key 'Test2' -Value 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2

            $result = Flash -Action Get -Key 'Test1'

            $result | Should Be 'Value1'
            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
        }

        It 'Adds two values for the same key then Gets it' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'
            Flash -Action Add -Key 'Test1' -Value 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1

            $result = Flash -Action Get -Key 'Test1'

            $result.Length | Should be 2
            $result[0] | Should be 'Value1'
            $result[1] | Should be 'Value2'
            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 0
        }

        It 'Adds two keys and then Remove one of them' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'
            Flash -Action Add -Key 'Test2' -Value 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2

            Flash -Action Remove -Key 'Test1'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
        }

        It 'Adds two keys and then retrieves the Keys' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Value 'Value1'
            Flash -Action Add -Key 'Test2' -Value 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2

            $result = Flash -Action Keys

            $result.Length | Should Be 2
            $result.IndexOf('Test1') | Should Not Be -1
            $result.IndexOf('Test2') | Should Not Be -1

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2
        }
    }
}

Describe 'Get-PodeSessionCookie' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Get-PodeSessionCookie -Request $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Returns no session details for invalid sessionId' {
            $Request = @{
                'Cookies' = @{}
            }

            $PodeContext = @{
                'Server' = @{ 'Cookies' = @{ 'Session' = @{
                    'Name' = 'pode.sid';
                    'SecretKey' = 'key';
                    'Info' = @{ 'Duration' = 60; };
                } } }
            }

            $data = Get-PodeSessionCookie -Request $Request
            $data | Should Be $null
        }

        It 'Returns no session details for invalid signed sessionId' {
            $Request = @{
                'Cookies' = @{
                    'pode.sid' = @{
                        'Value' = 's:value.kPv88V5o2uJ29sqh2a7P/f3dxcg+JdZJZT3GTIE=';
                        'Name' = 'pode.sid';
                        'TimeStamp' = $now;
                    }
                }
            }

            $PodeContext = @{
                'Server' = @{ 'Cookies' = @{ 'Session' = @{
                    'Name' = 'pode.sid';
                    'SecretKey' = 'key';
                    'Info' = @{ 'Duration' = 60; };
                } } }
            }

            $data = Get-PodeSessionCookie -Request $Request
            $data | Should Be $null
        }

        It 'Returns session details' {
            $Request = @{
                'Cookies' = @{
                    'pode.sid' = @{
                        'Value' = 's:value.kPv88V50o2uJ29sqch2a7P/f3dxcg+J/dZJZT3GTJIE=';
                        'Name' = 'pode.sid';
                        'TimeStamp' = $now;
                    }
                }
            }

            $PodeContext = @{
                'Server' = @{ 'Cookies' = @{ 'Session' = @{
                    'Name' = 'pode.sid';
                    'SecretKey' = 'key';
                    'Info' = @{ 'Duration' = 60; };
                } } }
            }

            $data = Get-PodeSessionCookie -Request $Request
            $data | Should Not Be $null
            $data.Id | Should Be 'value'
            $data.Name | Should Be 'pode.sid'
            $data.Cookie.TimeStamp | Should Be $now
            $data.Cookie.Duration | Should Be 60
        }
    }
}

Describe 'Set-PodeSessionCookieDataHash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Set-PodeSessionCookieDataHash -Session $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Sets a hash for no data' {
            $Session = @{}
            Set-PodeSessionCookieDataHash -Session $Session
            $Session.Data | Should Not Be $null

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Session.Data| ConvertTo-Json)))
            $hash = [System.Convert]::ToBase64String($hash)

            $Session.DataHash | Should Be $hash
        }

        It 'Sets a hash for data' {
            $Session = @{ 'Data' = @{ 'Counter' = 2; } }
            Set-PodeSessionCookieDataHash -Session $Session
            $Session.Data | Should Not Be $null

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Session.Data| ConvertTo-Json)))
            $hash = [System.Convert]::ToBase64String($hash)

            $Session.DataHash | Should Be $hash
        }
    }
}

Describe 'New-PodeSessionCookie' {
    Mock 'Invoke-ScriptBlock' { return 'value' }

    It 'Creates a new session object' {
        $PodeContext = @{
            'Server' = @{ 'Cookies' = @{ 'Session' = @{
                'Name' = 'pode.sid';
                'SecretKey' = 'key';
                'Info' = @{ 'Duration' = 60; };
                'GenerateId' = {}
            } } }
        }

        $session = New-PodeSessionCookie

        $session | Should Not Be $null
        $session.Id | Should Be 'value'
        $session.Name | Should Be 'pode.sid'
        $session.Data.Count | Should Be 0
        $session.Cookie.Duration | Should Be 60

        $crypto = [System.Security.Cryptography.SHA256]::Create()
        $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($session.Data| ConvertTo-Json)))
        $hash = [System.Convert]::ToBase64String($hash)

        $session.DataHash | Should Be $hash
    }
}

Describe 'Test-PodeSessionCookieDataHash' {
    Context 'Invalid parameters supplied' {
        It 'Throws null value error' {
            { Test-PodeSessionCookieDataHash -Session $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'Returns false for no hash set' {
            $Session = {}
            Test-PodeSessionCookieDataHash -Session $Session | Should Be $false
        }

        It 'Returns false for invalid hash' {
            $Session = @{ 'DataHash' = 'fake' }
            Test-PodeSessionCookieDataHash -Session $Session | Should Be $false
        }

        It 'Returns true for a valid hash' {
            $Session = @{
                'Data' = @{ 'Counter' = 2; };
            }

            $crypto = [System.Security.Cryptography.SHA256]::Create()
            $hash = $crypto.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($Session.Data| ConvertTo-Json)))
            $hash = [System.Convert]::ToBase64String($hash)
            $Session.DataHash = $hash

            Test-PodeSessionCookieDataHash -Session $Session | Should Be $true
        }
    }
}

Describe 'Get-PodeSessionCookieInMemStore' {
    It 'Returns a valid storage object' {
        $store = Get-PodeSessionCookieInMemStore
        $store | Should Not Be $null

        $members = @(($store | Get-Member).Name)
        $members.Contains('Memory' ) | Should Be $true
        $members.Contains('Delete' ) | Should Be $true
        $members.Contains('Get' ) | Should Be $true
        $members.Contains('Set' ) | Should Be $true
    }
}

Describe 'Set-PodeSessionCookieInMemClearDown' {
    It 'Adds a new schedule for clearing down' {
        $PodeContext = @{ 'Schedules' = @{}}
        Set-PodeSessionCookieInMemClearDown
        $PodeContext.Schedules.Count | Should Be 1
        $PodeContext.Schedules.Contains('__pode_session_inmem_cleanup__') | Should Be $true
    }
}