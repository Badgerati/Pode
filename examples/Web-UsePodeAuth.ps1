<#
.SYNOPSIS
    A PowerShell script to set up a Pode server with API key authentication and various route configurations.

.DESCRIPTION
    Sets up a Pode server that listens on a specified port, enables request and error logging, and configures API key
    authentication. The script uses the `Use-PodeAuth` function to load and apply the authentication defined in
    `./auth/SampleAuth.ps1`. The authentication is applied globally to the API routes using `Add-PodeAuthMiddleware`.
    The script defines a route to fetch a list of users, which requires authentication using a specified location
    for the API key (Header, Query, or Cookie).

.PARAMETER Location
    Specifies where the API key is expected. Valid values are 'Header', 'Query', and 'Cookie'. Default is 'Header'.

.EXAMPLE
    To run the sample:

    ```powershell
    ./Web-UsePodeAuth.ps1
    ```
    Then, make a request to get users with an API key:

    ```powershell
    Invoke-RestMethod -Uri 'http://localhost:8081/api/users' -Method Get -Headers @{ 'X-API-KEY' = 'test-api-key' }
    ```

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-UsePodeAuth.ps1

.NOTES
    The `Use-PodeAuth` function is used to load the authentication script located at `./auth/SampleAuth.ps1`. The
    authentication is then enforced using `Add-PodeAuthMiddleware` to protect the `/api/*` routes.

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

    Use-PodeAuth

    Add-PodeAuthMiddleware -Name 'globalAuthValidation' -Authentication 'Validate' -Route '/api/*'

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Get -Path '/api/users' -ScriptBlock {
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

}