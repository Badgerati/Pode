<#
.SYNOPSIS
    PowerShell script to set up a Pode server with Digest authentication.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port and uses Digest authentication
    for securing access to the server. The authentication details are checked against predefined user data.

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

    # Send the GET request and capture the response
    $response = $httpClient.GetStringAsync($uri).Result

    # Display the response
    $response


.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-AuthDigest.ps1

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

    # setup digest auth
    New-PodeAuthScheme -Digest | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $params)
write-podehost "username=$username"
        # here you'd check a real user storage, this is just for example
        if ($username -ieq 'morty') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
                Password = 'pickle'
            }
        }
write-podehost 'no auth'
        return $null
    }

    # GET request to get list of users (since there's no session, authentication will always happen)
    Add-PodeRoute -Method Get -Path '/users' -Authentication 'Validate'   -ScriptBlock {
        write-podehsot '1'
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