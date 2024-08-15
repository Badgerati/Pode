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
                AsyncPoolName = 'testRoute'
            }

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
                @{ AsyncPoolName = 'route1' },
                @{ AsyncPoolName = 'route2' }
            )

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
                AsyncPoolName = 'testRoute'
            }

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


# Assuming the function Export-PodeAsyncInfo is already defined in your session or module

Describe 'Export-PodeAsyncInfo Tests' {

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
            $asyncData['Name'] = 'TestAsync'
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

            $result = Export-PodeAsyncInfo -Async $asyncData

            $result | Should -BeOfType 'hashtable'
            $result.Id | Should -Be 'async-001'
            $result.Cancellable | Should -Be $true
            $result.CreationTime | Should -Be (Format-PodeDateToIso8601 -Date $testDate)
            $result.ExpireTime | Should -Be (Format-PodeDateToIso8601 -Date ($testDate.AddMinutes(10)))
            $result.Name | Should -Be 'TestAsync'
            $result.State | Should -Be 'Completed'
            $result.Permission | Should -Be 'Admin'
            $result.StartingTime | Should -Be (Format-PodeDateToIso8601 -Date ($testDate.AddSeconds(30)))
            $result.CallbackSettings.Url | Should -Be 'http://example.com/callback'
            $result.User | Should -Be 'testuser'
            $result.SseEnabled | Should -Be $true
            $result.Progress | Should -Be 50
            $result.Result | Should -Be 'Success'
            $result.CompletedTime | Should -Be (Format-PodeDateToIso8601 -Date ($testDate.AddMinutes(5)))
        }
    }

    Context 'When Raw switch is used' {
        It 'should return the raw ConcurrentDictionary' {
            $asyncData = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
            $asyncData['Id'] = 'async-002'

            $result = Export-PodeAsyncInfo -Async $asyncData -Raw

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

            $result = Export-PodeAsyncInfo -Async $asyncData

            $result | Should -BeOfType 'hashtable'
            $result.Id | Should -Be 'async-003'
            $result.CreationTime | Should -Be  (Format-PodeDateToIso8601 -Date $testDate)
            $result.State | Should -Be 'Running'
            $result.ContainsKey('Permission') | Should -Be $false
            $result.ContainsKey('CallbackSettings') | Should -Be $false
        }
    }
}

# Assuming the function Get-PodeAsyncRouteOperation is already defined in your session or module

Describe 'Get-PodeAsyncRouteOperation Tests' {

    BeforeAll {
        # Setup the mock for the PodeContext
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
        $operationId = '123e4567-e89b-12d3-a456-426614174000'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId
        $asyncOperationDetails['State'] = 'Running'
        $asyncOperationDetails['Cancellable'] = $true
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['Name'] = 'PesterTest'
        $PodeContext.AsyncRoutes.Results[$operationId] = $asyncOperationDetails

    }

    Context 'When the asynchronous route operation exists' {
        It 'should return the detailed information as a hashtable' {
            $result = Get-PodeAsyncRouteOperation -Id $operationId

            $result | Should -BeOfType 'hashtable'
            $result.Id | Should -Be $operationId
            $result.State | Should -Be 'Running'
        }

        It 'should return the raw dictionary if the Raw switch is used' {
            $result = Get-PodeAsyncRouteOperation -Id $operationId -Raw

            $result | Should -BeOfType 'System.Collections.Concurrent.ConcurrentDictionary[string, psobject]'
            $result['Id'] | Should -Be $operationId
            $result['State'] | Should -Be 'Running'
        }
    }

    Context 'When the asynchronous route operation does not exist' {
        It 'should throw an exception' {
            $nonExistentId = '000e4567-e89b-12d3-a456-426614174000'

            { Get-PodeAsyncRouteOperation -Id $nonExistentId } | Should -Throw -ExpectedMessage ($PodeLocale.asyncRouteOperationDoesNotExistExceptionMessage -f $nonExistentId)
        }
    }
}

# Test script for Get-PodeAsyncRoute function using Pester
# Save this as Get-PodeAsyncRoute.Tests.ps1

Describe 'Get-PodeAsyncRoute' {


    BeforeAll {
        # Set up mock data for testing
        $MockResults = @()
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
        $asyncOperationDetails['Name'] = 'PesterTest1'
        $PodeContext.AsyncRoutes.Results[$operationId1] = $asyncOperationDetails


        $operationId2 = '123e4567-e89b-12d3-a456-426614174001'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId2
        $asyncOperationDetails['State'] = 'NotStarted'
        $asyncOperationDetails['Cancellable'] = $false
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['Name'] = 'PesterTest2'
        $PodeContext.AsyncRoutes.Results[$operationId2] = $asyncOperationDetails

        $operationId3 = '123e4567-e89b-12d3-a456-426614174002'
        $asyncOperationDetails = [System.Collections.Concurrent.ConcurrentDictionary[string, psobject]]::new()
        $asyncOperationDetails['Id'] = $operationId3
        $asyncOperationDetails['State'] = 'Running'
        $asyncOperationDetails['Cancellable'] = $true
        $asyncOperationDetails['CreationTime'] = Get-Date
        $asyncOperationDetails['ExpireTime'] = ($asyncOperationDetails['CreationTime']).AddMinutes(10)
        $asyncOperationDetails['Name'] = 'PesterTest3'
        $PodeContext.AsyncRoutes.Results[$operationId3] = $asyncOperationDetails

    }

    It 'should return all routes when Id and Name are null' {

        # Act
        $Result = Get-PodeAsyncRoute

        # Assert
        $Result.Count | Should -Be 3
        $Result[$operationId1].Name | Should -Be 'PesterTest1'
        $Result[$operationId2].State | Should -Be 'NotStarted'
        $Result[$operationId3].Id | Should -Be $operationId3
    }

    It 'should return the route with Id "123e4567-e89b-12d3-a456-426614174002"' {
        # Arrange

        # Act
        $Result = Get-PodeAsyncRoute -Id $operationId3

        # Assert
        $Result.Count | Should -Be 1
        $Result[$operationId3].Id | Should -Be $operationId3
        $Result[$operationId3].State | Should -Be 'Running'
        $Result[$operationId3].Cancellable | Should -BeTrue
        $Result[$operationId3].Name | Should -Be 'PesterTest3'
    }

    It 'should return routes with Name Route1' {

        # Act
        $Result = Get-PodeAsyncRoute -Name 'PesterTest2'

        # Assert
        $Result | Should -HaveCount 1
        $Result[$operationId2].Id | Should -Be $operationId2
        $Result[$operationId2].State | Should -Be 'NotStarted'
        $Result[$operationId2].Cancellable | Should -BeFalse
        $Result[$operationId2].Name | Should -Be 'PesterTest2'
    }

    It 'should return empty when Id does not match' {
        # Arrange
        $MockResults = @()

        # Act
        $Result = Get-PodeAsyncRoute -Id '999'

        # Assert
        $Result | Should -BeNullOrEmpty
    }

    It 'should pass the Raw switch to Export-PodeAsyncInfo' {

        # Act
        $Result = Get-PodeAsyncRoute -Raw

        # Assert
        $Result.Count |should -Be 3
        $Result.GetType().tostring() |should -Be  'System.Collections.Concurrent.ConcurrentDictionary`2[System.String,System.Management.Automation.PSObject]'
    }
}
