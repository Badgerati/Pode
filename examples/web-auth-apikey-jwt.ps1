param(
    [Parameter()]
    [ValidateSet('Header', 'Query', 'Cookie')]
    [string]
    $Location = 'Header'
)

try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
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

# -------------
# None Signed
# Req: Invoke-RestMethod -Uri 'http://localhost:8081/users' -Headers @{ 'X-API-KEY' = 'eyJhbGciOiJub25lIn0.eyJ1c2VybmFtZSI6Im1vcnR5Iiwic3ViIjoiMTIzIn0.' }
# -------------

# -------------
# Signed
# Req: Invoke-RestMethod -Uri 'http://localhost:8081/users' -Headers @{ 'X-API-KEY' = 'eyJhbGciOiJoczI1NiJ9.eyJ1c2VybmFtZSI6Im1vcnR5Iiwic3ViIjoiMTIzIn0.WIOvdwk4mNrNC9EtTcQccmLHJc02gAuonXClHMFOjKM' }
#
# (add -Secret 'secret' to New-PodeAuthScheme below)
# -------------

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
                    ID ='M0R7Y302'
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
                    Age = 42
                },
                @{
                    Name = 'Leeroy Jenkins'
                    Age = 1337
                }
            )
        }
    }

}