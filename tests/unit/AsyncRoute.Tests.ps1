[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
}


Describe 'Set-PodeAsyncRoutePermission' {
    Describe 'Adding Permissions' {
        BeforeEach {
            # Mock Pode context and async routes
            $PodeContext = @{
                AsyncRoutes = @{
                    Enabled      = $true
                    Items        = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                    Results      = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                    HouseKeeping = @{
                        TimerInterval    = 30
                        RetentionMinutes = 10
                    }
                }
            }

            # Example route object to test with
            $route = @{
                AsyncRouteId = 'testRoute'
                IsAsync      = $true
            }
            $PodeContext.AsyncRoutes.Items[$route.AsyncRouteId] = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
            $PodeContext.AsyncRoutes.Items[$route.AsyncRouteId].Permission = @{}
            # Sample users, groups, roles, and scopes
            $users = @('user1', 'user2')
            $groups = @('group1', 'group2')
            $roles = @('role1', 'role2')
            $scopes = @('scope1', 'scope2')
        }

        It 'should add Read permissions for users, groups, roles, and scopes' {
            Set-PodeAsyncRoutePermission -Route $route -Type 'Read' -Users $users -Groups $groups -Roles $roles -Scopes $scopes

            $permissions = $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Read

            $permissions.Users | Should -Be $users
            $permissions.Groups | Should -Be $groups
            $permissions.Roles | Should -Be $roles
            $permissions.Scopes | Should -Be $scopes
        }

        It 'should add Write permissions for users, groups, roles, and scopes' {
            Set-PodeAsyncRoutePermission -Route $route -Type 'Write' -Users $users -Groups $groups -Roles $roles -Scopes $scopes

            $permissions = $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Write

            $permissions.Users | Should -Be $users
            $permissions.Groups | Should -Be $groups
            $permissions.Roles | Should -Be $roles
            $permissions.Scopes | Should -Be $scopes
        }

        It 'should return the route object when PassThru is specified' {
            $result = Set-PodeAsyncRoutePermission -Route $route -Type 'Read' -PassThru

            $result | Should -Be $route
        }

        It 'should throw an exception when Route is null' {
            { Set-PodeAsyncRoutePermission -Route $null -Type 'Read' } | Should -Throw
        }

        It 'should handle multiple routes piped in' {
            $routes = @(
                @{ AsyncRouteId = 'route1' ; IsAsync = $true },
                @{ AsyncRouteId = 'route2' ; IsAsync = $true }
            )

            $PodeContext.AsyncRoutes.Items['route1'] = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
            $PodeContext.AsyncRoutes.Items['route1'].Permission = @{}
            $PodeContext.AsyncRoutes.Items['route2'] = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
            $PodeContext.AsyncRoutes.Items['route2'].Permission = @{}
            $routes | Set-PodeAsyncRoutePermission -Type 'Read' -Users $users

            $PodeContext.AsyncRoutes.Items['route1'].Permission.Read.Users | Should -Be $users
            $PodeContext.AsyncRoutes.Items['route2'].Permission.Read.Users | Should -Be $users
        }

        It 'should initialize the Permission object if not already present' {
            $PodeContext.AsyncRoutes.Items['testRoute'] = @{Permission = @{Read = @{Users = @('user3') } } }

            Set-PodeAsyncRoutePermission -Route $route -Type 'Read' -Users $users

            $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Read.Users | Should -Be ( @('user3') + $users )
        }
    }


    Describe 'Remove' {
        BeforeEach {
            # Mock Pode context and async routes
            $PodeContext = @{
                AsyncRoutes = @{
                    Enabled      = $true
                    Items        = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                    Results      = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                    HouseKeeping = @{
                        TimerInterval    = 30
                        RetentionMinutes = 10
                    }
                }
            }

            # Example route object to test with
            $route = @{
                AsyncRouteId = 'testRoute'
                IsAsync      = $true
            }
            $PodeContext.AsyncRoutes.Items['testRoute'] = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()

            # Initialize permissions for testing remove functionality
            $PodeContext.AsyncRoutes.Items['testRoute'] = @{
                Permission = @{
                    Read  = @{
                        Users  = @('user1', 'user2')
                        Groups = @('group1', 'group2')
                        Roles  = @('role1', 'role2')
                        Scopes = @('scope1', 'scope2')
                    }
                    Write = @{
                        Users  = @('user3', 'user4')
                        Groups = @('group3', 'group4')
                        Roles  = @('role3', 'role4')
                        Scopes = @('scope3', 'scope4')
                    }
                }
            }
        }

        It 'should remove specified users from Read permissions' {
            Set-PodeAsyncRoutePermission -Route $route -Type 'Read' -Users @('user1') -Remove

            $permissions = $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Read

            $permissions.Users | Should -Not -Contain 'user1'
            $permissions.Users | Should -Contain 'user2'
        }

        It 'should remove specified groups from Write permissions' {
            Set-PodeAsyncRoutePermission -Route $route -Type 'Write' -Groups @('group3') -Remove

            $permissions = $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Write

            $permissions.Groups | Should -Not -Contain 'group3'
            $permissions.Groups | Should -Contain 'group4'
        }

        It 'should remove specified roles from Read permissions' {
            Set-PodeAsyncRoutePermission -Route $route -Type 'Read' -Roles @('role1') -Remove

            $permissions = $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Read

            $permissions.Roles | Should -Not -Contain 'role1'
            $permissions.Roles | Should -Contain 'role2'
        }

        It 'should remove specified scopes from Write permissions' {
            Set-PodeAsyncRoutePermission -Route $route -Type 'Write' -Scopes @('scope3') -Remove

            $permissions = $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Write

            $permissions.Scopes | Should -Not -Contain 'scope3'
            $permissions.Scopes | Should -Contain 'scope4'
        }

        It 'should do nothing if the item to remove does not exist' {
            Set-PodeAsyncRoutePermission -Route $route -Type 'Read' -Users @('nonexistentuser') -Remove

            $permissions = $PodeContext.AsyncRoutes.Items['testRoute'].Permission.Read

            $permissions.Users | Should -Contain 'user1'
            $permissions.Users | Should -Contain 'user2'
        }
    }
}


# Assuming the function Export-PodeAsyncRouteInfo is already defined in your session or module

Describe 'Export-PodeAsyncRouteInfo' {

    BeforeEach {
        $testDate = Get-Date
    }
    Context 'When Async contains full details' {
        It 'should export all details into a hashtable' {

            $asyncData = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
            $asyncData['Id'] = 'async-001'
            $asyncData['Cancellable'] = $true
            $asyncData['CreationTime'] = $testDate
            $asyncData['ExpireTime'] = $testDate.AddMinutes(10)
            $asyncData['AsyncRouteId'] = 'TestAsync'
            $asyncData['State'] = 'Completed'
            $asyncData['Permission'] = 'Admin'
            $asyncData['StartingTime'] = $testDate.AddSeconds(30)
            $asyncData['CallbackSettings'] = @{ Url = 'http://example.com/callback' }
            $asyncData['User'] = 'testuser'
            $asyncData['EnableSse'] = $true
            $asyncData['Progress'] = 50
            $asyncData['Runspace'] = @{
                Handler = [pscustomobject]@{ IsCompleted = $true }
            }
            $asyncData['Result'] = 'Success'
            $asyncData['CompletedTime'] = $testDate.AddMinutes(5)
            $asyncData['IsCompleted'] = $true

            $result = Export-PodeAsyncRouteInfo -Async $asyncData

            $result | Should -BeOfType 'hashtable'
            $result.Id | Should -Be 'async-001'
            $result.Cancellable | Should -Be $true
            $result.CreationTime | Should -Be (Format-PodeDateToIso8601 -Date $testDate)
            $result.ExpireTime | Should -Be (Format-PodeDateToIso8601 -Date ($testDate.AddMinutes(10)))
            $result.AsyncRouteId | Should -Be 'TestAsync'
            $result.State | Should -Be 'Completed'
            $result.Permission | Should -Be 'Admin'
            $result.StartingTime | Should -Be (Format-PodeDateToIso8601 -Date ($testDate.AddSeconds(30)))
            $result.CallbackSettings.Url | Should -Be 'http://example.com/callback'
            $result.User | Should -Be 'testuser'
            $result.Sse | Should -BeNullOrEmpty
            $result.Progress | Should -Be 50
            $result.Result | Should -Be 'Success'
            $result.CompletedTime | Should -Be (Format-PodeDateToIso8601 -Date ($testDate.AddMinutes(5)))
            $result.IsCompleted | Should -BeTrue
        }
    }

    Context 'When Raw switch is used' {
        It 'should return the raw ConcurrentDictionary' {
            $asyncData = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
            $asyncData['Id'] = 'async-002'

            $result = Export-PodeAsyncRouteInfo -Async $asyncData -Raw

            $result | Should -BeOfType 'System.Collections.Concurrent.ConcurrentDictionary[string, psobject]'
            $result['Id'] | Should -Be 'async-002'
        }
    }

    Context 'When Async contains minimal details' {
        It 'should handle missing optional keys gracefully' {
            $asyncData = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
            $asyncData['Id'] = 'async-003'
            $asyncData['CreationTime'] = $testDate
            $asyncData['ExpireTime'] = $testDate.AddMinutes(10)
            $asyncData['State'] = 'Running'

            $result = Export-PodeAsyncRouteInfo -Async $asyncData

            $result | Should -BeOfType 'hashtable'
            $result.Id | Should -Be 'async-003'
            $result.CreationTime | Should -Be  (Format-PodeDateToIso8601 -Date $testDate)
            $result.State | Should -Be 'Running'
            $result.ContainsKey('Permission') | Should -Be $false
            $result.ContainsKey('CallbackSettings') | Should -Be $false
        }
    }
}

Describe 'Get-PodeAsyncRouteOperation' {

    BeforeAll {
        $PodeContext = @{
            AsyncRoutes = @{
                Enabled      = $true
                Items        = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                Results      = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                HouseKeeping = @{
                    TimerInterval    = 30
                    RetentionMinutes = 10
                }
            }
        }


        # Add a sample asynchronous route operation to the mock PodeContext
        $operationId1 = '123e4567-e89b-12d3-a456-426614174000'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId1
        $asyncOperationDetails['State'] = 'Running'
        $asyncOperationDetails['Cancellable'] = $true
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['AsyncRouteId'] = 'PesterTest1'
        $PodeContext.AsyncRoutes.Results[$operationId1] = $asyncOperationDetails


        $operationId2 = '123e4567-e89b-12d3-a456-426614174001'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId2
        $asyncOperationDetails['State'] = 'NotStarted'
        $asyncOperationDetails['Cancellable'] = $false
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['AsyncRouteId'] = 'PesterTest2'
        $PodeContext.AsyncRoutes.Results[$operationId2] = $asyncOperationDetails

        $operationId3 = '123e4567-e89b-12d3-a456-426614174002'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId3
        $asyncOperationDetails['State'] = 'Running'
        $asyncOperationDetails['Cancellable'] = $true
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['AsyncRouteId'] = 'PesterTest3'
        $PodeContext.AsyncRoutes.Results[$operationId3] = $asyncOperationDetails

    }

    It 'should return all routes when Id and AsyncRouteId are null' {

        # Act
        $Result = Get-PodeAsyncRouteOperation

        # Assert
        $Result.Count | Should -Be 3
        foreach ($r in $Result) {
            switch ($r.Id ) {
                $operationId1 {
                    $r.AsyncRouteId | Should -Be 'PesterTest1'
                    $r.State | Should -Be 'Running'
                }
                $operationId2 {
                    $r.AsyncRouteId | Should -Be 'PesterTest2'
                    $r.State | Should -Be 'NotStarted'
                }
                $operationId3 {
                    $r.AsyncRouteId | Should -Be 'PesterTest3'
                    $r.State | Should -Be 'Running'
                }
            }
        }
    }

    It 'should return the route with Id "123e4567-e89b-12d3-a456-426614174002"' {
        # Arrange

        # Act
        $Result = Get-PodeAsyncRouteOperation -Id $operationId3

        # Assert
        $Result.Id | Should -Be $operationId3
        $Result.State | Should -Be 'Running'
        $Result.Cancellable | Should -BeTrue
        $Result.AsyncRouteId | Should -Be 'PesterTest3'
    }

    It 'should return routes with AsyncRouteId Route1' {

        # Act
        $Result = Get-PodeAsyncRouteOperation -AsyncRouteId 'PesterTest2'

        # Assert
        $Result.Id | Should -Be $operationId2
        $Result.State | Should -Be 'NotStarted'
        $Result.Cancellable | Should -BeFalse
        $Result.AsyncRouteId | Should -Be 'PesterTest2'
    }

    It 'should return empty when Id does not match' {
        # Arrange
        $MockResults = @()

        # Act
        $Result = Get-PodeAsyncRouteOperation -Id '999'

        # Assert
        $Result | Should -BeNullOrEmpty
    }

    It 'should pass the Raw switch to Export-PodeAsyncRouteInfo' {

        # Act
        $Result = Get-PodeAsyncRouteOperation -Raw

        # Assert
        $Result.Count | should -Be 3
        $Result.GetType().tostring() | should -Be  'System.Collections.Concurrent.ConcurrentDictionary`2[System.String,System.Management.Automation.PSObject]'
    }
}


Describe 'Get-PodeAsyncRouteOperationByFilter' {
    BeforeAll {
        # Mock data setup
        $PodeContext = @{
            AsyncRoutes = @{
                Enabled      = $true
                Items        = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                Results      = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                HouseKeeping = @{
                    TimerInterval    = 30
                    RetentionMinutes = 10
                }
            }
        }

        # Add mock routes

        # Add a sample asynchronous route operation to the mock PodeContext
        $operationId1 = '123e4567-e89b-12d3-a456-426614174000'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId1
        $asyncOperationDetails['State'] = 'Running'
        $asyncOperationDetails['Cancellable'] = $true
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['AsyncRouteId'] = 'PesterTest1'
        $PodeContext.AsyncRoutes.Results[$operationId1] = $asyncOperationDetails


        $operationId2 = '123e4567-e89b-12d3-a456-426614174001'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId2
        $asyncOperationDetails['State'] = 'NotStarted'
        $asyncOperationDetails['Cancellable'] = $false
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['AsyncRouteId'] = 'PesterTest2'
        $PodeContext.AsyncRoutes.Results[$operationId2] = $asyncOperationDetails

        $operationId3 = '123e4567-e89b-12d3-a456-426614174002'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId3
        $asyncOperationDetails['State'] = 'Running'
        $asyncOperationDetails['Cancellable'] = $false
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['AsyncRouteId'] = 'PesterTest3'
        $PodeContext.AsyncRoutes.Results[$operationId3] = $asyncOperationDetails

    }

    It 'should retrieve the operation details for a valid Id' {
        # Act
        $result = Get-PodeAsyncRouteOperationByFilter -Filter @{
            'State'       = @{ 'op' = 'EQ'; 'value' = 'Running' }
            'Cancellable' = @{ 'op' = 'EQ'; 'value' = $true }
        }

        # Assert
        $result['Id'] | Should -Be '123e4567-e89b-12d3-a456-426614174000'
        $result['AsyncRouteId'] | Should -Be 'PesterTest1'
    }

    It 'should return the raw data if -Raw is specified' {
        # Act
        $result = Get-PodeAsyncRouteOperationByFilter -Raw -Filter @{
            'State' = @{ 'op' = 'EQ'; 'value' = 'Running' }
        }

        # Assert
        $result.Count | should -Be 2
        foreach ($r in $result) {
            switch ($r.Id ) {
                $operationId1 {
                    $r | Should -Be $PodeContext.AsyncRoutes.Results[$operationId1]
                }
                $operationId3 {
                    $r | Should -Be $PodeContext.AsyncRoutes.Results[$operationId3]
                }
                $operationId2 {
                    # Fail the test if this case is hit
                    "Unexpected operation ID '$operationId2' found in results." | Should -Fail
                }
                default {
                    # Fail the test if any unexpected operation ID is found
                    "Unexpected operation ID '$($r.Id)' found in results." | Should -Fail
                }

            }
        }
    }

    It 'should throw an exception if the property does not exist' {

        { Get-PodeAsyncRouteOperationByFilter -Filter @{
                'notExist' = @{ 'op' = 'EQ'; 'value' = $true }
            } } | Should -Throw -ExpectedMessage ($PodeLocale.invalidQueryElementExceptionMessage -f 'notExist')
    }
}


# Set-PodeAsyncRouteOASchemaName.Tests.ps1

Describe 'Set-PodeAsyncRouteOASchemaName' {
    # Mocking the dependencies
    Mock -CommandName Test-PodeOADefinitionTag -MockWith { return @('default') }


    # Setting up a mock PodeContext with default values
    BeforeEach {
        $PodeContext = @{
            Server = @{
                OpenApi = @{
                    Definitions = @{
                        default = @{
                            hiddenComponents = @{
                                AsyncRoute = @{
                                    OATypeName         = 'DefaultAsyncRouteTask'
                                    TaskIdName         = 'defaultId'
                                    QueryRequestName   = 'DefaultAsyncRouteTaskQuery'
                                    QueryParameterName = 'DefaultAsyncRouteTaskQueryParameter'
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    It 'Should set the OpenAPI schema names correctly when all parameters are provided' {
        # Arrange
        $params = @{
            OATypeName         = 'CustomTask'
            TaskIdName         = 'CustomId'
            QueryRequestName   = 'CustomQuery'
            QueryParameterName = 'CustomQueryParam'
            OADefinitionTag    = @('default')
        }

        # Act
        Set-PodeAsyncRouteOASchemaName @params

        # Assert
        $definition = $PodeContext.Server.OpenApi.Definitions['default'].hiddenComponents.AsyncRoute
        $definition.OATypeName | Should -Be 'CustomTask'
        $definition.TaskIdName | Should -Be 'CustomId'
        $definition.QueryRequestName | Should -Be 'CustomQuery'
        $definition.QueryParameterName | Should -Be 'CustomQueryParam'
    }

    It 'Should use default values if parameters are not provided' {
        # Arrange
        $params = @{
            OADefinitionTag = @('default')
        }

        # Act
        Set-PodeAsyncRouteOASchemaName @params

        # Assert
        $definition = $PodeContext.Server.OpenApi.Definitions['default'].hiddenComponents.AsyncRoute
        $definition.OATypeName | Should -Be 'DefaultAsyncRouteTask'
        $definition.TaskIdName | Should -Be 'defaultId'
        $definition.QueryRequestName | Should -Be 'DefaultAsyncRouteTaskQuery'
        $definition.QueryParameterName | Should -Be 'DefaultAsyncRouteTaskQueryParameter'
    }
}


Describe 'Add-PodeAsyncRouteSse' {

    BeforeAll {
        # Mock the required Pode functions and variables
        Mock -CommandName 'Add-PodeRoute' -MockWith {
            return @{ Path = "$($args[2])_events"; Method = 'Get' }
        }
        #   Mock -CommandName 'ConvertTo-PodeSseConnection'
        Mock -CommandName 'Send-PodeSseEvent'
        Mock -CommandName 'Write-PodeErrorLog'

        # Mock Pode Context
        $PodeContext = @{
            AsyncRoutes = @{
                Items   = @{
                    'ExamplePool' = @{
                        Sse = $null
                    }
                }
                Results = @{
                    '12345' = @{
                        Runspace = [pscustomobject]@{ Handler = [pscustomobject]@{ IsCompleted = $false } }
                        State    = 'Completed'
                        Result   = 'Success'
                    }
                }
            }
        }
        # Mock data setup
        $PodeContext = @{
            AsyncRoutes = @{
                Enabled      = $true
                Items        = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                Results      = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                HouseKeeping = @{
                    TimerInterval    = 30
                    RetentionMinutes = 10
                }
            }
        }
        # Add a sample asynchronous route operation to the mock PodeContext
        $operationId1 = '123e4567-e89b-12d3-a456-426614174000'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId1
        $asyncOperationDetails['State'] = 'Completed'
        $asyncOperationDetails['Cancellable'] = $true
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['AsyncRouteId'] = 'PesterTest1'
        $asyncOperationDetails['Result'] = 'Success'
        $asyncOperationDetails['Runspace'] = [pscustomobject]@{ Handler = [pscustomobject]@{ IsCompleted = $false } }
        $PodeContext.AsyncRoutes.Results[$operationId1] = $asyncOperationDetails

        $PodeContext.AsyncRoutes.Items['ExamplePool'] = @{
            Sse = $null
        }

    }

    It 'Should throw an exception if the route is not marked as async' {
        {
            $route = @{
                Path         = '/not-async'
                AsyncRouteId = 'not-async'
                IsAsync      = $true
            } | Add-PodeAsyncRouteSse
        } | Should -Throw -ExpectedMessage ($PodeLocale.routeNotMarkedAsAsyncExceptionMessage -f '/not-async')
    }

    It 'Should add SSE route for a valid async route' {
        $route = @{ Path = '/events'; AsyncRouteId = 'ExamplePool'; IsAsync = $true }

        $result = Add-PodeAsyncRouteSse -Route $route -PassThru

        $result | Should -BeOfType 'hashtable'
        $result.Path | Should -Be '/events'
        $PodeContext.AsyncRoutes.Items['ExamplePool'].Sse.Name | Should -Be '/events_events'
    }

    It 'Should handle multiple routes piped in' {
        $routes = @(
            @{ Path = '/events1'; AsyncRouteId = 'ExamplePool'; IsAsync = $true },
            @{ Path = '/events2'; AsyncRouteId = 'ExamplePool'; IsAsync = $true }
        )

        $result = $routes | Add-PodeAsyncRouteSse -PassThru

        $result | Should -HaveCount 2
        $PodeContext.AsyncRoutes.Items['ExamplePool'].Sse.Name | Should -Be '/events2_events'
    }

    It 'Should return the modified route object when PassThru is specified' {
        $route = @{ Path = '/events'; AsyncRouteId = 'ExamplePool'; IsAsync = $true }

        $result = Add-PodeAsyncRouteSse -Route $route -PassThru

        $result | Should -BeOfType 'hashtable'
        $result.Path | Should -Be '/events'
    }


}

Describe 'Set-PodeAsyncRoute' {

    BeforeEach {
        # Mock the required Pode functions and variables
        Mock -CommandName 'Start-PodeAsyncRoutesHousekeeper'
        Mock -CommandName 'New-PodeGuid' -MockWith { return [guid]::NewGuid().ToString() }
        Mock -CommandName 'Test-PodeAsyncRouteScriptblockInvalidCommand'
        Mock -CommandName 'Get-PodeAsyncRouteScriptblock' -MockWith { return $args[0] }
        Mock -CommandName 'Get-PodeAsyncRouteSetScriptBlock' -MockWith { return $args[0] }
        Mock -CommandName 'New-PodeRunspacePoolNetWrapper' -MockWith { return @{} }

        # Mock Pode Context
        $PodeContext = @{
            Threads       = @{
                AsyncRoutes = 0
            }
            RunspacePools = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
            RunspaceState = [initialsessionstate]::CreateDefault()

            AsyncRoutes   = @{
                Enabled      = $true
                Items        = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                Results      = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                HouseKeeping = @{
                    TimerInterval    = 30
                    RetentionMinutes = 10
                }
            }
        }


    }


    It 'Should correctly mark a route as async and set runspaces' {
        $route = @{ Path = '/async'; AsyncRouteId = 'AsyncPool'; IsAsync = $false; Logic = {} }
        Mock -CommandName 'New-PodeRunspacePoolNetWrapper' -MockWith { return @{} }
        $result = Set-PodeAsyncRoute -Route $route -MaxRunspaces 3 -MinRunspaces 2 -PassThru

        $result | Should -BeOfType 'hashtable'
        $result.IsAsync | Should -Be $true

        $PodeContext.AsyncRoutes.Items['AsyncPool'].MinRunspaces | Should -Be 2
        $PodeContext.AsyncRoutes.Items['AsyncPool'].MaxRunspaces | Should -Be 3
        $PodeContext.Threads.AsyncRoutes | Should -Be 3
    }

    It 'Should throw an exception if attempting to invoke for a route already marked as async' {
        $route = @{ Path = '/async'; AsyncRouteId = 'AsyncPool'; IsAsync = $true; Logic = {} }

        {
            Set-PodeAsyncRoute -Route $route
        } | Should -Throw -ExpectedMessage ($PodeLocale.functionCannotBeInvokedMultipleTimesExceptionMessage -f 'Set-PodeAsyncRoute', '/async')
    }

    It 'Should handle a custom IdGenerator script block' {
        $route = @{ Path = '/async'; AsyncRouteId = 'AsyncPool'; IsAsync = $false; Logic = {} }

        $idGenScript = { return 'CustomId' }
        Set-PodeAsyncRoute -Route $route -IdGenerator $idGenScript

        $route.AsyncRouteTaskIdGenerator.Invoke() | Should -Be 'CustomId'
    }

    It 'Should use default IdGenerator if none is provided' {
        $route = @{ Path = '/async'; AsyncRouteId = 'AsyncPool'; IsAsync = $false; Logic = {} }

        Set-PodeAsyncRoute -Route $route

        $id = $route.AsyncRouteTaskIdGenerator.Invoke()

        $id -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' | Should -Be $true  # Checks if the generated Id is a valid GUID
    }

    It 'Should respect the Timeout parameter' {
        $route = @{ Path = '/async'; AsyncRouteId = 'AsyncPool'; IsAsync = $false; Logic = {} }

        Set-PodeAsyncRoute -Route $route -Timeout 600

        $PodeContext.AsyncRoutes.Items['AsyncPool'].Timeout | Should -Be 600
    }

}


Describe 'Stop-PodeAsyncRouteOperation' {
    # Mocking the dependencies
    BeforeAll {
        # Mock Pode Context
        $PodeContext = @{
            Threads       = @{
                AsyncRoutes = 0
            }
            RunspacePools = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
            RunspaceState = [initialsessionstate]::CreateDefault()

            AsyncRoutes   = @{
                Enabled      = $true
                Items        = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                Results      = [System.Collections.Concurrent.ConcurrentDictionary[string, PSObject]]::new()
                HouseKeeping = @{
                    TimerInterval    = 30
                    RetentionMinutes = 10
                }
            }
        }

        # Mocking the Complete-PodeAsyncRouteOperation function
        Mock -CommandName 'Complete-PodeAsyncRouteOperation'

        # Mocking the Export-PodeAsyncRouteInfo function
        Mock -CommandName 'Export-PodeAsyncRouteInfo'  -MockWith {
            param($Async, [switch]$Raw)
            # Return the async operation details, formatted or raw
            if ($Raw) { return $Async } else { return @{'Formatted' = $true } }
        }
    }

    Context 'When operation Id exists' {
        BeforeAll {
            class TestRunspacePipeline {
                [bool]$IsDisposed = $false
                [void]Dispose() {
                    $this.IsDisposed = $true
                    # Mock the Runspace.Dispose method
                }
            }
        }
        BeforeEach {
            # Add a mock operation to PodeContext
            $mockOperation = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
            $mockOperation['Id'] = '123e4567-e89b-12d3-a456-426614174000'
            $mockOperation['State'] = 'Running'
            $mockOperation['Error'] = $null
            $mockOperation['CompletedTime'] = $null
            $mockOperation['Runspace'] = [pscustomobject]@{ Pipeline = [TestRunspacePipeline]::new() }

            $PodeContext.AsyncRoutes.Results[$mockOperation.Id] = $mockOperation
        }

        It 'Should abort the operation and finalize it' {
            $operationId = '123e4567-e89b-12d3-a456-426614174000'

            # Call the function
            $result = Stop-PodeAsyncRouteOperation -Id $operationId

            # Assertions
            $operation = $PodeContext.AsyncRoutes.Results[$operationId]
            $operation.State | Should -Be 'Aborted'
            $operation.Error | Should -Be 'Aborted by System'
            $operation.CompletedTime | Should -Not -Be $null

            # Ensure Complete-PodeAsyncRouteOperation was called
            $operation.Runspace.Pipeline.IsDisposed | Should -BeTrue
        }

        It 'Should return raw operation details when -Raw is specified' {
            $operationId = '123e4567-e89b-12d3-a456-426614174000'

            # Call the function with -Raw
            $result = Stop-PodeAsyncRouteOperation -Id $operationId -Raw

            # Assertions
            $result | Should -Be $PodeContext.AsyncRoutes.Results[$operationId]
        }
    }

    Context 'When operation Id does not exist' {
        It 'Should throw an exception' {
            $operationId = 'nonexistent-id'

            # Assert that the function throws an exception
            { Stop-PodeAsyncRouteOperation -Id $operationId } | Should -Throw
        }
    }
}


Describe 'Add-PodeAsyncRouteGet' {
    # Mocking the dependencies
     BeforeAll {
        # Mock the Get-PodeAsyncRouteOAName function
         Mock -CommandName Get-PodeAsyncRouteOAName -MockWith {
            return @{
                TaskIdName = 'taskId'
                OATypeName = 'AsyncTaskType'
            }
        }

        # Mock the Add-PodeRoute function
        Mock -CommandName Add-PodeRoute -MockWith {
            return @{
             Path = $Path; AsyncRouteId = "__Get$($Path)__".Replace('/', '_'); IsAsync = $false; Logic = {} ;OpenApi=@{}}
        }

        # Mock the Set-PodeOARequest, Add-PodeOAResponse, New-PodeOAStringProperty, and New-PodeOAObjectProperty functions
       Mock -CommandName Set-PodeOARequest -MockWith { return $args[0] }
       #  Mock -CommandName Add-PodeOAResponse -MockWith { return $args[0] }
           Mock -CommandName New-PodeOAStringProperty -MockWith { return @{} }
        Mock -CommandName New-PodeOAObjectProperty -MockWith { return @{} }#>
    }

    Context 'When Path and OADefinitionTag are specified' {
        It 'Should create the route and return it when PassThru is specified' {
            $route = Add-PodeAsyncRouteGet -Path '/status' -PassThru

            # Ensure Add-PodeRoute was called with the expected parameters
            Assert-MockCalled -CommandName Add-PodeRoute -Exactly 1 -Scope It

            # Verify the returned route
            $route.Path | Should -Be '/status'
            $route.OpenApi.ContainsKey('Postponed') | Should -Be $true
            $route.OpenApi.ContainsKey('PostponedArgumentList') | Should -Be $true
        }

        It 'Should correctly modify the Path when In is Path' {
            $route = Add-PodeAsyncRouteGet -Path '/status' -In 'Path' -PassThru

            # Ensure the Path was modified to include taskId
            $route.Path | Should -Be '/status/:taskId'
        }

        It 'Should append the taskId to the Path when In is Path' {
            $route = Add-PodeAsyncRouteGet -Path '/status' -In 'Path' -PassThru

            # Verify that the taskId is appended to the path
            $route.Path | Should -Be '/status/:taskId'
        }
    }

}