$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

$PodeContext = @{ 'Server' = $null; }

Describe 'Get-PodeRoute' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid method error for no method' {
            { Get-PodeRoute -Method 'MOO' -Route '/' } | Should Throw "Cannot validate argument on parameter 'Method'"
        }

        It 'Throw null route parameter error' {
            { Get-PodeRoute -Method GET -Route $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty route parameter error' {
            { Get-PodeRoute -Method GET -Route ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid method and route' {
        It 'Return null as method does not exist' {
            $PodeContext.Server = @{ 'Routes' = @{}; }
            Get-PodeRoute -Method GET -Route '/' | Should Be $null
        }

        It 'Returns no logic for method/route that do not exist' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Get-PodeRoute -Method GET -Route '/' | Should Be $null
        }

        It 'Returns logic for method and exact route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(@{ 'Logic'= { Write-Host 'Test' }; }); }; }; }
            $result = (Get-PodeRoute -Method GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route and protocol' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                @{ 'Logic'= { Write-Host 'Test' }; };
                @{ 'Logic'= { Write-Host 'Test' }; 'Protocol' = 'http' };
            ); }; }; }

            $result = (Get-PodeRoute -Method GET -Route '/' -Protocol 'http')

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

            $result = (Get-PodeRoute -Method GET -Route '/' -Endpoint 'pode.foo.com')

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

            $result = (Get-PodeRoute -Method GET -Route '/' -Endpoint 'pode.foo.com' -Protocol 'https')

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

            $result = (Get-PodeRoute -Method GET -Route '/' -Endpoint 'localhost:8080')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Endpoint | Should Be '*:8080'
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and middleware for method and exact route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(@{ 'Logic'= { Write-Host 'Test' }; 'Middleware' = { Write-Host 'Middle' }; }); }; }; }
            $result = (Get-PodeRoute -Method GET -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Middleware.ToString() | Should Be ({ Write-Host 'Middle' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic for method and exact route under star' {
            $PodeContext.Server = @{ 'Routes' = @{ '*' = @{ '/' = @(@{ 'Logic'= { Write-Host 'Test' }; }); }; }; }
            $result = (Get-PodeRoute -Method * -Route '/')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()
            $result.Parameters | Should Be $null
        }

        It 'Returns logic and parameters for parameterised route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/(?<userId>[\w-_]+?)' = @(@{ 'Logic'= { Write-Host 'Test' }; }); }; }; }
            $result = (Get-PodeRoute -Method GET -Route '/123')

            $result | Should BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should Be ({ Write-Host 'Test' }).ToString()

            $result.Parameters | Should BeOfType System.Collections.Hashtable
            $result.Parameters['userId'] | Should Be '123'
        }
    }
}

Describe 'Add-PodeStaticRoute' {
    It 'Adds basic static route' {
        Mock Test-PodePath { return $true }
        Mock New-PodePSDrive { return './assets' }

        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd }
        Add-PodeStaticRoute -Path '/assets' -Source './assets'

        $route = $PodeContext.Server.Routes['static']
        $route | Should Not Be $null
        $route.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should Be $true
        $route['/assets[/]{0,1}(?<file>.*)'].Path | Should Be './assets'
    }

    It 'Throws error when adding static route for non-existing folder' {
        Mock Test-PodePath { return $false }
        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd }
        { Add-PodeStaticRoute -Path '/assets' -Source './assets' } | Should Throw 'does not exist'
    }
}

Describe 'Remove-PodeRoute' {
    It 'Adds route with simple url, and then removes it' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }

        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null
        $routes.ContainsKey('/users') | Should Be $true
        $routes['/users'].Length | Should Be 1

        Remove-PodeRoute -Method Get -Path '/users'

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null
        $routes.ContainsKey('/users') | Should Be $false
    }

    It 'Adds two routes with simple url, and then removes one' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }

        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Get -Path '/users' -Protocol Http -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null
        $routes.ContainsKey('/users') | Should Be $true
        $routes['/users'].Length | Should Be 2

        Remove-PodeRoute -Method Get -Path '/users'

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null
        $routes.ContainsKey('/users') | Should Be $true
        $routes['/users'].Length | Should Be 1
    }
}

Describe 'Remove-PodeStaticRoute' {
    It 'Adds a static route, and then removes it' {
        Mock Test-PodePath { return $true }
        Mock New-PodePSDrive { return './assets' }

        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd }
        Add-PodeStaticRoute -Path '/assets' -Source './assets'

        $routes = $PodeContext.Server.Routes['static']
        $routes | Should Not be $null
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should Be $true
        $routes['/assets[/]{0,1}(?<file>.*)'].Path | Should Be './assets'

        Remove-PodeStaticRoute -Path '/assets'

        $routes = $PodeContext.Server.Routes['static']
        $routes | Should Not be $null
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should Be $false
    }
}

Describe 'Clear-PodeRoutes' {
    It 'Adds routes for methods, and clears everything' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; 'POST' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello1' }
        Add-PodeRoute -Method POST -Path '/messages' -ScriptBlock { Write-Host 'hello2' }

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should Be $true

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should Be $true

        Clear-PodeRoutes

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should Be $false

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should Be $false
    }

    It 'Adds routes for methods, and clears one method' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; 'POST' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello1' }
        Add-PodeRoute -Method POST -Path '/messages' -ScriptBlock { Write-Host 'hello2' }

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should Be $true

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should Be $true

        Clear-PodeRoutes -Method Get

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should Be $false

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should Be $true
    }
}

Describe 'Clear-PodeStaticRoutes' {
    It 'Adds some static routes, and clears them all' {
        Mock Test-PodePath { return $true }
        Mock New-PodePSDrive { return './assets' }

        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd }

        Add-PodeStaticRoute -Path '/assets' -Source './assets'
        Add-PodeStaticRoute -Path '/images' -Source './images'

        $routes = $PodeContext.Server.Routes['static']
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should Be $true
        $routes.ContainsKey('/images[/]{0,1}(?<file>.*)') | Should Be $true

        Clear-PodeStaticRoutes

        $routes = $PodeContext.Server.Routes['static']
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should Be $false
        $routes.ContainsKey('/images[/]{0,1}(?<file>.*)') | Should Be $false
    }
}

Describe 'Add-PodeRoute' {
    It 'Throws invalid method error for no method' {
        { Add-PodeRoute -Method 'MOO' -Path '/' -ScriptBlock {} } | Should Throw "Cannot validate argument on parameter 'Method'"
    }

    It 'Throws null route parameter error' {
        { Add-PodeRoute -Method GET -Path $null -ScriptBlock {} } | Should Throw 'it is an empty string'
    }

    It 'Throws empty route parameter error' {
        { Add-PodeRoute -Method GET -Path ([string]::Empty) -ScriptBlock {} } | Should Throw 'it is an empty string'
    }

    It 'Throws error when scriptblock and file path supplied' {
        { Add-PodeRoute -Method GET -Path '/' -ScriptBlock { write-host 'hi' } -FilePath './path' } | Should Throw 'parameter set cannot be resolved'
    }

    It 'Throws error when file path is a directory' {
        Mock Test-PodePath { return $true }
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{} } }
        { Add-PodeRoute -Method GET -Path '/' -FilePath './path' } | Should Throw 'cannot be a wildcard or directory'
    }

    It 'Throws error when file path is a wildcard' {
        Mock Test-PodePath { return $true }
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{} } }
        { Add-PodeRoute -Method GET -Path '/' -FilePath './path/*' } | Should Throw 'cannot be a wildcard or directory'
    }

    It 'Throws error because no scriptblock supplied' {
        { Add-PodeRoute -Method GET -Path '/' -ScriptBlock {} } | Should Throw "No logic passed"
    }

    It 'Throws error because only querystring has been given' {
        { Add-PodeRoute -Method GET -Path "?k=v" -ScriptBlock { write-host 'hi' } } | Should Throw "No path supplied"
    }

    It 'Throws error because route already exists' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
            @{'Protocol' = ''; 'Endpoint' = ''}
        ); }; }; }

        { Add-PodeRoute -Method GET -Path '/' -ScriptBlock { write-host 'hi' } } | Should Throw 'already defined'
    }

    It 'Throws error because route and protocol already exists' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
            @{'Protocol' = ''; 'Endpoint' = ''}
            @{'Protocol' = 'http'; 'Endpoint' = ''}
        ); }; }; }

        { Add-PodeRoute -Method GET -Path '/' -Protocol 'http' -ScriptBlock { write-host 'hi' } } | Should Throw 'already defined for'
    }

    It 'Throws error because route and endpoint already exists' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
            @{'Protocol' = ''; 'Endpoint' = ''}
            @{'Protocol' = ''; 'Endpoint' = 'pode.foo.com:*'}
        ); }; }; }

        { Add-PodeRoute -Method GET -Path '/' -Endpoint 'pode.foo.com' -ScriptBlock { write-host 'hi' } } | Should Throw 'already defined for'
    }

    It 'Throws error because route, endpoint and protocol already exists' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
            @{'Protocol' = ''; 'Endpoint' = ''}
            @{'Protocol' = ''; 'Endpoint' = 'pode.foo.com:*'}
            @{'Protocol' = 'https'; 'Endpoint' = 'pode.foo.com:*'}
        ); }; }; }

        { Add-PodeRoute -Method GET -Path '/' -Protocol 'https' -Endpoint 'pode.foo.com' -ScriptBlock {} } | Should Throw 'already defined for'
    }

    It 'Throws error on GET route for endpoint name not existing' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        { Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' } -EndpointName 'test' } | Should Throw 'does not exist'
    }

    It 'Adds route with simple url' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' }

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
        Mock Use-PodeScript { return { Write-Host 'bye' } }

        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -FilePath './path/route.ps1'

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
        Add-PodeRoute -Method GET -Path '/users' -ContentType 'application/json' -ScriptBlock { Write-Host 'hello' }

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

        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' }

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

        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' }

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
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' } -Endpoint 'pode.foo.com:8080'

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
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' } -Endpoint '8080'

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
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' } -Endpoint 'pode.foo.com'

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
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' } -Protocol 'http'

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null
        $routes.ContainsKey('/users') | Should Be $true
        $routes['/users'] | Should Not Be $null
        $routes['/users'].Length | Should Be 1
        $routes['/users'][0].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        $routes['/users'][0].Middleware | Should Be $null
        $routes['/users'][0].Protocol | Should Be 'http'
    }

    It 'Adds route with middleware supplied as scriptblock and no logic' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -Middleware ({ Write-Host 'middle' }) -ScriptBlock {}

        $route = $PodeContext.Server.Routes['get']
        $route | Should Not be $null

        $route = $route['/users']
        $route | Should Not Be $null

        $route.Middleware.Logic.ToString() | Should Be ({ Write-Host 'middle' }).ToString()
        $route.Logic | Should Be ({}).ToString()
    }

    It 'Adds route with middleware supplied as hashtable with null logic' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        { Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = $null }) -ScriptBlock {} } | Should Throw 'no logic defined'
    }

    It 'Adds route with middleware supplied as hashtable with invalid type logic' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        { Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = 74 }) -ScriptBlock {} } | Should Throw 'invalid logic type'
    }

    It 'Adds route with invalid middleware type' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        { Add-PodeRoute -Method GET -Path '/users' -Middleware 74 -ScriptBlock {} } | Should Throw 'invalid type'
    }

    It 'Adds route with middleware supplied as hashtable and empty logic' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = { Write-Host 'middle' }; 'Arguments' = 'test' }) -ScriptBlock {}

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
        $routes[0].Middleware[0].Arguments | Should Be 'test'
    }

    It 'Adds route with middleware supplied as hashtable and no logic' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = { Write-Host 'middle' }; 'Arguments' = 'test' }) -ScriptBlock {}

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
        $routes[0].Middleware[0].Arguments | Should Be 'test'
    }

    It 'Adds route with middleware and logic supplied' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -Middleware { Write-Host 'middle' } -ScriptBlock { Write-Host 'logic' }

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

    It 'Adds route with array of middleware and no logic supplied' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }

        Add-PodeRoute -Method GET -Path '/users' -Middleware @(
            { Write-Host 'middle1' },
            { Write-Host 'middle2' }
            ) -ScriptBlock {}

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should Not be $null

        $routes = $routes['/users']
        $routes | Should Not Be $null
        $routes.Length | Should Be 1

        $routes[0].Logic.ToString() | Should Be ({}).ToString()

        $routes[0].Middleware.Length | Should Be 2
        $routes[0].Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
        $routes[0].Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()
    }

    It 'Adds route with array of middleware and logic supplied' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users' -Middleware @(
            { Write-Host 'middle1' },
            { Write-Host 'middle2' }
            ) -ScriptBlock { Write-Host 'logic' }

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
        Add-PodeRoute -Method GET -Path '/users?k=v' -ScriptBlock { Write-Host 'hello' }

        $route = $PodeContext.Server.Routes['get']
        $route | Should Not be $null
        $route.ContainsKey('/users') | Should Be $true
        $route['/users'] | Should Not Be $null
        $route['/users'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        $route['/users'].Middleware | Should Be $null
    }

    It 'Adds route with url parameters' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users/:userId' -ScriptBlock { Write-Host 'hello' }

        $route = $PodeContext.Server.Routes['get']
        $route | Should Not be $null
        $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
        $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
        $route['/users/(?<userId>[\w-_]+?)'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        $route['/users/(?<userId>[\w-_]+?)'].Middleware | Should Be $null
    }

    It 'Adds route with url parameters and querystring' {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
        Add-PodeRoute -Method GET -Path '/users/:userId?k=v' -ScriptBlock { Write-Host 'hello' }

        $route = $PodeContext.Server.Routes['get']
        $route | Should Not be $null
        $route.ContainsKey('/users/(?<userId>[\w-_]+?)') | Should Be $true
        $route['/users/(?<userId>[\w-_]+?)'] | Should Not Be $null
        $route['/users/(?<userId>[\w-_]+?)'].Logic.ToString() | Should Be ({ Write-Host 'hello' }).ToString()
        $route['/users/(?<userId>[\w-_]+?)'].Middleware | Should Be $null
    }
}

Describe 'Convert-PodeFunctionVerbToHttpMethod' {
    It 'Returns POST for no Verb' {
        Convert-PodeFunctionVerbToHttpMethod -Verb ([string]::Empty) | Should Be 'POST'
    }

    It 'Returns POST' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Invoke | Should Be 'POST'
    }

    It 'Returns GET' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Find | Should Be 'GET'
    }

    It 'Returns PUT' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Set | Should Be 'PUT'
    }

    It 'Returns PATCH' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Edit | Should Be 'PATCH'
    }

    It 'Returns DELETE' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Remove | Should Be 'DELETE'
    }
}

Describe 'ConvertTo-PodeRoute' {
    Mock Import-PodeModule {}
    Mock Write-Verbose {}
    Mock Add-PodeRoute {}
    Mock Write-PodeJsonResponse {}
    Mock Get-Module { return @{ ExportedCommands = @{ Keys = @('Some-ModuleCommand1', 'Some-ModuleCommand2') } } }

    It 'Throws error when module does not contain command' {
        { ConvertTo-PodeRoute -Module Example -Commands 'Get-ChildItem' } | Should Throw 'does not contain function'
    }

    It 'Throws error for no commands' {
        { ConvertTo-PodeRoute } | Should Throw 'No commands supplied to convert to Routes'
    }

    It 'Calls Add-PodeRoute twice for commands' {
        ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Invoke-Expression')
        Assert-MockCalled Add-PodeRoute -Times 2 -Scope It
    }

    It 'Calls Add-PodeRoute twice for module commands' {
        ConvertTo-PodeRoute -Module Example
        Assert-MockCalled Add-PodeRoute -Times 2 -Scope It
    }

    It 'Calls Add-PodeRoute once for module filtered commands' {
        ConvertTo-PodeRoute -Module Example -Commands 'Some-ModuleCommand1'
        Assert-MockCalled Add-PodeRoute -Times 1 -Scope It
    }
}