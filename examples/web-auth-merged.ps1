$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# Success
# Invoke-RestMethod -Method Get -Uri 'http://localhost:8085/users' -Headers @{ 'X-API-KEY' = 'test-api-key'; Authorization = 'Basic bW9ydHk6cGlja2xl' }

# Failure
# Invoke-RestMethod -Method Get -Uri 'http://localhost:8085/users' -Headers @{ 'X-API-KEY' = 'test-api-key'; Authorization = 'Basic bW9ydHk6cmljaw==' }

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # request logging
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging

    # setup access
    Add-PodeAuthAccess -Type Role -Name 'Rbac'
    Add-PodeAuthAccess -Type Group -Name 'Gbac'

    # setup a merged access
    Merge-PodeAuthAccess -Name 'MergedAccess' -Access 'Rbac', 'Gbac' -Valid All

    # setup apikey auth
    New-PodeAuthScheme -ApiKey -Location Header | Add-PodeAuth -Name 'ApiKey' -Access 'Gbac' -Sessionless -ScriptBlock {
        param($key)

        # here you'd check a real user storage, this is just for example
        if ($key -ieq 'test-api-key') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                    Groups = @('Software')
                }
            }
        }

        return $null
    }

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Basic' -Access 'MergedAccess' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    Username = 'morty'
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                    Roles = @('Developer')
                    Groups = @('Software')
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # merge the auths together
    Merge-PodeAuth -Name 'MergedAuth' -Authentication 'ApiKey', 'Basic' -Valid All

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'MergedAuth' -Role Developer -Group Software -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = $WebEvent.Auth.User
        }
    }

}