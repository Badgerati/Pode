<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with JWT authentication and various route configurations.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port, enables request and error logging,
    and configures JWT authentication. It also defines a route to fetch a list of users, requiring authentication.

.PARAMETER Location
    The location where the API key is expected. Valid values are 'Header', 'Query', and 'Cookie'. Default is 'Header'.

    .NOTES
    -------------
    None Signed
    Req: Invoke-RestMethod -Uri 'http://localhost:8081/users' -Headers @{ 'X-API-KEY' = 'eyJhbGciOiJub25lIn0.eyJ1c2VybmFtZSI6Im1vcnR5Iiwic3ViIjoiMTIzIn0.' }
    -------------

    -------------
    Signed
    Req: Invoke-RestMethod -Uri 'http://localhost:8081/users' -Headers @{ 'X-API-KEY' = 'eyJhbGciOiJoczI1NiJ9.eyJ1c2VybmFtZSI6Im1vcnR5Iiwic3ViIjoiMTIzIn0.WIOvdwk4mNrNC9EtTcQccmLHJc02gAuonXClHMFOjKM' }

    (add -Secret 'secret' to New-PodeAuthScheme below)

    -------------

.EXAMPLE
    To run the sample: ./WebAuth-ApikeyJWT.ps1

    Invoke-RestMethod -Uri http://localhost:8081/users -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/WebAuth-ApikeyJWT.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [Parameter()]
    [ValidateSet('Header', 'Query', 'Cookie')]
    [string]
    $Location = 'Header'
)

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

    New-PodeLoggingMethod -File -Name 'requests' | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # setup bearer auth
    New-PodeAuthScheme -ApiKey -Location $Location -AsJWT | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($jwt)

        # here you'd check a real user storage, this is just for example
        if ($jwt.username -ieq 'morty') {
            return @{
                User = @{
                    ID   = 'M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        return $null
    }

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'Validate' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Users = @(
                @{
                    Name = 'Deep Thought'
                    Age  = 42
                },
                @{
                    Name = 'Leeroy Jenkins'
                    Age  = 1337
                }
            )
        }
    }

    New-PodeAuthScheme -ApiKey -AsJWT -Secret 'secret' | Add-PodeAuth -Name 'ApiKeySignedJwtAuth' -Sessionless -ScriptBlock {
        param($jwt)

        if ($jwt.username -ieq 'morty') {
            return @{
                User = @{ ID = 'M0R7Y302' }
            }
        }

        return $null
    }

    Add-PodeRoute -Method Get -Path '/auth/apikey/jwt/signed' -Authentication 'ApiKeySignedJwtAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 'OK' }

    }
    # API KEY - JWT (not signed)
    New-PodeAuthScheme -ApiKey -AsJWT | Add-PodeAuth -Name 'ApiKeyNotSignedJwtAuth' -Sessionless -ScriptBlock {
        param($jwt)

        if ($jwt.username -ieq 'morty') {
            return @{
                User = @{ ID = 'M0R7Y302' }
            }
        }

        return $null
    }

    Add-PodeRoute -Method Get -Path '/auth/apikey/jwt/notsigned' -Authentication 'ApiKeyNotSignedJwtAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 'OK' }
    }



}