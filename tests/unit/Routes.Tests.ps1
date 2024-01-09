BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    $PodeContext = @{ 'Server' = $null; }
}

Describe 'Find-PodeRoute' {
    Context 'Invalid parameters supplied' {
        It 'Throw invalid method error for no method' {
            { Find-PodeRoute -Method 'MOO' -Path '/' } | Should -Throw -ExpectedMessage "*Cannot validate argument on parameter 'Method'*"
        }

        It 'Throw null route parameter error' {
            { Find-PodeRoute -Method GET -Path $null } | Should -Throw -ExpectedMessage '*The argument is null or empty*'
        }

        It 'Throw empty route parameter error' {
            { Find-PodeRoute -Method GET -Path ([string]::Empty) } | Should -Throw -ExpectedMessage '*The argument is null or empty*'
        }
    }

    Context 'Valid method and route' {
        It 'Return null as method does not exist' {
            $PodeContext.Server = @{ 'Routes' = @{}; }
            Find-PodeRoute -Method GET -Path '/' | Should -Be $null
        }

        It 'Returns no logic for method/route that do not exist' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; }
            Find-PodeRoute -Method GET -Path '/' | Should -Be $null
        }

        It 'Returns logic for method and exact route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(@{ 'Logic' = { Write-Host 'Test' }; }); }; }; }
            $result = (Find-PodeRoute -Method GET -Path '/')

            $result | Should -BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should -Be ({ Write-Host 'Test' }).ToString()
        }

        It 'Returns logic for method and exact route and endpoint' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(
                            @{ 'Logic' = { Write-Host 'Test' }; }
                            @{ 'Logic' = { Write-Host 'Test' }; 'Endpoint' = @{ Name = 'example'; 'Address' = 'pode.foo.com' } }
                        )
                    }
                }
            }

            $result = (Find-PodeRoute -Method GET -Path '/' -EndpointName 'example')

            $result | Should -BeOfType System.Collections.Hashtable
            $result.Endpoint.Address | Should -Be 'pode.foo.com'
            $result.Logic.ToString() | Should -Be ({ Write-Host 'Test' }).ToString()
        }

        It 'Returns logic and middleware for method and exact route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/' = @(@{ 'Logic' = { Write-Host 'Test' }; 'Middleware' = { Write-Host 'Middle' }; }); }; }; }
            $result = (Find-PodeRoute -Method GET -Path '/')

            $result | Should -BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should -Be ({ Write-Host 'Test' }).ToString()
            $result.Middleware.ToString() | Should -Be ({ Write-Host 'Middle' }).ToString()
        }

        It 'Returns logic for method and exact route under star' {
            $PodeContext.Server = @{ 'Routes' = @{ '*' = @{ '/' = @(@{ 'Logic' = { Write-Host 'Test' }; }); }; }; }
            $result = (Find-PodeRoute -Method * -Path '/')

            $result | Should -BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should -Be ({ Write-Host 'Test' }).ToString()
        }

        It 'Returns logic and parameters for parameterised route' {
            $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{ '/(?<userId>[^\/]+?)' = @(@{ 'Logic' = { Write-Host 'Test' }; }); }; }; }
            $result = (Find-PodeRoute -Method GET -Path '/123')

            $result | Should -BeOfType System.Collections.Hashtable
            $result.Logic.ToString() | Should -Be ({ Write-Host 'Test' }).ToString()
        }
    }
}

Describe 'Add-PodeStaticRoute' {
    It 'Adds basic static route' {
        Mock Test-PodePath { return $true }
        Mock New-PodePSDrive { return './assets' }

        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd; FindEndpoints = @{} }
        Add-PodeStaticRoute -Path '/assets' -Source './assets'

        $route = $PodeContext.Server.Routes['static']
        $route | Should -Not -Be $null
        $route.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should -Be $true
        $route['/assets[/]{0,1}(?<file>.*)'].Source | Should -Be './assets'
    }

    It 'Throws error when adding static route for non-existing folder' {
        Mock Test-PodePath { return $false }
        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd; FindEndpoints = @{} }
        { Add-PodeStaticRoute -Path '/assets' -Source './assets' } | Should -Throw -ExpectedMessage '*does not exist*'
    }
}

Describe 'Remove-PodeRoute' {
    BeforeEach {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; 'FindEndpoints' = @{}; 'Endpoints' = @{}; 'EndpointsMap' = @{}
            'OpenAPI' = @{
                SelectedDefinitionTag = 'default'
                Definitions           = @{
                    default = Get-PodeOABaseObject
                }
            }
        }
    }
    It 'Adds route with simple url, and then removes it' {
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'].Length | Should -Be 1

        Remove-PodeRoute -Method Get -Path '/users'

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $false
    }

    It 'Adds two routes with simple url, and then removes one' {

        Add-PodeEndpoint -Address '127.0.0.1' -Port 8080 -Protocol Http -Name user

        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Get -Path '/users' -EndpointName user -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'].Length | Should -Be 2

        Remove-PodeRoute -Method Get -Path '/users'

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'].Length | Should -Be 1
    }
}

Describe 'Remove-PodeStaticRoute' {
    It 'Adds a static route, and then removes it' {
        Mock Test-PodePath { return $true }
        Mock New-PodePSDrive { return './assets' }

        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd; FindEndpoints = @{} }
        Add-PodeStaticRoute -Path '/assets' -Source './assets'

        $routes = $PodeContext.Server.Routes['static']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should -Be $true
        $routes['/assets[/]{0,1}(?<file>.*)'].Source | Should -Be './assets'

        Remove-PodeStaticRoute -Path '/assets'

        $routes = $PodeContext.Server.Routes['static']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should -Be $false
    }
}

Describe 'Clear-PodeRoutes' {
    BeforeEach {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; 'POST' = @{} }
            'FindEndpoints'               = @{}
            'OpenAPI'                     = @{
                SelectedDefinitionTag = 'default'
                Definitions           = @{
                    default = Get-PodeOABaseObject
                }
            }
        } }
    It 'Adds routes for methods, and clears everything' {
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello1' }
        Add-PodeRoute -Method POST -Path '/messages' -ScriptBlock { Write-Host 'hello2' }

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should -Be $true

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should -Be $true

        Clear-PodeRoutes

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should -Be $false

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should -Be $false
    }

    It 'Adds routes for methods, and clears one method' {
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello1' }
        Add-PodeRoute -Method POST -Path '/messages' -ScriptBlock { Write-Host 'hello2' }

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should -Be $true

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should -Be $true

        Clear-PodeRoutes -Method Get

        $routes = $PodeContext.Server.Routes['get']
        $routes.ContainsKey('/users') | Should -Be $false

        $routes = $PodeContext.Server.Routes['post']
        $routes.ContainsKey('/messages') | Should -Be $true
    }
}

Describe 'Clear-PodeStaticRoutes' {
    It 'Adds some static routes, and clears them all' {
        Mock Test-PodePath { return $true }
        Mock New-PodePSDrive { return './assets' }

        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd; FindEndpoints = @{} }

        Add-PodeStaticRoute -Path '/assets' -Source './assets'
        Add-PodeStaticRoute -Path '/images' -Source './images'

        $routes = $PodeContext.Server.Routes['static']
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should -Be $true
        $routes.ContainsKey('/images[/]{0,1}(?<file>.*)') | Should -Be $true

        Clear-PodeStaticRoutes

        $routes = $PodeContext.Server.Routes['static']
        $routes.ContainsKey('/assets[/]{0,1}(?<file>.*)') | Should -Be $false
        $routes.ContainsKey('/images[/]{0,1}(?<file>.*)') | Should -Be $false
    }
}

Describe 'Add-PodeRoute' {
    BeforeEach {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; }; 'FindEndpoints' = @{}
            'Endpoints' = @{}
            'OpenAPI' = @{
                SelectedDefinitionTag = 'default'
                Definitions           = @{
                    default = Get-PodeOABaseObject
                }
            }
        }
    }
    It 'Throws invalid method error for no method' {
        { Add-PodeRoute -Method 'MOO' -Path '/' -ScriptBlock {} } | Should -Throw -ExpectedMessage "*Cannot validate argument on parameter 'Method'*"
    }

    It 'Throws null route parameter error' {
        { Add-PodeRoute -Method GET -Path $null -ScriptBlock {} } | Should -Throw -ExpectedMessage '*it is an empty string*'
    }

    It 'Throws empty route parameter error' {
        { Add-PodeRoute -Method GET -Path ([string]::Empty) -ScriptBlock {} } | Should -Throw -ExpectedMessage '*it is an empty string*'
    }

    It 'Throws error when scriptblock and file path supplied' {
        { Add-PodeRoute -Method GET -Path '/' -ScriptBlock { write-host 'hi' } -FilePath './path' } | Should -Throw -ExpectedMessage '*parameter set cannot be resolved*'
    }

    It 'Throws error when file path is a directory' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Test-PodePath { return $true }
        { Add-PodeRoute -Method GET -Path '/' -FilePath './path' } | Should -Throw -ExpectedMessage '*cannot be a wildcard or a directory*'
    }

    It 'Throws error when file path is a wildcard' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Test-PodePath { return $true }
        { Add-PodeRoute -Method GET -Path '/' -FilePath './path/*' } | Should -Throw -ExpectedMessage '*cannot be a wildcard or a directory*'
    }

    It 'Throws error because no scriptblock supplied' {
        { Add-PodeRoute -Method GET -Path '/' -ScriptBlock {} } | Should -Throw -ExpectedMessage '*No logic passed*'
    }

    It 'Throws error because only querystring has been given' {
        { Add-PodeRoute -Method GET -Path '?k=v' -ScriptBlock { write-host 'hi' } } | Should -Throw -ExpectedMessage '*No path supplied*'
    }

    It 'Throws error because route already exists' {
        $PodeContext.Server['Routes'] = @{ 'GET' = @{ '/' = @(
                    @{ 'Endpoint' = @{'Protocol' = ''; 'Address' = '' } }
                )
            }
        }

        { Add-PodeRoute -Method GET -Path '/' -ScriptBlock { write-host 'hi' } } | Should -Throw -ExpectedMessage '*already defined*'
    }

    It 'Throws error on GET route for endpoint name not existing' {
        { Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' } -EndpointName 'test' } | Should -Throw -ExpectedMessage '*does not exist*'
    }

    It 'Adds route with simple url' {
        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'] | Should -Not -Be $null
        $routes['/users'].Length | Should -Be 1
        $routes['/users'][0].Logic.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $routes['/users'][0].Middleware | Should -Be $null
        $routes['/users'][0].ContentType | Should -Be ([string]::Empty)
    }

    It 'Adds route with simple url and scriptblock from file path' {
        Mock Get-PodeRelativePath { return $Path }
        Mock Test-PodePath { return $true }
        Mock Use-PodeScript { return { Write-Host 'bye' } }

        Add-PodeRoute -Method GET -Path '/users' -FilePath './path/route.ps1'

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'] | Should -Not -Be $null
        $routes['/users'].Length | Should -Be 1
        $routes['/users'][0].Logic.ToString() | Should -Be ({ Write-Host 'bye' }).ToString()
        $routes['/users'][0].Middleware | Should -Be $null
        $routes['/users'][0].ContentType | Should -Be ([string]::Empty)
    }

    Mock Test-PodePath { return $false }

    It 'Adds route with simple url with content type' {
        Add-PodeRoute -Method GET -Path '/users' -ContentType 'application/json' -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'] | Should -Not -Be $null
        $routes['/users'].Length | Should -Be 1
        $routes['/users'][0].Logic.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $routes['/users'][0].Middleware | Should -Be $null
        $routes['/users'][0].ContentType | Should -Be 'application/json'
    }

    It 'Adds route with simple url with default content type' {
        $PodeContext.Server['Web'] = @{ 'ContentType' = @{
                'Default' = 'text/xml'
                'Routes'  = @{}
            }
        }


        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'] | Should -Not -Be $null
        $routes['/users'].Length | Should -Be 1
        $routes['/users'][0].Logic.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $routes['/users'][0].Middleware | Should -Be $null
        $routes['/users'][0].ContentType | Should -Be 'text/xml'
    }

    It 'Adds route with simple url with route pattern content type' {
        $PodeContext.Server['Web'] = @{ 'ContentType' = @{
                'Default' = 'text/xml'
                'Routes'  = @{ '/users' = 'text/plain' }
            }
        }

        Add-PodeRoute -Method GET -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null
        $routes.ContainsKey('/users') | Should -Be $true
        $routes['/users'] | Should -Not -Be $null
        $routes['/users'].Length | Should -Be 1
        $routes['/users'][0].Logic.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $routes['/users'][0].Middleware | Should -Be $null
        $routes['/users'][0].ContentType | Should -Be 'text/plain'
    }

    It 'Adds route with middleware supplied as scriptblock and no logic' {
        Add-PodeRoute -Method GET -Path '/users' -Middleware ({ Write-Host 'middle' }) -ScriptBlock {}

        $route = $PodeContext.Server.Routes['get']
        $route | Should -Not -Be $null

        $route = $route['/users']
        $route | Should -Not -Be $null

        $route.Middleware.Logic.ToString() | Should -Be ({ Write-Host 'middle' }).ToString()
        $route.Logic | Should -Be ({}).ToString()
    }

    It 'Adds route with middleware supplied as hashtable with null logic' {
        { Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = $null }) -ScriptBlock {} } | Should -Throw -ExpectedMessage '*no logic defined*'
    }

    It 'Adds route with middleware supplied as hashtable with invalid type logic' {
        { Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = 74 }) -ScriptBlock {} } | Should -Throw -ExpectedMessage '*invalid logic type*'
    }

    It 'Adds route with invalid middleware type' {
        { Add-PodeRoute -Method GET -Path '/users' -Middleware 74 -ScriptBlock {} } | Should -Throw -ExpectedMessage '*invalid type*'
    }

    It 'Adds route with middleware supplied as hashtable and empty logic' {
        Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = { Write-Host 'middle' }; 'Arguments' = 'test' }) -ScriptBlock {}

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null

        $routes = $routes['/users']
        $routes | Should -Not -Be $null
        $routes.Length | Should -Be 1

        $routes[0].Logic.ToString() | Should -Be ({}).ToString()
        $routes[0].Endpoint.Protocol | Should -Be ''
        $routes[0].Endpoint.Address | Should -Be ''

        $routes[0].Middleware.Length | Should -Be 1
        $routes[0].Middleware[0].Logic.ToString() | Should -Be ({ Write-Host 'middle' }).ToString()
        $routes[0].Middleware[0].Arguments | Should -Be 'test'
    }

    It 'Adds route with middleware supplied as hashtable and no logic' {
        Add-PodeRoute -Method GET -Path '/users' -Middleware (@{ 'Logic' = { Write-Host 'middle' }; 'Arguments' = 'test' }) -ScriptBlock {}

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null

        $routes = $routes['/users']
        $routes | Should -Not -Be $null
        $routes.Length | Should -Be 1

        $routes[0].Logic.ToString() | Should -Be ({}).ToString()
        $routes[0].Endpoint.Protocol | Should -Be ''
        $routes[0].Endpoint.Address | Should -Be ''

        $routes[0].Middleware.Length | Should -Be 1
        $routes[0].Middleware[0].Logic.ToString() | Should -Be ({ Write-Host 'middle' }).ToString()
        $routes[0].Middleware[0].Arguments | Should -Be 'test'
    }

    It 'Adds route with middleware and logic supplied' {
        Add-PodeRoute -Method GET -Path '/users' -Middleware { Write-Host 'middle' } -ScriptBlock { Write-Host 'logic' }

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null

        $routes = $routes['/users']
        $routes | Should -Not -Be $null
        $routes.Length | Should -Be 1

        $routes[0].Logic.ToString() | Should -Be ({ Write-Host 'logic' }).ToString()
        $routes[0].Endpoint.Protocol | Should -Be ''
        $routes[0].Endpoint.Address | Should -Be ''

        $routes[0].Middleware.Length | Should -Be 1
        $routes[0].Middleware[0].Logic.ToString() | Should -Be ({ Write-Host 'middle' }).ToString()
    }

    It 'Adds route with array of middleware and no logic supplied' {
        Add-PodeRoute -Method GET -Path '/users' -Middleware @(
            { Write-Host 'middle1' },
            { Write-Host 'middle2' }
        ) -ScriptBlock {}

        $routes = $PodeContext.Server.Routes['get']
        $routes | Should -Not -Be $null

        $routes = $routes['/users']
        $routes | Should -Not -Be $null
        $routes.Length | Should -Be 1

        $routes[0].Logic.ToString() | Should -Be ({}).ToString()

        $routes[0].Middleware.Length | Should -Be 2
        $routes[0].Middleware[0].Logic.ToString() | Should -Be ({ Write-Host 'middle1' }).ToString()
        $routes[0].Middleware[1].Logic.ToString() | Should -Be ({ Write-Host 'middle2' }).ToString()
    }

    It 'Adds route with array of middleware and logic supplied' {
        Add-PodeRoute -Method GET -Path '/users' -Middleware @(
            { Write-Host 'middle1' },
            { Write-Host 'middle2' }
        ) -ScriptBlock { Write-Host 'logic' }

        $route = $PodeContext.Server.Routes['get']
        $route | Should -Not -Be $null

        $route = $route['/users']
        $route | Should -Not -Be $null

        $route.Logic.ToString() | Should -Be ({ Write-Host 'logic' }).ToString()
        $route.Middleware.Length | Should -Be 2
        $route.Middleware[0].Logic.ToString() | Should -Be ({ Write-Host 'middle1' }).ToString()
        $route.Middleware[1].Logic.ToString() | Should -Be ({ Write-Host 'middle2' }).ToString()
    }

    It 'Adds route with simple url and querystring' {
        Add-PodeRoute -Method GET -Path '/users?k=v' -ScriptBlock { Write-Host 'hello' }

        $route = $PodeContext.Server.Routes['get']
        $route | Should -Not -Be $null
        $route.ContainsKey('/users') | Should -Be $true
        $route['/users'] | Should -Not -Be $null
        $route['/users'].Logic.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $route['/users'].Middleware | Should -Be $null
    }

    It 'Adds route with url parameters' {
        Add-PodeRoute -Method GET -Path '/users/:userId' -ScriptBlock { Write-Host 'hello' }

        $route = $PodeContext.Server.Routes['get']
        $route | Should -Not -Be $null
        $route.ContainsKey('/users/(?<userId>[^\/]+?)') | Should -Be $true
        $route['/users/(?<userId>[^\/]+?)'] | Should -Not -Be $null
        $route['/users/(?<userId>[^\/]+?)'].Logic.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $route['/users/(?<userId>[^\/]+?)'].Middleware | Should -Be $null
    }

    It 'Adds route with url parameters and querystring' {
        Add-PodeRoute -Method GET -Path '/users/:userId?k=v' -ScriptBlock { Write-Host 'hello' }

        $route = $PodeContext.Server.Routes['get']
        $route | Should -Not -Be $null
        $route.ContainsKey('/users/(?<userId>[^\/]+?)') | Should -Be $true
        $route['/users/(?<userId>[^\/]+?)'] | Should -Not -Be $null
        $route['/users/(?<userId>[^\/]+?)'].Logic.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        $route['/users/(?<userId>[^\/]+?)'].Middleware | Should -Be $null
    }
}

Describe 'Convert-PodeFunctionVerbToHttpMethod' {
    It 'Returns POST for no Verb' {
        Convert-PodeFunctionVerbToHttpMethod -Verb ([string]::Empty) | Should -Be 'POST'
    }

    It 'Returns POST' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Invoke | Should -Be 'POST'
    }

    It 'Returns GET' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Find | Should -Be 'GET'
    }

    It 'Returns PUT' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Set | Should -Be 'PUT'
    }

    It 'Returns PATCH' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Edit | Should -Be 'PATCH'
    }

    It 'Returns DELETE' {
        Convert-PodeFunctionVerbToHttpMethod -Verb Remove | Should -Be 'DELETE'
    }
}

Describe 'ConvertTo-PodeRoute' {
    BeforeAll {
        Mock Import-PodeModule {}
        Mock Write-Verbose {}
        Mock Add-PodeRoute {}
        Mock Write-PodeJsonResponse {}
        Mock Get-Module { return @{ ExportedCommands = @{ Keys = @('Some-ModuleCommand1', 'Some-ModuleCommand2') } } }
    }
    It 'Throws error when module does not contain command' {
        { ConvertTo-PodeRoute -Module Example -Commands 'Get-ChildItem' } | Should -Throw -ExpectedMessage '*does not contain function*'
    }

    It 'Throws error for no commands' {
        { ConvertTo-PodeRoute } | Should -Throw -ExpectedMessage 'No commands supplied to convert to Routes'
    }

    It 'Calls Add-PodeRoute twice for commands' {
        ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Invoke-Expression') -NoOpenApi
        Assert-MockCalled Add-PodeRoute -Times 2 -Scope It
    }

    It 'Calls Add-PodeRoute twice for module commands' {
        ConvertTo-PodeRoute -Module Example -NoOpenApi
        Assert-MockCalled Add-PodeRoute -Times 2 -Scope It
    }

    It 'Calls Add-PodeRoute once for module filtered commands' {
        ConvertTo-PodeRoute -Module Example -Commands 'Some-ModuleCommand1' -NoOpenApi
        Assert-MockCalled Add-PodeRoute -Times 1 -Scope It
    }
}

Describe 'Add-PodePage' {
    BeforeAll {
        Mock Add-PodeRoute {}
    }

    It 'Throws error for invalid Name' {
        { Add-PodePage -Name 'Rick+Morty' -ScriptBlock {} } | Should -Throw -ExpectedMessage '*should be a valid alphanumeric*'
    }

    It 'Throws error for invalid ScriptBlock' {
        { Add-PodePage -Name 'RickMorty' -ScriptBlock {} } | Should -Throw -ExpectedMessage '*non-empty scriptblock is required*'
    }

    It 'Throws error for invalid FilePath' {
        $PodeContext.Server = @{ 'Root' = $pwd }
        { Add-PodePage -Name 'RickMorty' -FilePath './fake/path' } | Should -Throw -ExpectedMessage '*the path does not exist*'
    }

    It 'Call Add-PodeRoute once for ScriptBlock page' {
        Add-PodePage -Name 'Name' -ScriptBlock { Get-Service }
        Assert-MockCalled Add-PodeRoute -Times 1 -Scope It
    }

    It 'Call Add-PodeRoute once for FilePath page' {
        Mock Get-PodeRelativePath { return $Path }
        Add-PodePage -Name 'Name' -FilePath './fake/path'
        Assert-MockCalled Add-PodeRoute -Times 1 -Scope It
    }

    It 'Call Add-PodeRoute once for FilePath page' {
        Add-PodePage -Name 'Name' -View 'index'
        Assert-MockCalled Add-PodeRoute -Times 1 -Scope It
    }
}

Describe 'Update-PodeRouteSlashes' {
    Context 'Static' {
        It 'Update route slashes' {
            $input = '/route'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route[/]{0,1}(?<file>.*)'
        }

        It 'Update route slashes, no slash' {
            $input = 'route'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route[/]{0,1}(?<file>.*)'
        }

        It 'Update route slashes, ending with wildcard' {
            $input = '/route/*'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route[/]{0,1}(?<file>.*)'
        }

        It 'Update route slashes, ending with wildcard, no slash' {
            $input = 'route/*'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route[/]{0,1}(?<file>.*)'
        }

        It 'Update route slashes, with midpoint wildcard' {
            $input = '/route/*/ending'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route/.*/ending[/]{0,1}(?<file>.*)'
        }

        It 'Update route slashes, with midpoint wildcard, no slash' {
            $input = 'route/*/ending'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route/.*/ending[/]{0,1}(?<file>.*)'
        }

        It 'Update route slashes, with midpoint wildcard, ending with wildcard' {
            $input = '/route/*/ending/*'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route/.*/ending[/]{0,1}(?<file>.*)'
        }

        It 'Update route slashes, with midpoint wildcard, ending with wildcard, no slash' {
            $input = 'route/*/ending/*'
            Update-PodeRouteSlashes -Path $input -Static | Should -Be '/route/.*/ending[/]{0,1}(?<file>.*)'
        }
    }

    Context 'Non Static' {
        It 'Update route slashes' {
            $input = '/route'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route'
        }

        It 'Update route slashes, no slash' {
            $input = 'route'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route'
        }

        It 'Update route slashes, ending with wildcard' {
            $input = '/route/*'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route/.*'
        }

        It 'Update route slashes, ending with wildcard, no slash' {
            $input = 'route/*'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route/.*'
        }

        It 'Update route slashes, with midpoint wildcard' {
            $input = '/route/*/ending'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route/.*/ending'
        }

        It 'Update route slashes, with midpoint wildcard, no slash' {
            $input = 'route/*/ending'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route/.*/ending'
        }

        It 'Update route slashes, with midpoint wildcard, ending with wildcard' {
            $input = '/route/*/ending/*'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route/.*/ending/.*'
        }

        It 'Update route slashes, with midpoint wildcard, ending with wildcard, no slash' {
            $input = 'route/*/ending/*'
            Update-PodeRouteSlashes -Path $input | Should -Be '/route/.*/ending/.*'
        }
    }
}

Describe 'Resolve-PodePlaceholders' {
    It 'Update route placeholders, basic' {
        $input = 'route'
        Resolve-PodePlaceholders -Path $input | Should -Be 'route'
    }

    It 'Update route placeholders' {
        $input = ':route'
        Resolve-PodePlaceholders -Path $input | Should -Be '(?<route>[^\/]+?)'
    }

    It 'Update route placeholders, double with no spacing' {
        $input = ':route:placeholder'
        Resolve-PodePlaceholders -Path $input | Should -Be '(?<route>[^\/]+?)(?<placeholder>[^\/]+?)'
    }

    It 'Update route placeholders, double with double ::' {
        $input = '::route:placeholder'
        Resolve-PodePlaceholders -Path $input | Should -Be ':(?<route>[^\/]+?)(?<placeholder>[^\/]+?)'
    }

    It 'Update route placeholders, double with slash' {
        $input = ':route/:placeholder'
        Resolve-PodePlaceholders -Path $input | Should -Be '(?<route>[^\/]+?)/(?<placeholder>[^\/]+?)'
    }

    It 'Update route placeholders, no update' {
        $input = ': route'
        Resolve-PodePlaceholders -Path $input | Should -Be ': route'
    }
}

Describe 'Split-PodeRouteQuery' {
    It 'Split route, no split' {
        $input = 'route'
        Split-PodeRouteQuery -Path $input | Should -Be 'route'
    }

    It 'Split route, split' {
        $input = 'route?'
        Split-PodeRouteQuery -Path $input | Should -Be 'route'
    }

    It 'Split route, split' {
        $input = 'route?split'
        Split-PodeRouteQuery -Path $input | Should -Be 'route'
    }

    It 'Split route, split, first character' {
        $input = '?route'
        Split-PodeRouteQuery -Path $input | Should -Be ''
    }
}

Describe 'Get-PodeRouteByUrl' {
    BeforeEach {
        $routeNameSet = @{
            Endpoint = @{
                Protocol = 'HTTP'
                Address  = '/assets'
                Name     = 'Example1'
            }
        }

        $routeNoNameSet = @{
            Endpoint = @{
                Protocol = ''
                Address  = '/assets'
                Name     = 'Example2'
            }
        } }

    It 'Single route' {
        $Routes = @($routeNameSet)

        $Result = Get-PodeRouteByUrl -Routes $Routes -EndpointName 'Example1'

        $Result | Should -Not -Be $null
        $Result | Should -Be $routeNameSet
    }

    It 'No routes' {
        $Routes = @()

        $Result = Get-PodeRouteByUrl -Routes $Routes -EndpointName 'Example1'

        $Result | Should -Be $null
    }

    It 'Two routes, sorting' {
        $Routes = @($routeNameSet, $routeNoNameSet)

        $Result = Get-PodeRouteByUrl -Routes $Routes -EndpointName 'Example1'

        $Result | Should -Not -Be $null
        $Result | Should -Be $routeNameSet
    }
}

Describe 'Get-PodeRoute' {
    BeforeAll {
        Mock Test-PodeIPAddress { return $true }
        Mock Test-PodeIsAdminUser { return $true } }
    BeforeEach {
        $PodeContext.Server = @{ 'Routes' = @{ 'GET' = @{}; 'POST' = @{}; }; 'FindEndpoints' = @{}; 'Endpoints' = @{}; 'EndpointsMap' = @{}; 'Type' = $null
            'OpenAPI' = @{
                SelectedDefinitionTag = 'default'
                Definitions           = @{
                    default = Get-PodeOABaseObject
                }
            }
        }
    }

    It 'Returns both routes whe nothing supplied' {
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Get -Path '/about' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Post -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = Get-PodeRoute
        $routes.Length | Should -Be 3
    }

    It 'Returns both routes for GET method' {
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Get -Path '/about' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Post -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = Get-PodeRoute -Method Get
        $routes.Length | Should -Be 2
    }

    It 'Returns one route for POST method' {
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Get -Path '/about' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Post -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = Get-PodeRoute -Method Post
        $routes.Length | Should -Be 1
    }

    It 'Returns both routes for users path' {
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Get -Path '/about' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Post -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = Get-PodeRoute -Path '/users'
        $routes.Length | Should -Be 2
    }

    It 'Returns one route for users path and GET method' {
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Get -Path '/about' -ScriptBlock { Write-Host 'hello' }
        Add-PodeRoute -Method Post -Path '/users' -ScriptBlock { Write-Host 'hello' }

        $routes = Get-PodeRoute -Method Get -Path '/users'
        $routes.Length | Should -Be 1
    }

    It 'Returns one route for users path and endpoint name user' {

        Add-PodeEndpoint -Address '127.0.0.1' -Port 8080 -Protocol Http -Name user
        Add-PodeEndpoint -Address '127.0.0.1' -Port 8081 -Protocol Http -Name admin

        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' } -EndpointName user
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' } -EndpointName admin

        $routes = @(Get-PodeRoute -Method Get -Path '/users' -EndpointName user)
        $routes.Length | Should -Be 1
        $routes[0].Endpoint.Name | Should -Be 'user'
        $routes[0].Endpoint.Address | Should -Be '127.0.0.1:8080'
    }

    It 'Returns both routes for users path and endpoint names' {

        Add-PodeEndpoint -Address '127.0.0.1' -Port 8080 -Protocol Http -Name user
        Add-PodeEndpoint -Address '127.0.0.1' -Port 8081 -Protocol Http -Name admin

        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' } -EndpointName user
        Add-PodeRoute -Method Get -Path '/users' -ScriptBlock { Write-Host 'hello' } -EndpointName admin

        $routes = @(Get-PodeRoute -Method Get -Path '/users' -EndpointName user, admin)
        $routes.Length | Should -Be 2
    }

    It 'Returns both routes for user endpoint name' {

        Add-PodeEndpoint -Address '127.0.0.1' -Port 8080 -Protocol Http -Name user
        Add-PodeEndpoint -Address '127.0.0.1' -Port 8081 -Protocol Http -Name admin

        Add-PodeRoute -Method Get -Path '/users1' -ScriptBlock { Write-Host 'hello' } -EndpointName user, admin
        Add-PodeRoute -Method Get -Path '/users2' -ScriptBlock { Write-Host 'hello' } -EndpointName user, admin

        $routes = @(Get-PodeRoute -Method Get -EndpointName user)
        $routes.Length | Should -Be 2
    }
}

Describe 'Get-PodeStaticRoute' {
    BeforeAll {
        Mock Test-PodePath { return $true }
        Mock New-PodePSDrive { return './assets' }
    }
    BeforeEach {
        $PodeContext.Server = @{ 'Routes' = @{ 'STATIC' = @{}; }; 'Root' = $pwd ; 'FindEndpoints' = @{}; 'Endpoints' = @{}; 'OpenAPI' = @{'default' = (Get-PodeOABaseObject) }; 'SelectedOADefinitionTag' = 'default' }
    }
    It 'Returns all static routes' {
        Add-PodeStaticRoute -Path '/assets' -Source './assets'
        Add-PodeStaticRoute -Path '/images' -Source './images'

        $routes = Get-PodeStaticRoute
        $routes.Length | Should -Be 2
    }

    It 'Returns one static route' {
        Add-PodeStaticRoute -Path '/assets' -Source './assets'
        Add-PodeStaticRoute -Path '/images' -Source './images'

        $routes = Get-PodeStaticRoute -Path '/images'
        $routes.Length | Should -Be 1
    }

    It 'Returns one static route for endpoint name user' {
        $PodeContext.Server = @{ Routes = @{ STATIC = @{}; }; Root = $pwd; Endpoints = @{}; EndpointsMap = @{}; FindEndpoints = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 8080 -Protocol Http -Name user
        Add-PodeEndpoint -Address '127.0.0.1' -Port 8081 -Protocol Http -Name admin

        Add-PodeStaticRoute -Path '/images' -Source './images' -EndpointName user
        Add-PodeStaticRoute -Path '/images' -Source './images' -EndpointName admin

        $routes = @(Get-PodeStaticRoute -Path '/images' -EndpointName user)
        $routes.Length | Should -Be 1
        $routes[0].Endpoint.Name | Should -Be 'user'
        $routes[0].Endpoint.Address | Should -Be '127.0.0.1:8080'
    }

    It 'Returns both routes for users path and endpoint names' {
        $PodeContext.Server = @{ Routes = @{ STATIC = @{}; }; Root = $pwd; Endpoints = @{}; EndpointsMap = @{}; FindEndpoints = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 8080 -Protocol Http -Name user
        Add-PodeEndpoint -Address '127.0.0.1' -Port 8081 -Protocol Http -Name admin

        Add-PodeStaticRoute -Path '/images' -Source './images' -EndpointName user
        Add-PodeStaticRoute -Path '/images' -Source './images' -EndpointName admin

        $routes = @(Get-PodeStaticRoute -Path '/images' -EndpointName user, admin)
        $routes.Length | Should -Be 2
    }

    It 'Returns both routes for user endpoint' {
        $PodeContext.Server = @{ Routes = @{ STATIC = @{}; }; Root = $pwd; Endpoints = @{}; EndpointsMap = @{}; FindEndpoints = @{}; Type = $null }

        Add-PodeEndpoint -Address '127.0.0.1' -Port 8080 -Protocol Http -Name user
        Add-PodeEndpoint -Address '127.0.0.1' -Port 8081 -Protocol Http -Name admin

        Add-PodeStaticRoute -Path '/images1' -Source './images' -EndpointName user, admin
        Add-PodeStaticRoute -Path '/images2' -Source './images' -EndpointName user, admin

        $routes = @(Get-PodeStaticRoute -EndpointName user)
        $routes.Length | Should -Be 2
    }
}

Describe 'Find-PodeRouteTransferEncoding' {
    It 'Returns nothing' {
        Find-PodeRouteTransferEncoding -Path '/users' | Should -Be ([string]::Empty)
    }

    It 'Returns the passed encoding' {
        Find-PodeRouteTransferEncoding -Path '/users' -TransferEncoding 'text/xml' | Should -Be 'text/xml'
    }

    It 'Returns a default encoding' {
        $PodeContext.Server = @{ Web = @{ TransferEncoding = @{ Default = 'text/yml' } } }
        Find-PodeRouteTransferEncoding -Path '/users' | Should -Be 'text/yml'
    }

    It 'Returns a path match' {
        $PodeContext.Server = @{ Web = @{ TransferEncoding = @{ Routes = @{
                        '/users' = 'text/json'
                    }
                }
            }
        }

        Find-PodeRouteTransferEncoding -Path '/users' | Should -Be 'text/json'
    }
}

Describe 'Find-PodeRouteContentType' {
    It 'Returns nothing' {
        Find-PodeRouteContentType -Path '/users' | Should -Be ([string]::Empty)
    }

    It 'Returns the passed type' {
        Find-PodeRouteContentType -Path '/users' -ContentType 'text/xml' | Should -Be 'text/xml'
    }

    It 'Returns a default type' {
        $PodeContext.Server = @{ Web = @{ ContentType = @{ Default = 'text/yml' } } }
        Find-PodeRouteContentType -Path '/users' | Should -Be 'text/yml'
    }

    It 'Returns a path match' {
        $PodeContext.Server = @{ Web = @{ ContentType = @{ Routes = @{
                        '/users' = 'text/json'
                    }
                }
            }
        }

        Find-PodeRouteContentType -Path '/users' | Should -Be 'text/json'
    }
}

Describe 'ConvertTo-PodeMiddleware' {
    BeforeAll {
        $_PSSession = @{}
    }

    It 'Returns no middleware' {
        @(ConvertTo-PodeMiddleware -PSSession $_PSSession) | Should -Be $null
    }

    It 'Errors for invalid middleware type' {
        { ConvertTo-PodeMiddleware -Middleware 'string' -PSSession $_PSSession } | Should -Throw -ExpectedMessage '*invalid type*'
    }

    It 'Errors for invalid middleware hashtable - no logic' {
        { ConvertTo-PodeMiddleware -Middleware @{} -PSSession $_PSSession } | Should -Throw -ExpectedMessage '*no logic defined*'
    }

    It 'Errors for invalid middleware hashtable - logic not scriptblock' {
        { ConvertTo-PodeMiddleware -Middleware @{ Logic = 'string' } -PSSession $_PSSession } | Should -Throw -ExpectedMessage '*invalid logic type*'
    }

    It 'Returns hashtable for single hashtable middleware' {
        $middleware = @{ Logic = { Write-Host 'Hello' } }
        $converted = @(ConvertTo-PodeMiddleware -Middleware $middleware -PSSession $_PSSession)
        $converted.Length | Should -Be 1
        $converted[0].Logic.ToString() | Should -Be ($middleware.Logic.ToString())
    }

    It 'Returns hashtable for multiple hashtable middleware' {
        $middleware1 = @{ Logic = { Write-Host 'Hello1' } }
        $middleware2 = @{ Logic = { Write-Host 'Hello2' } }

        $converted = @(ConvertTo-PodeMiddleware -Middleware @($middleware1, $middleware2) -PSSession $_PSSession)

        $converted.Length | Should -Be 2
        $converted[0].Logic.ToString() | Should -Be ($middleware1.Logic.ToString())
        $converted[1].Logic.ToString() | Should -Be ($middleware2.Logic.ToString())
    }

    It 'Converts single scriptblock middleware to hashtable' {
        $middleware = { Write-Host 'Hello' }
        $converted = @(ConvertTo-PodeMiddleware -Middleware $middleware -PSSession $_PSSession)
        $converted.Length | Should -Be 1
        $converted[0].Logic.ToString() | Should -Be ($middleware.ToString())
    }

    It 'Converts multiple scriptblock middleware to hashtable' {
        $middleware1 = { Write-Host 'Hello1' }
        $middleware2 = { Write-Host 'Hello2' }

        $converted = @(ConvertTo-PodeMiddleware -Middleware @($middleware1, $middleware2) -PSSession $_PSSession)

        $converted.Length | Should -Be 2
        $converted[0].Logic.ToString() | Should -Be ($middleware1.ToString())
        $converted[1].Logic.ToString() | Should -Be ($middleware2.ToString())
    }

    It 'Handles a mixture of hashtable and scriptblock' {
        $middleware1 = @{ Logic = { Write-Host 'Hello1' } }
        $middleware2 = { Write-Host 'Hello2' }

        $converted = @(ConvertTo-PodeMiddleware -Middleware @($middleware1, $middleware2) -PSSession $_PSSession)

        $converted.Length | Should -Be 2
        $converted[0].Logic.ToString() | Should -Be ($middleware1.Logic.ToString())
        $converted[1].Logic.ToString() | Should -Be ($middleware2.ToString())
    }
}