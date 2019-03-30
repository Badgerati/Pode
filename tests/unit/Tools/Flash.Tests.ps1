$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Flash' {
    Context 'Invalid parameters supplied' {
        It 'Throws invalid action error' {
            { Flash -Action 'MOO' -Key '' -Message '' } | Should Throw "Cannot validate argument on parameter 'Action'"
        }
    }

    Context 'Valid parameters' {
        It 'Throws error because sessions are not configured' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
            { Flash -Action Add -Key '' -Message '' } | Should Throw 'Sessions are required'
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

            Flash -Action Add -Key 'Test1' -Message 'Value1'

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

            Flash -Action Add -Key 'Test1' -Message 'Value1'
            Flash -Action Add -Key 'Test2' -Message 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2
            $WebEvent.Session.Data.Flash['Test1'] | Should Be 'Value1'
            $WebEvent.Session.Data.Flash['Test2'] | Should Be 'Value2'
        }

        It 'Adds two values for the same key' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Message 'Value1'
            Flash -Action Add -Key 'Test1' -Message 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
            $WebEvent.Session.Data.Flash['Test1'].Length | Should Be 2
            $WebEvent.Session.Data.Flash['Test1'][0] | Should Be 'Value1'
            $WebEvent.Session.Data.Flash['Test1'][1] | Should Be 'Value2'
        }

        It 'Adds two keys and then Clears them all' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Message 'Value1'
            Flash -Action Add -Key 'Test2' -Message 'Value2'

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

            Flash -Action Add -Key 'Test1' -Message 'Value1'
            Flash -Action Add -Key 'Test2' -Message 'Value2'

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

            Flash -Action Add -Key 'Test1' -Message 'Value1'
            Flash -Action Add -Key 'Test1' -Message 'Value2'

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

            Flash -Action Add -Key 'Test1' -Message 'Value1'
            Flash -Action Add -Key 'Test2' -Message 'Value2'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 2

            Flash -Action Remove -Key 'Test1'

            $WebEvent.Session.Data.Flash | Should Not Be $null
            $WebEvent.Session.Data.Flash.Count | Should Be 1
        }

        It 'Adds two keys and then retrieves the Keys' {
            $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{} } } }
            $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

            Flash -Action Add -Key 'Test1' -Message 'Value1'
            Flash -Action Add -Key 'Test2' -Message 'Value2'

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