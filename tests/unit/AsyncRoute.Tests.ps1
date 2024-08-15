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