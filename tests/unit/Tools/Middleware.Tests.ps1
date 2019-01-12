$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Get-PodeInbuiltMiddleware' {
    Context 'Invalid parameters supplied' {
        It 'Throws null name parameter error' {
            { Get-PodeInbuiltMiddleware -Name $null -ScriptBlock {} } | Should Throw 'null or empty'
        }

        It 'Throws empty name parameter error' {
            { Get-PodeInbuiltMiddleware -Name ([string]::Empty) -ScriptBlock {} } | Should Throw 'null or empty'
        }

        It 'Throws null logic error' {
            { Get-PodeInbuiltMiddleware -Name 'test' -ScriptBlock $null } | Should Throw 'argument is null'
        }
    }

    Context 'Valid parameters' {
        It 'using default inbuilt logic' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(
                @{ 'Name' = $null; 'Logic' = { write-host 'pre1' } }
            ); }; }

            $logic = Get-PodeInbuiltMiddleware -Name '@access' -ScriptBlock { write-host 'in1' }

            $logic | Should Not Be $null
            $logic.Name | Should Be '@access'
            $logic.Logic.ToString() | Should Be ({ write-host 'in1' }).ToString()

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic | Should Be ({ write-host 'pre1' }).ToString()
        }

        It 'using default override logic' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(
                @{ 'Name' = $null; 'Logic' = { write-host 'pre1' } };
                @{ 'Name' = '@access'; 'Logic' = { write-host 'over1' } }
            ); }; }

            $logic = Get-PodeInbuiltMiddleware -Name '@access' -ScriptBlock { write-host 'in1' }

            $logic | Should Not Be $null
            $logic.Name | Should Be '@access'
            $logic.Logic.ToString() | Should Be ({ write-host 'over1' }).ToString()

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic | Should Be ({ write-host 'pre1' }).ToString()
        }
    }
}

Describe 'Middleware' {
    Context 'Invalid parameters supplied' {
        It 'Throws null script logic error' {
            { Middleware -ScriptBlock $null } | Should Throw 'argument is null'
        }

        It 'Throws null hash logic error' {
            { Middleware -HashTable $null } | Should Throw 'because it is null'
        }
    }

    Context 'Valid parameters' {
        It 'Adds single middleware script to list' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -ScriptBlock { write-host 'middle1' }

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
        }

        It 'Adds single middleware script to list with route' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -Route '/api' -ScriptBlock { write-host 'middle1' }

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeSession.Server.Middleware[0].Route | Should Be '/api'
        }

        It 'Adds single middleware script to list with route and return' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            $result = (Middleware -Route '/api' -ScriptBlock { write-host 'middle1' } -Return)

            $PodeSession.Server.Middleware.Length | Should Be 0
            $result.Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $result.Route | Should Be '/api'
        }

        It 'Adds two middleware scripts to list' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -ScriptBlock { write-host 'middle1' }
            Middleware -ScriptBlock { write-host 'middle2' }

            $PodeSession.Server.Middleware.Length | Should Be 2
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeSession.Server.Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()
        }

        It 'Adds middleware script to override inbuilt ones' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -ScriptBlock { write-host 'middle1' } -Name '@access'

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeSession.Server.Middleware[0].Name | Should Be '@access'
        }

        It 'Throws error when adding middleware script with duplicate name' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -ScriptBlock { write-host 'middle1' } -Name '@access'
            { Middleware -ScriptBlock { write-host 'middle2' } -Name '@access' } | Should Throw 'already exists'
        }

        It 'Throws error when adding middleware hash with no logic' {
            { Middleware -HashTable @{ 'Rand' = { write-host 'middle1' } } } | Should Throw 'has no logic'
        }

        It 'Adds single middleware hash to list' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -HashTable @{ 'Logic' = { write-host 'middle1' } }

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
        }

        It 'Adds single middleware hash to list with route' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -Route '/api' -HashTable @{ 'Logic' = { write-host 'middle1' } }

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeSession.Server.Middleware[0].Route | Should Be '/api'
        }

        It 'Adds single middleware hash to list with route and return' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            $result = (Middleware -Route '/api' -HashTable @{ 'Logic' = { write-host 'middle1' } } -Return)

            $PodeSession.Server.Middleware.Length | Should Be 0
            $result.Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $result.Route | Should Be '/api'
        }

        It 'Adds two middleware hashs to list' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -HashTable @{ 'Logic' = { write-host 'middle1' } }
            Middleware -HashTable @{ 'Logic' = { write-host 'middle2' } }

            $PodeSession.Server.Middleware.Length | Should Be 2
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeSession.Server.Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()
        }

        It 'Adds middleware hash to override inbuilt ones' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -HashTable @{ 'Logic' = { write-host 'middle1' } } -Name '@access'

            $PodeSession.Server.Middleware.Length | Should Be 1
            $PodeSession.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeSession.Server.Middleware[0].Name | Should Be '@access'
        }

        It 'Throws error when adding middleware hash with duplicate name' {
            $PodeSession = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Middleware -HashTable @{ 'Logic' = { write-host 'middle1' } } -Name '@access'
            { Middleware -HashTable @{ 'Logic' = { write-host 'middle2' } } -Name '@access' } | Should Throw 'already exists'
        }
    }
}