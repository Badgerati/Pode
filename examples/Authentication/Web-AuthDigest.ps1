<#
.SYNOPSIS
    PowerShell script to set up a Pode server with Digest authentication or make client requests.

.DESCRIPTION
    This script can either:
    - Start a Pode server that listens on a specified port and uses Digest authentication to secure access.
    - Act as a client to send requests with Digest authentication.

    The authentication details are checked against predefined user data.
    For non-MD5 algorithms, use ./utility/DigestClient.ps1.

.PARAMETER Client
    If specified, the script runs in client mode instead of starting a server.

.PARAMETER Algorithm
    The Digest authentication algorithm(s) to use. Supported values: MD5, SHA-1, SHA-256, SHA-512, SHA-384, SHA-512/256.
    Defaults to all supported algorithms.

.PARAMETER QualityOfProtection
    Specifies the Quality of Protection (qop) to use in Digest authentication.
    Valid options:
    - 'auth': Authentication only.
    - 'auth-int': Authentication with integrity protection.
    - 'auth,auth-int': Support both modes.

.EXAMPLE
    To start the Pode server with default settings:
    ```powershell
    ./Web-AuthDigest.ps1
    ```

.EXAMPLE
    To start the Pode server with SHA-256 authentication only:
    ```powershell
    ./Web-AuthDigest.ps1 -Algorithm SHA-256
    ```

.EXAMPLE
    To run in client mode and send a Digest-authenticated request:
    ```powershell
    ./Web-AuthDigest.ps1 -Client
    ```

.EXAMPLE
    Client request example using default .Net Digest support:

    ```powershell
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

    # Send the GET request
    $requestMessage = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $uri)
    $response = $httpClient.SendAsync($requestMessage).Result

    # Display response headers and content
    $response.Headers | ForEach-Object { "$($_.Key): $($_.Value)" }
    $content = $response.Content.ReadAsStringAsync().Result
    $content
    ```
.EXAMPLE
    Client request example using `Invoke-WebRequestDigest`:

    ```powershell
    Import-Module './client/Invoke-Digest.psm1'

    # Define the URI and credentials
    $uri = 'http://localhost:8081/users'
    $username = 'morty'
    $password = 'pickle'

    # Convert the password to a SecureString and create a credential object
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new($username, $securePassword)

    # Make a GET request using Digest authentication
    $response = Invoke-WebRequestDigest -Uri $uri -Method 'GET' -Credential $credential

    # Display response headers and content
    $response.Headers | Format-List
    Write-Output $response.Content
    ```

.EXAMPLE
    Running the server with `auth-int` quality of protection:
    ```powershell
    ./Web-AuthDigest.ps1 -QualityOfProtection auth-int
    ```

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Authentication/Web-AuthDigest.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

[CmdletBinding(DefaultParameterSetName = 'Server')]
param(
    [Parameter(ParameterSetName = 'Client')]
    [switch]
    $Client,

    [Parameter(ParameterSetName = 'Server')]
    [string[]]
    $Algorithm = @('MD5', 'SHA-1', 'SHA-256', 'SHA-512', 'SHA-384', 'SHA-512/256'),

    [Parameter(ParameterSetName = 'Server')]
    [ValidateSet('auth', 'auth-int', 'auth,auth-int'  )]
    [string[]]
    $QualityOfProtection = 'auth,auth-int'
)
if ($Client) {
    Import-Module './Modules/Invoke-Digest.psm1'
    $uri = 'http://localhost:8081/users'
    $username = 'morty'
    $password = 'pickle'

    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $credential = [System.Management.Automation.PSCredential]::new($username, $securePassword)

    $response = Invoke-WebRequestDigest -Uri $uri -Method 'GET' -Credential $credential
    $response | Format-List *

    Invoke-WebRequestDigest -Uri $uri -Method 'GET' -Credential $credential -OutFile 'outfile.json'

    $response = Invoke-RestMethodDigest -Uri $uri -Method 'GET' -Credential $credential
    $response
    return
}
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
    # If QualityOfProtection is 'auth-int' skip GET because it is not supported
    if ($QualityOfProtection -ne 'auth-int') {
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