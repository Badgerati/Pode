$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
$sut = (Split-Path -Leaf -Path $path) -ireplace '\.Tests\.', '.'
. "$($src)\$($sut)"

Describe 'Get-PodeRoute' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid method error for no method' {
            { Get-PodeRoute -HttpMethod 'MOO' -Route '/' } | Should Throw "Cannot validate argument on parameter 'HttpMethod'"
        }

        It 'Throw null route parameter error' {
            { Get-PodeRoute -HttpMethod GET -Route $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty route parameter error' {
            { Get-PodeRoute -HttpMethod GET -Route ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid method and route' {
        It 'Return null as method does not exist' {
            $PodeSession = @{ 'Routes' = @{}; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns no logic for method/route that do not exist' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns logic for method and exact route' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{ '/' = { Write-Host 'Test' }; }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and parameters for parameterised route' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{ '/(?<userId>[\w-_]+?)' = { Write-Host 'Test' }; }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/123')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            
            $result.Parameters | Should BeOfType System.Collections.Hashtable
            $result.Parameters['userId'] | Should Be '123'
        }
    }
}

Describe 'Route' {
    Context 'Invalid parameters supplied' {
        It 'Throws invalid method error for no method' {
            { Route -HttpMethod 'MOO' -Route '/' -ScriptBlock {} } | Should Throw "Cannot validate argument on parameter 'HttpMethod'"
        }

        It 'Throws null route parameter error' {
            { Route -HttpMethod GET -Route $null -ScriptBlock {} } | Should Throw 'it is an empty string'
        }

        It 'Throws empty route parameter error' {
            { Route -HttpMethod GET -Route ([string]::Empty) -ScriptBlock {} } | Should Throw 'it is an empty string'
        }

        It 'Throws null scriptblock parameter error' {
            { Route -HttpMethod GET -Route '/' -ScriptBlock $null } | Should Throw 'The argument is null'
        }
    }

    Context 'Valid route parameters' {
        It 'Throws error because only querystring has been given' {
            { Route -HttpMethod GET -Route "?k=v" -ScriptBlock {} } | Should Throw "No route supplied"
        }

        It 'Throws error because route already exists' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{ '/' = $null; }; }; }
            { Route -HttpMethod GET -Route '/' -ScriptBlock {} } | Should Throw 'request logic defined'
        }

        It 'Adds route with simple url' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users') | Should Be $true
            $route['/users'] | Should Not Be $null
            $route['/users'].ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds route with simple url and querystring' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users?k=v' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users') | Should Be $true
            $route['/users'] | Should Not Be $null
            $route['/users'].ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds route with url parameters' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users/:userId' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
            $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
            $route['/users/(?<userId>[\w-_]+?)'].ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }

        It 'Adds route with url parameters and querystring' {
            $PodeSession = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users/:userId?k=v' -ScriptBlock { Write-Host 'hello' }

            $route = $PodeSession.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
            $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
            $route['/users/(?<userId>[\w-_]+?)'].ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        }
    }
}