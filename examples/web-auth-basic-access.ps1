<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with basic authentication and role/group-based access control.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port, enables request and error logging,
    configures basic authentication, and sets up role and group-based access control. It defines various routes
    with specific access requirements.

.PARAMETER Location
    The location where the API key is expected. Valid values are 'Header', 'Query', and 'Cookie'. Default is 'Header'.

.EXAMPLE
    This example shows how to use sessionless authentication, which will mostly be for
    REST APIs. The example used here is Basic authentication.

    Calling the '[POST] http://localhost:8081/users-all' endpoint, with an Authorization
    header of 'Basic bW9ydHk6cGlja2xl' will display the uesrs. Anything else and
    you'll get a 401 status code back.

    Success:
    Invoke-RestMethod -Uri http://localhost:8081/users-all -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }

    Failure:
    Invoke-RestMethod -Uri http://localhost:8081/users-all -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cmljaw==' }

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # setup RBAC
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'TestRbac'
    New-PodeAccessScheme -Type Group | Add-PodeAccess -Name 'TestGbac'

    Merge-PodeAccess -Name 'TestMergedAll' -Access 'TestRbac', 'TestGbac' -Valid All
    Merge-PodeAccess -Name 'TestMergedOne' -Access 'TestRbac', 'TestGbac' -Valid One

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic -Realm 'Pode Example Page' | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID           = 'M0R7Y302'
                    Name         = 'Morty'
                    Type         = 'Human'
                    Username     = 'm.orty'
                    Roles        = @('Developer')
                    Groups       = @('Software', 'Admins')
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

    # POST request to get list of users - there's no Access, so any auth'd user can access
    Add-PodeRoute -Method Post -Path '/users-all' -Authentication 'Validate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Deep Thought'
                }
            )
        }
    }

    # POST request to get list of users - only Developer roles can access
    Add-PodeRoute -Method Post -Path '/users-dev' -Authentication 'Validate' -Access 'TestRbac' -Role Developer -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Leeroy Jenkins'
                }
            )
        }
    }

    # POST request to get list of users - only QA roles can access
    Add-PodeRoute -Method Post -Path '/users-qa' -Authentication 'Validate' -Access 'TestRbac' -Role QA -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Nikola Tesla'
                }
            )
        }
    }

    # POST request to get list of users - only users in the SOftware group can access
    Add-PodeRoute -Method Post -Path '/users-soft' -Authentication 'Validate' -Access 'TestGbac' -Group Software -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Smooth McGroove'
                }
            )
        }
    }

    # POST request to get list of users - only Developer role in the Admins group can access
    Add-PodeRoute -Method Post -Path '/users-dev-admin' -Authentication 'Validate' -Access 'TestMergedAll' -Role Developer -Group Admins -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Arthur Dent'
                }
            )
        }
    }

    # POST request to get list of users - either DevOps role or Admins group can access
    Add-PodeRoute -Method Post -Path '/users-devop-admin' -Authentication 'Validate' -Access 'TestMergedOne' -Role DevOps -Group Admins -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Monkey D. Luffy'
                }
            )
        }
    }

    # POST request to get list of users - either QA role or Support group can access
    Add-PodeRoute -Method Post -Path '/users-qa-support' -Authentication 'Validate' -Access 'TestMergedOne' -Role QA -Group Support -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Donald Duck'
                }
            )
        }
    }

}