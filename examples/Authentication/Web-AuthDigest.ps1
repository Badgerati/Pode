<#
.SYNOPSIS
    PowerShell script to set up a Pode server with Digest authentication.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and uses Digest authentication
    for securing access to the server. The authentication details are checked against predefined user data.
    For not MD5 algorithm use ./utility/DigestClient.ps1

.EXAMPLE
    To run the sample: ./Web-AuthDigest.ps1

    # Define the URI and credentials
    $uri = [System.Uri]::new("http://localhost:8081/users")
    $username = "morty"
    $password = "pickle"

    # Create a credential cache and add Digest authentication
    $credentialCache = [System.Net.CredentialCache]::new()
    $networkCredential = [System.Net.NetworkCredential]::new($username, $password)
    $credentialCache.Add($uri, "Digest", $networkCredential)

    # Create the HTTP client handler with the credential cache
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.Credentials = $credentialCache

    # Create the HTTP client
    $httpClient = [System.Net.Http.HttpClient]::new($handler)

    # Create the HTTP GET request message
    $requestMessage = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $uri)

    # Send the request and get the response
    $response = $httpClient.SendAsync($requestMessage).Result

    # Extract and display the response headers
    $response.Headers | ForEach-Object { "$($_.Key): $($_.Value)" }

    # Optionally, get content as string if needed
    $content = $response.Content.ReadAsStringAsync().Result
    $content

.EXAMPLE
    No authentication

    # Define the URI
    $uri = [System.Uri]::new("http://localhost:8081/users")

    # Create the HTTP client handler (no authentication)
    $handler = [System.Net.Http.HttpClientHandler]::new()

    # Create the HTTP client
    $httpClient = [System.Net.Http.HttpClient]::new($handler)

    # Create the HTTP GET request message
    $requestMessage = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $uri)

    # Send the request and get the response
    $response = $httpClient.SendAsync($requestMessage).Result

    # Extract and display the response headers
    $response.Headers | ForEach-Object { "$($_.Key): $($_.Value)" }

    # Optionally, get content as string if needed
    $content = $response.Content.ReadAsStringAsync().Result
    $content

.EXAMPLE
    Wrong password

    # Define the URI and wrong credentials
    $uri = [System.Uri]::new("http://localhost:8081/users")
    $wrongUsername = "wrongUser"
    $wrongPassword = "wrongPassword"

    # Create a credential cache and add Digest authentication with incorrect credentials
    $credentialCache = [System.Net.CredentialCache]::new()
    $networkCredential = [System.Net.NetworkCredential]::new($wrongUsername, $wrongPassword)
    $credentialCache.Add($uri, "Digest", $networkCredential)

    # Create the HTTP client handler with the credential cache
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.Credentials = $credentialCache

    # Create the HTTP client
    $httpClient = [System.Net.Http.HttpClient]::new($handler)

    # Create the HTTP GET request message
    $requestMessage = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $uri)

    # Send the request and get the response
    $response = $httpClient.SendAsync($requestMessage).Result

    # Display the response status code (to check for 401 Unauthorized)
    $response.StatusCode

    # Extract and display the response headers
    $response.Headers | ForEach-Object { "$($_.Key): $($_.Value)" }

    # Optionally, get content as string if needed
    $content = $response.Content.ReadAsStringAsync().Result
    $content


.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Authentication/Web-AuthDigest.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

param(
    [Parameter()]
    [string[]]
    $Algorithm = @('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256'),

    [Parameter()]
    [ValidateSet('auth', 'auth-int', 'auth,auth-int'  )]
    [string[]]
    $QualityOfProtection = 'auth,auth-int'
)
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path))
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

    # setup digest auth
    New-PodeAuthDigestScheme -Algorithm $Algorithm -QualityOfProtection $QualityOfProtection | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $params)

        # here you'd check a real user storage, this is just for example
        if ($username -ieq 'morty') {
            return @{
                User     = @{
                    ID   = 'M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
                Password = 'pickle'
            }
        }

        return $null
    }

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'Validate' -ErrorContentType  'application/json' -ScriptBlock {
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

    Add-PodeRoute -Method Post -Path '/users' -Authentication 'Validate' -ErrorContentType  'application/json' -ScriptBlock {
        if ($WebEvent.data) {
            Write-PodeJsonResponse -Value  $WebEvent.data -StatusCode 200
        }
        else {
            Write-PodeJsonResponse -Value @{success = $false } -StatusCode 400
        }
    }

}