$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
This example shows how to use sessionless authentication, which will mostly be for
REST APIs. The example used here is Basic authentication.

Calling the '[POST] http://localhost:8085/users' endpoint, with an Authorization
header of 'Basic bW9ydHk6cGlja2xl' will display the uesrs. Anything else and
you'll get a 401 status code back.

Success:
Invoke-RestMethod -Uri http://localhost:8085/users -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }

Failure:
Invoke-RestMethod -Uri http://localhost:8085/users -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cmljaw==' }
#>

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http

    # setup RBAC
    Add-PodeAuthAccess -Type Role -Name 'TestRbac'
    # Add-PodeAuthAccess -Type Custom -Name 'TestRbac' -Path 'CustomAccess' -Validator {
    #     param($userRoles, $customValues)
    #     return $userRoles.Example -iin $customValues.Example
    # }

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic -Realm 'Pode Example Page' | Add-PodeAuth -Name 'Validate' -Access 'TestRbac' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                    Username = 'm.orty'
                    Roles = @('Developer', 'Admin')
                    CustomAccess = @{ Example = 'test-val-1' }
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # Endware to output user auth state
    Add-PodeEndware -ScriptBlock {
        $WebEvent.Auth | Out-Default
    }

    # POST request to get list of users - there's no Roles, so any auth'd user can access
    Add-PodeRoute -Method Post -Path '/users-all' -Authentication 'Validate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Deep Thought'
                    Age = 42
                }
            )
        }
    }

    # POST request to get list of users - only Developer roles can access
    Add-PodeRoute -Method Post -Path '/users-dev' -Authentication 'Validate' -Role Developer -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Leeroy Jenkins'
                    Age = 1337
                }
            )
        }
    } -PassThru | Add-PodeAuthCustomAccess -Name 'TestRbac' -Value @{ Example = 'test-val-1' }

    # POST request to get list of users - only Admin roles can access
    Add-PodeRoute -Method Post -Path '/users-admin' -Authentication 'Validate' -Role Admin -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Arthur Dent'
                    Age = 30
                }
            )
        }
    } -PassThru | Add-PodeAuthCustomAccess -Name 'TestRbac' -Value @{ Example = 'test-val-2' }

}