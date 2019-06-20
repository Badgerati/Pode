$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

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
            $PodeContext.Server = @{ 'Routes' = @{}; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns no logic for method/route that do not exist' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Get-PodeRoute -HttpMethod GET -Route '/' | Should Be $null
        }

        It 'Returns logic for method and exact route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(@{ 'Logic'= { Write-Host 'Test' }; }); }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route and protocol' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{ 'Logic'= { Write-Host 'Test' }; };
                @{ 'Logic'= { Write-Host 'Test' }; 'Protocol' = 'http' };
            ); }; }; }

            $result = (Get-PodeRoute -HttpMethod GET -Route '/' -Protocol 'http')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Protocol | Should Be 'http'
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route and endpoint' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{ 'Logic'= { Write-Host 'Test' }; };
                @{ 'Logic'= { Write-Host 'Test' }; 'Endpoint' = 'pode.foo.com' };
            ); }; }; }

            $result = (Get-PodeRoute -HttpMethod GET -Route '/' -Endpoint 'pode.foo.com')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Endpoint | Should Be 'pode.foo.com'
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route, endpoint and protocol' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{ 'Logic'= { Write-Host 'Test' }; };
                @{ 'Logic'= { Write-Host 'Test' }; 'Endpoint' = 'pode.foo.com' };
                @{ 'Logic'= { Write-Host 'Test' }; 'Endpoint' = 'pode.foo.com'; 'Protocol' = 'https' };
            ); }; }; }

            $result = (Get-PodeRoute -HttpMethod GET -Route '/' -Endpoint 'pode.foo.com' -Protocol 'https')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Protocol | Should Be 'https'
            $result.Endpoint | Should Be 'pode.foo.com'
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route and wildcard endpoint' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{ 'Logic'= { Write-Host 'Test' }; };
                @{ 'Logic'= { Write-Host 'Test' }; 'Endpoint' = '*:8080' };
            ); }; }; }

            $result = (Get-PodeRoute -HttpMethod GET -Route '/' -Endpoint 'localhost:8080')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Endpoint | Should Be '*:8080'
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and middleware for method and exact route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(@{ 'Logic'= { Write-Host 'Test' }; 'Middleware' = { Write-Host 'Middle' }; }); }; }; }
            $result = (Get-PodeRoute -HttpMethod GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Middleware.ToString() | Should Be ({ Write-Host 'Middle' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route under star' {
            $PodeContext.Server = @{ 'Routes' = @{ '*' = @{ '/' = @(@{ 'Logic'= { Write-Host 'Test' }; }); }; }; }
            $result = (Get-PodeRoute -HttpMethod * -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and parameters for parameterised route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/(?<userId>[\w-_]+?)' = @(@{ 'Logic'= { Write-Host 'Test' }; }); }; }; }
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

        It 'Throws null logic and middleware error' {
            { Route -HttpMethod GET -Route '/' -Middleware $null -ScriptBlock $null } | Should Throw 'no scriptblock defined'
        }

        It 'Throws error when scriptblock and file path supplied' {
            { Route -HttpMethod GET -Route '/' -ScriptBlock { write-host 'hi' } -FilePath './path' } | Should Throw 'has both a scriptblock and a filepath'
        }

        It 'Throws error when file path is a directory' {
            Mock Test-PodePath { return $true }
            { Route -HttpMethod GET -Route '/' -FilePath './path' } | Should Throw 'cannot have a wildcard or directory'
        }

        It 'Throws error when file path is a wildcard' {
            Mock Test-PodePath { return $true }
            { Route -HttpMethod GET -Route '/' -FilePath './path/*' } | Should Throw 'cannot have a wildcard or directory'
        }
    }

    Context 'Valid route parameters' {
        It 'Throws error because only querystring has been given' {
            { Route -HttpMethod GET -Route "?k=v" {} } | Should Throw "No route path supplied"
        }

        It 'Throws error because route already exists' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{'Protocol' = ''; 'Endpoint' = ''}
            ); }; }; }

            { Route -HttpMethod GET -Route '/' {} } | Should Throw 'already defined'
        }

        It 'Throws error because route and protocol already exists' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{'Protocol' = ''; 'Endpoint' = ''}
                @{'Protocol' = 'http'; 'Endpoint' = ''}
            ); }; }; }

            { Route -HttpMethod GET -Route '/' -Protocol 'http' {} } | Should Throw 'already defined for'
        }

        It 'Throws error because route and endpoint already exists' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{'Protocol' = ''; 'Endpoint' = ''}
                @{'Protocol' = ''; 'Endpoint' = 'pode.foo.com:*'}
            ); }; }; }

            { Route -HttpMethod GET -Route '/' -Endpoint 'pode.foo.com' {} } | Should Throw 'already defined for'
        }

        It 'Throws error because route, endpoint and protocol already exists' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{'Protocol' = ''; 'Endpoint' = ''}
                @{'Protocol' = ''; 'Endpoint' = 'pode.foo.com:*'}
                @{'Protocol' = 'https'; 'Endpoint' = 'pode.foo.com:*'}
            ); }; }; }

            { Route -HttpMethod GET -Route '/' -Protocol 'https' -Endpoint 'pode.foo.com' {} } | Should Throw 'already defined for'
        }

        It 'Throws error when setting defaults on GET route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            { Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -Defaults @('index.html') } | Should Throw 'default static files defined'
        }

        It 'Throws error when setting DownloadOnly on GET route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            { Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -DownloadOnly } | Should Throw 'flagged as DownloadOnly'
        }

        It 'Throws error on GET route for endpoint name not existing' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            { Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -ListenName 'test' } | Should Throw 'does not exist'
        }

        It 'Adds route with simple url' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' }

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].ContentType | Should Be ([string]::Empty)
        }

        It 'Adds route with simple url and scriptblock from file path' {
            Mock Test-PodePath { return $true }
            Mock Load { return { Write-Host 'bye' } }

            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' -FilePath './path/route.ps1'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'bye' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].ContentType | Should Be ([string]::Empty)
        }

        Mock Test-PodePath { return $false }

        It 'Adds route with simple url with content type' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' -ContentType 'application/json' { Write-Host 'hello' }

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].ContentType | Should Be 'application/json'
        }

        It 'Adds route with simple url with default content type' {
            $PodeContext.Server = @{
                'Routes' = @{ 'GET' = @{}; };
                'Web' = @{ 'ContentType' = @{
                    'Default' = 'text/xml';
                    'Routes' = @{};
                } };
            }

            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' }

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].ContentType | Should Be 'text/xml'
        }

        It 'Adds route with simple url with route pattern content type' {
            $PodeContext.Server = @{
                'Routes' = @{ 'GET' = @{}; };
                'Web' = @{ 'ContentType' = @{
                    'Default' = 'text/xml';
                    'Routes' = @{ '/users' = 'text/plain' };
                } };
            }

            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' }

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].ContentType | Should Be 'text/plain'
        }

        It 'Adds route with full endpoint' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -Endpoint 'pode.foo.com:8080'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].Endpoint | Should Be 'pode.foo.com:8080'
        }

        It 'Adds route with wildcard host endpoint' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -Endpoint '8080'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].Endpoint | Should Be '*:8080'
        }

        It 'Adds route with wildcard port endpoint' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -Endpoint 'pode.foo.com'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].Endpoint | Should Be 'pode.foo.com:*'
        }

        It 'Adds route with http protocol' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -Protocol 'http'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'] | Should Not Be $null
            $routes['/users'].Length | Should Be 1
            $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $routes['/users'][0].Middleware | Should Be $null
            $routes['/users'][0].Protocol | Should Be 'http'
        }

        It 'Adds route with simple url, and then removes it' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' }

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'].Length | Should Be 1

            Route -Remove -HttpMethod GET -Route '/users'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $false
        }

        It 'Adds two routes with simple url, and then removes one' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' }
            Route -HttpMethod GET -Route '/users' { Write-Host 'hello' } -Protocol 'http'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'].Length | Should Be 2

            Route -Remove -HttpMethod GET -Route '/users'

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null
            $routes.ContainsKey('/users') | Should Be $true
            $routes['/users'].Length | Should Be 1
        }

        It 'Adds basic static route' {
            Mock Test-Path { return $true }
            Mock New-PodePSDrive { return './assets' }

            $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd }
            Route -HttpMethod STATIC -Route '/assets' -Middleware './assets'

            $route = $PodeContext.Server.Routes['static']
            $route | Should Not Be $null
            $route.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should Be $true
            $route['/assets[/]{0,1}(?<file>.*)'].Path | Should Be './assets'
        }

        It 'Throws error when adding static route for non-existing folder' {
            Mock Test-Path { return $false }
            $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd }
            { Route -HttpMethod STATIC -Route '/assets' -Middleware './assets' } | Should Throw 'does not exist'
        }

        It 'Throws error when adding static route under get method' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; 'Root' = $pwd }
            { Route -HttpMethod GET -Route '/assets' -Middleware './assets' } | Should Throw 'invalid type'
        }

        It 'Adds route with middleware supplied as scriptblock and no logic' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' ({ Write-Host 'middle' }) -ScriptBlock $null

            $route = $PodeContext.Server.Routes['get']
            $route | Should Not be $null

            $route = $route['/users']
            $route | Should Not Be $null

            $route.Logic.ToString() | Should Be ({ Write-Host 'middle' }).ToString()
            $route.Middleware | Should Be $null
        }

        It 'Adds route with middleware supplied as hashtable with null logic' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            { Route -HttpMethod GET -Route '/users' (@{ 'Logic' = $null }) -ScriptBlock {} } | Should Throw 'no logic defined'
        }

        It 'Adds route with middleware supplied as hashtable with invalid type logic' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            { Route -HttpMethod GET -Route '/users' (@{ 'Logic' = 74 }) -ScriptBlock {} } | Should Throw 'invalid logic type'
        }

        It 'Adds route with invalid middleware type' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            { Route -HttpMethod GET -Route '/users' 74 -ScriptBlock {} } | Should Throw 'invalid type'
        }

        It 'Adds route with middleware supplied as hashtable and empty logic' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' (@{ 'Logic' = { Write-Host 'middle' }; 'Options' = 'test' }) -ScriptBlock {}

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null

            $routes = $routes['/users']
            $routes | Should Not Be $null
            $routes.Length | Should Be 1

            $routes[0].Logic.ToString() | Should Be ({}).ToString()
            $routes[0].Protocol | Should Be ''
            $routes[0].Endpoint | Should Be ''

            $routes[0].Middleware.Length | Should Be 1
            $routes[0].Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle' }).ToString()
            $routes[0].Middleware[0].Options | Should Be 'test'
        }

        It 'Adds route with middleware supplied as hashtable and no logic' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' (@{ 'Logic' = { Write-Host 'middle' }; 'Options' = 'test' }) -ScriptBlock $null

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null

            $routes = $routes['/users']
            $routes | Should Not Be $null
            $routes.Length | Should Be 1

            $routes[0].Logic.ToString() | Should Be ({}).ToString()
            $routes[0].Protocol | Should Be ''
            $routes[0].Endpoint | Should Be ''

            $routes[0].Middleware.Length | Should Be 1
            $routes[0].Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle' }).ToString()
            $routes[0].Middleware[0].Options | Should Be 'test'
        }

        It 'Adds route with middleware and logic supplied' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' { Write-Host 'middle' } -ScriptBlock { Write-Host 'logic' }

            $routes = $PodeContext.Server.Routes['get']
            $routes | Should Not be $null

            $routes = $routes['/users']
            $routes | Should Not Be $null
            $routes.Length | Should Be 1

            $routes[0].Logic.ToString() | Should Be ({ Write-Host 'logic' }).ToString()
            $routes[0].Protocol | Should Be ''
            $routes[0].Endpoint | Should Be ''

            $routes[0].Middleware.Length | Should Be 1
            $routes[0].Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle' }).ToString()
        }

        It 'Throws error for route with array of middleware and no logic supplied' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }

            { Route -HttpMethod GET -Route '/users' @(
                { Write-Host 'middle1' },
                { Write-Host 'middle2' }
             ) $null } | Should Throw 'no logic defined'

            $route = $PodeContext.Server.Routes['get']
            $route | Should Not be $null

            $route = $route['/users']
            $route | Should Be $null
        }

        It 'Adds route with array of middleware and logic supplied' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users' @(
                { Write-Host 'middle1' },
                { Write-Host 'middle2' }
             ) { Write-Host 'logic' }

            $route = $PodeContext.Server.Routes['get']
            $route | Should Not be $null

            $route = $route['/users']
            $route | Should Not Be $null

            $route.Logic.ToString() | Should Be ({ Write-Host 'logic' }).ToString()
            $route.Middleware.Length | Should Be 2
            $route.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $route.Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()
        }

        It 'Adds route with simple url and querystring' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users?k=v' { Write-Host 'hello' }

            $route = $PodeContext.Server.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users') | Should Be $true
            $route['/users'] | Should Not Be $null
            $route['/users'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $route['/users'].Middleware | Should Be $null
        }

        It 'Adds route with url parameters' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users/:userId' { Write-Host 'hello' }

            $route = $PodeContext.Server.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
            $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
            $route['/users/(?<userId>[\w-_]+?)'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $route['/users/(?<userId>[\w-_]+?)'].Middleware | Should Be $null
        }

        It 'Adds route with url parameters and querystring' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Route -HttpMethod GET -Route '/users/:userId?k=v' { Write-Host 'hello' }

            $route = $PodeContext.Server.Routes['get']
            $route | Should Not be $null
            $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
            $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
            $route['/users/(?<userId>[\w-_]+?)'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
            $route['/users/(?<userId>[\w-_]+?)'].Middleware | Should Be $null
        }
    }
}

Describe 'Remove-PodeRoute' {

    Context 'Input Validation'{
        It 'Route Empty'{
            { Remove-PodeRoute 'GET' ' ' } | Should Throw 'No route supplied for removing the GET definition'
        }
    }

    It 'Adds route and remove it' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Route -HttpMethod GET -Route '/users' { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null

        Remove-PodeRoute 'GET' '/users'

        $routes = $PodeContext.Server.Routes['get']
        $routes.Keys.Count | Should be 0
    }

    It 'Adds route and remove it and remove it again' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Route -HttpMethod GET -Route '/users' { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null

        Remove-PodeRoute 'GET' '/users'

        $routes = $PodeContext.Server.Routes['get']
        $routes.Keys.Count | Should be 0

        Remove-PodeRoute 'GET' '/users'

        $routes = $PodeContext.Server.Routes['get']
        $routes.Keys.Count | Should be 0
    }
}

Describe 'Add-PodeStaticRoute' {

    Context 'Input Validation'{
        It 'Route Empty'{
            { Add-PodeStaticRoute ' ' 'Source' } | Should Throw 'No route supplied for static definition'
        }

        It 'Source Empty'{
            { Add-PodeStaticRoute '/users' ' ' } | Should Throw 'No path supplied for static definition'
        }

        It 'Source file does not exist'{
            { Add-PodeStaticRoute '/users' 'folderDoesNotExist' } | Should Throw 'Source folder supplied for static route does not exist: folderDoesNotExist'
        }
    }

    It 'Adds basic static route' {
        Mock Test-Path { return $true }
        Mock New-PodePSDrive { return './assets' }

        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd }
        Add-PodeStaticRoute -Route '/assets' -Source './assets'

        $route = $PodeContext.Server.Routes['static']
        $route | Should Not Be $null
        $route.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should Be $true
        $route['/assets[/]{0,1}(?<file>.*)'].Path | Should Be './assets'
    }
}