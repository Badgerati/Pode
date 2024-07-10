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

# Success
# Invoke-RestMethod -Method Get -Uri 'http://localhost:8081/users' -Headers @{ 'X-API-KEY' = 'test-api-key'; Authorization = 'Basic bW9ydHk6cGlja2xl' }

# Failure
# Invoke-RestMethod -Method Get -Uri 'http://localhost:8081/users' -Headers @{ 'X-API-KEY' = 'test-api-key'; Authorization = 'Basic bW9ydHk6cmljaw==' }

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # request logging
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging

    # setup access
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'Rbac'
    New-PodeAccessScheme -Type Group | Add-PodeAccess -Name 'Gbac'

    # setup a merged access
    Merge-PodeAccess -Name 'MergedAccess' -Access 'Rbac', 'Gbac' -Valid All

    # setup apikey auth
    New-PodeAuthScheme -ApiKey -Location Header | Add-PodeAuth -Name 'ApiKey' -Sessionless -ScriptBlock {
        param($key)

        # here you'd check a real user storage, this is just for example
        if ($key -ieq 'test-api-key') {
            return @{
                User = @{
                    ID     = 'M0R7Y302'
                    Name   = 'Morty'
                    Type   = 'Human'
                    Roles  = @('Developer')
                    Groups = @('Platform')
                }
            }
        }

        return $null
    }

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Basic' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    Username = 'morty'
                    ID       = 'M0R7Y302'
                    Name     = 'Morty'
                    Type     = 'Human'
                    Roles    = @('Developer')
                    Groups   = @('Software')
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # merge the auths together
    Merge-PodeAuth -Name 'MergedAuth' -Authentication 'ApiKey', 'Basic' -Valid All -ScriptBlock {
        param($results)

        $apiUser = $results['ApiKey'].User
        $basicUser = $results['Basic'].User

        return @{
            User = @{
                Username = $basicUser.Username
                ID       = $apiUser.ID
                Name     = $apiUser.Name
                Type     = $apiUser.Type
                Roles    = @($apiUser.Roles + $basicUser.Roles) | Sort-Object -Unique
                Groups   = @($apiUser.Groups + $basicUser.Groups) | Sort-Object -Unique
            }
        }
    }

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'MergedAuth' -Access 'MergedAccess' -Role Developer -Group Software -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = $WebEvent.Auth.User
        }
    }

}