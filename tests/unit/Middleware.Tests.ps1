$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

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
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(
                @{ 'Name' = $null; 'Logic' = { write-host 'pre1' } }
            ); }; }

            $logic = Get-PodeInbuiltMiddleware -Name '__pode_mw_access__' -ScriptBlock { write-host 'in1' }

            $logic | Should Not Be $null
            $logic.Name | Should Be '__pode_mw_access__'
            $logic.Logic.ToString() | Should Be ({ write-host 'in1' }).ToString()

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic | Should Be ({ write-host 'pre1' }).ToString()
        }

        It 'using default override logic' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(
                @{ 'Name' = $null; 'Logic' = { write-host 'pre1' } };
                @{ 'Name' = '__pode_mw_access__'; 'Logic' = { write-host 'over1' } }
            ); }; }

            $logic = Get-PodeInbuiltMiddleware -Name '__pode_mw_access__' -ScriptBlock { write-host 'in1' }

            $logic | Should Not Be $null
            $logic.Name | Should Be '__pode_mw_access__'
            $logic.Logic.ToString() | Should Be ({ write-host 'over1' }).ToString()

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic | Should Be ({ write-host 'pre1' }).ToString()
        }
    }
}

Describe 'Middleware' {
    Context 'Valid parameters' {
        It 'Adds single middleware script to list' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -ScriptBlock { write-host 'middle1' }

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
        }

        It 'Adds single middleware script to list with route' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -Route '/api' -ScriptBlock { write-host 'middle1' }

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeContext.Server.Middleware[0].Route | Should Be '/api'
        }

        It 'Adds two middleware scripts to list' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -ScriptBlock { write-host 'middle1' }
            Add-PodeMiddleware -Name 'Test2' -ScriptBlock { write-host 'middle2' }

            $PodeContext.Server.Middleware.Length | Should Be 2
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeContext.Server.Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()
        }

        It 'Adds middleware script to override inbuilt ones' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name '__pode_mw_access__' -ScriptBlock { write-host 'middle1' }

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeContext.Server.Middleware[0].Name | Should Be '__pode_mw_access__'
        }

        It 'Throws error when adding middleware script with duplicate name' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -ScriptBlock { write-host 'middle1' }
            { Add-PodeMiddleware -Name 'Test1' -ScriptBlock { write-host 'middle2' } } | Should Throw 'already defined'
        }

        It 'Throws error when adding middleware hash with no logic' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }
            { Add-PodeMiddleware -Name 'Test1' -InputObject @{ 'Rand' = { write-host 'middle1' } } } | Should Throw 'no logic supplied'
        }

        It 'Adds single middleware hash to list' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -InputObject @{ 'Logic' = { write-host 'middle1' } }

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
        }

        It 'Adds single middleware hash to list with route' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -Route '/api' -InputObject @{ 'Logic' = { write-host 'middle1' } }

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeContext.Server.Middleware[0].Route | Should Be '/api'
        }

        It 'Adds two middleware hashs to list' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -InputObject @{ 'Logic' = { write-host 'middle1' } }
            Add-PodeMiddleware -Name 'Test2' -InputObject @{ 'Logic' = { write-host 'middle2' } }

            $PodeContext.Server.Middleware.Length | Should Be 2
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeContext.Server.Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()
        }

        It 'Adds middleware hash to override inbuilt ones' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name '__pode_mw_access__' -InputObject @{ 'Logic' = { write-host 'middle1' } }

            $PodeContext.Server.Middleware.Length | Should Be 1
            $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
            $PodeContext.Server.Middleware[0].Name | Should Be '__pode_mw_access__'
        }

        It 'Throws error when adding middleware hash with duplicate name' {
            $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

            Add-PodeMiddleware -Name 'Test1' -InputObject @{ 'Logic' = { write-host 'middle1' } }
            { Add-PodeMiddleware -Name 'Test1' -InputObject @{ 'Logic' = { write-host 'middle2' } } } | Should Throw 'already defined'
        }
    }
}

Describe 'Invoke-PodeMiddleware' {
    It 'Returns true for no middleware' {
        (Invoke-PodeMiddleware -WebEvent @{} -Middleware @()) | Should Be $true
    }

    It 'Runs the logic for a single middleware and returns true' {
        Mock Invoke-PodeScriptBlock { return $true }
        $WebEvent = @{ 'Middleware' = @{} }
        $midware = @{
            'Options' = @{};
            'Logic' = { 'test' | Out-Null };
        }

        Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware @($midware) | Should Be $true

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
    }

    It 'Runs the logic for a single middleware mapped to a route' {
        Mock Invoke-PodeScriptBlock { return $true }
        $WebEvent = @{ 'Middleware' = @{} }
        $midware = @{
            'Options' = @{};
            'Route' = '/';
            'Logic' = { 'test' | Out-Null };
        }

        Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware @($midware) -Route '/' | Should Be $true

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
    }

    It 'Runs the logic for two middlewares and returns true' {
        Mock Invoke-PodeScriptBlock { return $true }
        $WebEvent = @{ 'Middleware' = @{} }

        $midware1 = @{
            'Options' = @{};
            'Logic' = { 'test' | Out-Null };
        }

        $midware2 = @{
            'Options' = @{};
            'Logic' = { 'test2' | Out-Null };
        }

        Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware @($midware1, $midware2) | Should Be $true

        Assert-MockCalled Invoke-PodeScriptBlock -Times 2 -Scope It
    }

    It 'Runs the logic for a single middleware and returns false' {
        Mock Invoke-PodeScriptBlock { return $false }
        $WebEvent = @{ 'Middleware' = @{} }
        $midware = @{
            'Options' = @{};
            'Logic' = { 'test' | Out-Null };
        }

        Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware @($midware) | Should Be $false

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
    }

    It 'Runs the logic for a single middleware and returns false after erroring' {
        Mock Invoke-PodeScriptBlock { throw 'some error' }
        Mock Write-PodeErrorLog { }
        Mock Set-PodeResponseStatus { }

        $WebEvent = @{ 'Middleware' = @{} }
        $midware = @{
            'Options' = @{};
            'Logic' = { 'test' | Out-Null };
        }

        Invoke-PodeMiddleware -WebEvent $WebEvent -Middleware @($midware) | Should Be $false

        Assert-MockCalled Invoke-PodeScriptBlock -Times 1 -Scope It
        Assert-MockCalled Set-PodeResponseStatus -Times 1 -Scope It
    }
}

Describe 'Get-PodeAccessMiddleware' {
    Mock Get-PodeInbuiltMiddleware { return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    } }

    It 'Returns a ScriptBlock and invokes it as true' {
        $r = Get-PodeAccessMiddleware
        $r.Name | Should Be '__pode_mw_access__'
        $r.Logic | Should Not Be $null

        Mock Test-PodeIPAccess { return $true }
        (. $r.Logic @{
            'Request' = @{ 'RemoteEndPoint' = @{ 'Address' = 'localhost' } }
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock and invokes it as false' {
        $r = Get-PodeAccessMiddleware
        $r.Name | Should Be '__pode_mw_access__'
        $r.Logic | Should Not Be $null

        Mock Test-PodeIPAccess { return $false }
        Mock Set-PodeResponseStatus { }
        (. $r.Logic @{
            'Request' = @{ 'RemoteEndPoint' = @{ 'Address' = 'localhost' } }
        }) | Should Be $false
    }
}

Describe 'Get-PodeLimitMiddleware' {
    Mock Get-PodeInbuiltMiddleware { return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    } }

    It 'Returns a ScriptBlock and invokes it as true' {
        $r = Get-PodeLimitMiddleware
        $r.Name | Should Be '__pode_mw_rate_limit__'
        $r.Logic | Should Not Be $null

        Mock Test-PodeIPLimit { return $true }
        (. $r.Logic @{
            'Request' = @{ 'RemoteEndPoint' = @{ 'Address' = 'localhost' } }
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock and invokes it as false' {
        $r = Get-PodeLimitMiddleware
        $r.Name | Should Be '__pode_mw_rate_limit__'
        $r.Logic | Should Not Be $null

        Mock Test-PodeIPLimit { return $false }
        Mock Set-PodeResponseStatus { }
        (. $r.Logic @{
            'Request' = @{ 'RemoteEndPoint' = @{ 'Address' = 'localhost' } }
        }) | Should Be $false
    }
}

Describe 'Get-PodeRouteValidateMiddleware' {
    Mock Get-PodeInbuiltMiddleware { return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    } }

    It 'Returns a ScriptBlock and invokes it as true' {
        $WebEvent = @{ 'Parameters' = @{} }

        $r = Get-PodeRouteValidateMiddleware
        $r.Name | Should Be '__pode_mw_route_validation__'
        $r.Logic | Should Not Be $null

        Mock Find-PodeRoute { return @{ 'Parameters' = @{}; 'Logic' = { Write-Host 'hello' }; } }
        (. $r.Logic @{
            'Method' = 'GET';
            'Path' = '/';
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock and invokes it as true, overriding the content type' {
        $WebEvent = @{
            Parameters = @{};
            ContentType = 'text/plain'
            Method = 'GET'
            Path = '/'
        }

        $r = Get-PodeRouteValidateMiddleware
        $r.Name | Should Be '__pode_mw_route_validation__'
        $r.Logic | Should Not Be $null

        Mock Find-PodeRoute { return @{
            'Parameters' = @{};
            'Logic' = { Write-Host 'hello' };
            'ContentType' = 'application/json';
        } }

        (. $r.Logic $WebEvent) | Should Be $true
        $WebEvent.ContentType | Should Be 'application/json'
    }

    It 'Returns a ScriptBlock and invokes it as false' {
        $r = Get-PodeRouteValidateMiddleware
        $r.Name | Should Be '__pode_mw_route_validation__'
        $r.Logic | Should Not Be $null

        Mock Find-PodeRoute { return $null }
        Mock Set-PodeResponseStatus { }
        (. $r.Logic @{
            'Method' = 'GET';
            'Path' = '/';
        }) | Should Be $false
    }
}

Describe 'Get-PodeBodyMiddleware' {
    Mock Get-PodeInbuiltMiddleware { return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    } }

    It 'Returns a ScriptBlock and invokes it as true' {
        $r = Get-PodeBodyMiddleware
        $r.Name | Should Be '__pode_mw_body_parsing__'
        $r.Logic | Should Not Be $null

        Mock ConvertFrom-PodeRequestContent { return @{ 'Data' = @{}; 'Files' = @{}; } }
        (. $r.Logic @{
            'Request' = 'value'
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock and invokes it as false' {
        $r = Get-PodeBodyMiddleware
        $r.Name | Should Be '__pode_mw_body_parsing__'
        $r.Logic | Should Not Be $null

        Mock ConvertFrom-PodeRequestContent { throw 'error' }
        Mock Set-PodeResponseStatus { }
        (. $r.Logic @{
            'Request' = 'value'
        }) | Should Be $false
    }
}

Describe 'Get-PodeQueryMiddleware' {
    Mock Get-PodeInbuiltMiddleware { return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    } }

    It 'Returns a ScriptBlock and invokes it as true' {
        $r = Get-PodeQueryMiddleware
        $r.Name | Should Be '__pode_mw_query_parsing__'
        $r.Logic | Should Not Be $null

        Mock ConvertFrom-PodeNameValueToHashTable { return 'string' }
        (. $r.Logic @{
            'Request' = @{ 'QueryString' = [System.Web.HttpUtility]::ParseQueryString('name=bob') }
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock and invokes it as false' {
        $r = Get-PodeQueryMiddleware
        $r.Name | Should Be '__pode_mw_query_parsing__'
        $r.Logic | Should Not Be $null

        Mock ConvertFrom-PodeNameValueToHashTable { throw 'error' }
        Mock Set-PodeResponseStatus { }
        (. $r.Logic @{
            'Request' = @{ 'QueryString' = 'name=bob' }
        }) | Should Be $false
    }
}

Describe 'Get-PodePublicMiddleware' {
    Mock Get-PodeInbuiltMiddleware { return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    } }

    It 'Returns a ScriptBlock, invokes true for no static path' {
        $r = Get-PodePublicMiddleware
        $r.Name | Should Be '__pode_mw_static_content__'
        $r.Logic | Should Not Be $null

        Mock Find-PodeStaticRoutePath { return @{ 'Source' = $null } }
        (. $r.Logic @{
            'Path' = '/'; 'Protocol' = 'http'; 'Endpoint' = '';
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock, invokes false for static path, flagged as download' {
        $r = Get-PodePublicMiddleware
        $r.Name | Should Be '__pode_mw_static_content__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{
            'Web' = @{ 'Static' = @{ } }
        }}

        Mock Find-PodeStaticRoutePath { return @{ 'Source' = '/'; 'Download' = $true } }
        Mock Set-PodeResponseAttachment { }
        (. $r.Logic @{
            'Path' = '/'; 'Protocol' = 'http'; 'Endpoint' = '';
        }) | Should Be $false

        Assert-MockCalled Set-PodeResponseAttachment -Times 1 -Scope It
    }

    It 'Returns a ScriptBlock, invokes false for static path, with no caching' {
        $r = Get-PodePublicMiddleware
        $r.Name | Should Be '__pode_mw_static_content__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{
            'Web' = @{ 'Static' = @{
                'Cache' = @{
                    'Enabled' = $false
                }
            }}
        }}

        Mock Find-PodeStaticRoutePath { return @{ 'Source' = '/' } }
        Mock Write-PodeFileResponse { }
        (. $r.Logic @{
            'Path' = '/'; 'Protocol' = 'http'; 'Endpoint' = '';
        }) | Should Be $false

        Assert-MockCalled Write-PodeFileResponse -Times 1 -Scope It
    }

    It 'Returns a ScriptBlock, invokes false for static path, with no caching from exclude' {
        $r = Get-PodePublicMiddleware
        $r.Name | Should Be '__pode_mw_static_content__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{
            'Web' = @{ 'Static' = @{
                'Cache' = @{
                    'Enabled' = $true;
                    'Exclude' = '/'
                }
            }}
        }}

        Mock Find-PodeStaticRoutePath { return @{ 'Source' = '/' } }
        Mock Write-PodeFileResponse { }
        (. $r.Logic @{
            'Path' = '/'; 'Protocol' = 'http'; 'Endpoint' = '';
        }) | Should Be $false

        Assert-MockCalled Write-PodeFileResponse -Times 1 -Scope It
    }

    It 'Returns a ScriptBlock, invokes false for static path, with no caching from include' {
        $r = Get-PodePublicMiddleware
        $r.Name | Should Be '__pode_mw_static_content__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{
            'Web' = @{ 'Static' = @{
                'Cache' = @{
                    'Enabled' = $true;
                    'Include' = '/route'
                }
            }}
        }}

        Mock Find-PodeStaticRoutePath { return @{ 'Source' = '/' } }
        Mock Write-PodeFileResponse { }
        (. $r.Logic @{
            'Path' = '/'; 'Protocol' = 'http'; 'Endpoint' = '';
        }) | Should Be $false

        Assert-MockCalled Write-PodeFileResponse -Times 1 -Scope It
    }

    It 'Returns a ScriptBlock, invokes false for static path, with caching' {
        $r = Get-PodePublicMiddleware
        $r.Name | Should Be '__pode_mw_static_content__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{
            'Web' = @{ 'Static' = @{
                'Cache' = @{
                    'Enabled' = $true;
                }
            }}
        }}

        Mock Find-PodeStaticRoutePath { return @{ 'Source' = '/' } }
        Mock Write-PodeFileResponse { }
        (. $r.Logic @{
            'Path' = '/'; 'Protocol' = 'http'; 'Endpoint' = '';
        }) | Should Be $false

        Assert-MockCalled Write-PodeFileResponse -Times 1 -Scope It
    }
}

Describe 'Get-PodeCookieMiddleware' {
    Mock Get-PodeInbuiltMiddleware { return @{
        'Name' = $Name;
        'Logic' = $ScriptBlock;
    } }

    It 'Returns a ScriptBlock, invokes true for not being serverless' {
        $r = Get-PodeCookieMiddleware
        $r.Name | Should Be '__pode_mw_cookie_parsing__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $false } }
        (. $r.Logic @{}) | Should Be $true
    }

    It 'Returns a ScriptBlock, invokes true for cookies already being set' {
        $r = Get-PodeCookieMiddleware
        $r.Name | Should Be '__pode_mw_cookie_parsing__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }
        (. $r.Logic @{
            'Cookies' = @{ 'test' = 'value' };
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock, invokes true for for no cookies on header' {
        $r = Get-PodeCookieMiddleware
        $r.Name | Should Be '__pode_mw_cookie_parsing__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }
        Mock Get-PodeHeader { return $null }

        (. $r.Logic @{
            'Cookies' = @{};
        }) | Should Be $true
    }

    It 'Returns a ScriptBlock, invokes true and parses cookies' {
        $r = Get-PodeCookieMiddleware
        $r.Name | Should Be '__pode_mw_cookie_parsing__'
        $r.Logic | Should Not Be $null

        $PodeContext = @{ 'Server' = @{ 'IsServerless' = $true } }
        Mock Get-PodeHeader { return 'key1=value1; key2=value2' }

        $WebEvent = @{ 'Cookies' = @{} }

        (. $r.Logic $WebEvent) | Should Be $true

        $WebEvent.Cookies.Count | Should Be 2
        $WebEvent.Cookies['key1'].Value | Should Be 'value1'
        $WebEvent.Cookies['key2'].Value | Should Be 'value2'
    }
}

Describe 'Remove-PodeMiddleware' {
    It 'Adds middleware, then removes it' {
        $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

        Add-PodeMiddleware -Name 'Test1' -ScriptBlock { write-host 'middle1' }

        $PodeContext.Server.Middleware.Length | Should Be 1
        $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()

        Remove-PodeMiddleware -Name 'Test1'

        $PodeContext.Server.Middleware.Length | Should Be 0
    }
}

Describe 'Clear-PodeMiddleware' {
    It 'Adds middleware, then removes them' {
        $PodeContext = @{ 'Server' = @{ 'Middleware' = @(); }; }

        Add-PodeMiddleware -Name 'Test1' -ScriptBlock { write-host 'middle1' }
        Add-PodeMiddleware -Name 'Test2' -ScriptBlock { write-host 'middle2' }

        $PodeContext.Server.Middleware.Length | Should Be 2
        $PodeContext.Server.Middleware[0].Logic.ToString() | Should Be ({ Write-Host 'middle1' }).ToString()
        $PodeContext.Server.Middleware[1].Logic.ToString() | Should Be ({ Write-Host 'middle2' }).ToString()

        Clear-PodeMiddleware

        $PodeContext.Server.Middleware.Length | Should Be 0
    }
}

Describe 'Add-PodeBodyParser' {
    It 'Fails because a script is already defined' {
        $PodeContext = @{ 'Server' = @{ 'BodyParsers' = @{} } }
        { Add-PodeBodyParser -ContentType 'text/xml' -ScriptBlock {} } | Should Not Throw
        { Add-PodeBodyParser -ContentType 'text/xml' -ScriptBlock {} } | Should Throw 'already a body parser'
    }

    It 'Fails on an invalid content-type' {
        $PodeContext = @{ 'Server' = @{ 'BodyParsers' = @{} } }
        { Add-PodeBodyParser -ContentType 'text_xml' -ScriptBlock {} } | Should Throw "Cannot validate argument on parameter 'ContentType'"
    }

    It 'Adds a script for a content-type' {
        $PodeContext = @{ 'Server' = @{ 'BodyParsers' = @{} } }
        { Add-PodeBodyParser -ContentType 'text/xml' -ScriptBlock {} } | Should Not Throw
        $PodeContext.Server.BodyParsers.ContainsKey('text/xml') | Should Be $true
    }
}

Describe 'Remove-PodeBodyParser' {
    It 'Fails on an invalid content-type' {
        $PodeContext = @{ 'Server' = @{ 'BodyParsers' = @{} } }
        { Remove-PodeBodyParser -ContentType 'text_xml' } | Should Throw "Cannot validate argument on parameter 'ContentType'"
    }

    It 'Does nothing if no script set for content-type' {
        $PodeContext = @{ 'Server' = @{ 'BodyParsers' = @{
            'text/xml' = {}
        } } }

        { Remove-PodeBodyParser -ContentType 'text/yaml' } | Should Not Throw
        $PodeContext.Server.BodyParsers.ContainsKey('text/xml') | Should Be $true
    }

    It 'Removes the script for the content-type' {
        $PodeContext = @{ 'Server' = @{ 'BodyParsers' = @{
            'text/xml' = {}
        } } }

        { Remove-PodeBodyParser -ContentType 'text/xml' } | Should Not Throw
        $PodeContext.Server.BodyParsers.ContainsKey('text/xml') | Should Be $false
    }
}