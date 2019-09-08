$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

Describe 'Add-PodeFlashMessage' {
    It 'Throws error because sessions are not configured' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
        { Add-PodeFlashMessage -Name 'name' -Message 'message' } | Should Throw 'Sessions are required'
    }

    It 'Throws error for no name supplied' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        { Add-PodeFlashMessage -Name '' -Message 'message' } | Should Throw 'empty string'
    }

    It 'Throws error for no message supplied' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        { Add-PodeFlashMessage -Name 'name' -Message '' } | Should Throw 'empty string'
    }

    It 'Adds a single key and value' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 1
        $WebEvent.Session.Data.Flash['Test1'] | Should Be 'Value1'
    }

    It 'Adds two different keys and values' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test2' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2
        $WebEvent.Session.Data.Flash['Test1'] | Should Be 'Value1'
        $WebEvent.Session.Data.Flash['Test2'] | Should Be 'Value2'
    }

    It 'Adds two values for the same key' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test1' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 1
        $WebEvent.Session.Data.Flash['Test1'].Length | Should Be 2
        $WebEvent.Session.Data.Flash['Test1'][0] | Should Be 'Value1'
        $WebEvent.Session.Data.Flash['Test1'][1] | Should Be 'Value2'
    }
}

Describe 'Clear-PodeFlashMessages' {
    It 'Throws error because sessions are not configured' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
        { Clear-PodeFlashMessages } | Should Throw 'Sessions are required'
    }

    It 'Adds two keys and then Clears them all' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test2' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2

        Clear-PodeFlashMessages

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 0
    }
}

Describe 'Get-PodeFlashMessage' {
    It 'Throws error because sessions are not configured' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
        { Get-PodeFlashMessage -Name 'name' } | Should Throw 'Sessions are required'
    }

    It 'Throws error for no key supplied' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        { Get-PodeFlashMessage -Name '' } | Should Throw 'empty string'
    }

    It 'Returns empty array on key that does not exist' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        $result = (Get-PodeFlashMessage -Name 'Test1')
        $result.Length | Should Be 0
    }

    It 'Returns empty array on key that is empty' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{
            'Flash' = @{ 'Test1' = @(); }
         } } }

        $result = (Get-PodeFlashMessage -Name 'Test1')
        $result.Length | Should Be 0
    }

    It 'Adds two keys and then Gets one of them' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test2' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2

        $result = (Get-PodeFlashMessage -Name 'Test1')

        $result | Should Be 'Value1'
        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 1
    }

    It 'Adds two values for the same key then Gets it' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test1' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 1

        $result = (Get-PodeFlashMessage -Name 'Test1')

        $result.Length | Should be 2
        $result[0] | Should be 'Value1'
        $result[1] | Should be 'Value2'
        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 0
    }
}

Describe 'Get-PodeFlashMessageNames' {
    It 'Throws error because sessions are not configured' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
        { Get-PodeFlashMessageNames } | Should Throw 'Sessions are required'
    }

    It 'Adds two keys and then retrieves the Keys' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test2' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2

        $result = (Get-PodeFlashMessageNames)

        $result.Length | Should Be 2
        $result.IndexOf('Test1') | Should Not Be -1
        $result.IndexOf('Test2') | Should Not Be -1

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2
    }

    It 'Returns no keys as none have been added' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        $result = (Get-PodeFlashMessageNames)
        $result.Length | Should Be 0
    }
}

Describe 'Remove-PodeFlashMessage' {
    It 'Throws error because sessions are not configured' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
        { Remove-PodeFlashMessage -Name 'name' } | Should Throw 'Sessions are required'
    }

    It 'Throws error for no key supplied' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        { Remove-PodeFlashMessage -Name '' } | Should Throw 'empty string'
    }

    It 'Adds two keys and then Remove one of them' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test2' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2

        Remove-PodeFlashMessage -Name 'Test1'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 1
    }
}

Describe 'Test-PodeFlashMessage' {
    It 'Throws error because sessions are not configured' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{} } }
        { Test-PodeFlashMessage -Name 'name' } | Should Throw 'Sessions are required'
    }

    It 'Throws error for no key supplied' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        { Test-PodeFlashMessage -Name '' } | Should Throw 'empty string'
    }

    It 'Adds two keys and then Tests if one of them exists' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test2' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2

        Test-PodeFlashMessage -Name 'Test1' | Should Be $true
    }

    It 'Adds two keys and then Tests for a non-existent key' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }

        Add-PodeFlashMessage -Name 'Test1' -Message 'Value1'
        Add-PodeFlashMessage -Name 'Test2' -Message 'Value2'

        $WebEvent.Session.Data.Flash | Should Not Be $null
        $WebEvent.Session.Data.Flash.Count | Should Be 2

        Test-PodeFlashMessage -Name 'Test3' | Should Be $false
    }

    It 'Returns false when no flash message have been added' {
        $PodeContext = @{ 'Server' = @{ 'Cookies' = @{ 'Session' = @{ 'Secret' = 'Key' } } } }
        $WebEvent = @{ 'Session' = @{ 'Data' = @{ } } }
        Test-PodeFlashMessage -Name 'Test3' | Should Be $false
    }
}