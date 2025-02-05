<#
.SYNOPSIS
    A Pode server setup with manual authentication error handling.

.DESCRIPTION
    This script initializes a Pode web server on port 80 and configures custom API key authentication.
    Instead of using Pode's default error handling, it manually processes authentication failures, providing
    detailed responses based on the authentication result.

.EXAMPLE
    To run the script:

        ./Web-AuthManualErrorHandling.ps1

    Test it using:

        Invoke-RestMethod -Uri http://localhost/api/v3/ -Headers @{ 'X-API-KEY' = 'test_user' } -Method Get

.EXAMPLE
   Digest
   # Define the URI and credentials
    $uri = [System.Uri]::new("http://localhost:8081/api/v3/whois")
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

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-AuthManualErrorHandling.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

try {
    # Determine the script's directory and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source directory if available, otherwise use the installed module
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# Start the Pode server
Start-PodeServer {
    # Define an HTTP endpoint for the server
    Add-PodeEndpoint -Address 'localhost' -Protocol 'Http' -Port '8081'

    # Enable OpenAPI documentation and viewers
    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3' -DisableMinimalDefinitions -NoDefaultResponses
    Add-PodeOAInfo -Title 'Custom Authentication Error Handling' -Version 1.0.0
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'
    Add-PodeOAServerEndpoint -Url '/api/v3' -Description 'Default API endpoint'

    # Configure custom API key authentication
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'APIKey' -Sessionless -ScriptBlock {
        param($key)
        # Handle missing API key
        if (!$key) {
            return @{ Success = $false; Reason = 'No Authentication Header found' }
        }

        # Validate API key
        if ($key -eq 'test_user') {
            return @{ Success = $true; User = 'test_user'; UserId = 1 }
        }

        # Return failure for invalid users
        return @{ Success = $false; User = $key; Reason = 'Not existing user' }
    }


    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'APIKey_standard' -Sessionless -ScriptBlock {
        param($key)

        # Validate API key
        if ($key -eq 'test_user') {
            return @{ Success = $true; User = 'test_user'; UserId = 1 }
        }

    }

    New-PodeAuthScheme -Digest | Add-PodeAuth -Name 'Digest' -Sessionless -ScriptBlock {
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

    # Define an API route with manual authentication error handling
    Add-PodeRoute -PassThru -Method 'Get' -Path '/api/v3/whoami' -Authentication 'APIKey' -NoMiddlewareAuthentication -ScriptBlock {
        # Manually invoke authentication
        $auth = Invoke-PodeAuth -Name 'APIKey'

        # Log authentication details for debugging
        Write-PodeHost $auth -Explode

        # If authentication succeeds, return user details
        if ($auth.Success) {
            Write-PodeJsonResponse -StatusCode 200 -Value @{
                Success  = $true
                Username = $auth.User
                UserId   = $auth.UserId
            }
        }
        else {
            # Handle authentication failures with a custom error response
            Write-PodeJsonResponse -StatusCode 401 -Value @{
                Success  = $false
                Message  = $auth.Reason
                Username = $auth.User
            }
        }
    } | Set-PodeOARouteInfo -Summary 'Who am I' -Tags 'auth' -OperationId 'whoami' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{  'application/json' = (New-PodeOABoolProperty -Name 'Success' -Default $true | New-PodeOAStringProperty -Name 'Username' | New-PodeOAIntProperty -Name 'UserId' | New-PodeOAObjectProperty ) } -PassThru |
        Add-PodeOAResponse -StatusCode 401 -Description 'Authentication failure' -Content @{  'application/json' = (New-PodeOABoolProperty -Name 'Success' -Default $false | New-PodeOAStringProperty -Name 'Username' | New-PodeOAStringProperty -Name 'Message' | New-PodeOAObjectProperty ) }

    Add-PodeRoute -PassThru -Method 'Get' -Path '/api/v3/whoami_standard' -Authentication 'APIKey_standard' -ErrorContentType 'application/json'  -ScriptBlock {
        # Manually invoke authentication
        $auth = $WebEvent.Auth
        # Log authentication details for debugging
        Write-PodeHost $auth -Explode

        # If authentication succeeds, return user details
        if ($auth.Success) {
            Write-PodeJsonResponse -StatusCode 200 -Value @{
                Success  = $true
                Username = $auth.User
                UserId   = $auth.UserId
            }
        }
        else {
            # Handle authentication failures with a custom error response
            Write-PodeJsonResponse -StatusCode 401 -Value @{
                Success  = $false
                Message  = $auth.Reason
                Username = $auth.User
            }
        }
    } | Set-PodeOARouteInfo -Summary 'Who am I (default auth)' -Tags 'auth' -OperationId 'whoami_standard' -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{  'application/json' = (New-PodeOABoolProperty -Name 'Success' -Default $true | New-PodeOAStringProperty -Name 'Username' | New-PodeOAIntProperty -Name 'UserId' | New-PodeOAObjectProperty ) } -PassThru |
        Add-PodeOAResponse -StatusCode 401 -Description 'Authentication failure' -Content @{  'application/json' = (New-PodeOABoolProperty -Name 'Success' -Default $false | New-PodeOAStringProperty -Name 'Username' | New-PodeOAStringProperty -Name 'Message' | New-PodeOAObjectProperty ) }


    # Define an API route with manual authentication error handling
    Add-PodeRoute   -Method 'Get' -Path '/api/v3/whois' -Authentication 'Digest'   -ScriptBlock {
        # Manually invoke authentication
        $auth = $WebEvent.Auth

        # Log authentication details for debugging
        Write-PodeHost $Webauth -Explode

        # If authentication succeeds, return user details
        if ($auth.Success) {
            Write-PodeJsonResponse -StatusCode 200 -Value @{
                Success  = $true
                Username = $auth.User.Name
                UserId   = $auth.User.Id
            }
        }
        else {
            # Handle authentication failures with a custom error response
            Write-PodeJsonResponse -StatusCode 401 -Value @{
                Success  = $false
                Message  = $auth.Reason
                Username = $auth.User
            }
        }
    }
    #| Set-PodeOARouteInfo -Summary 'Who Is' -Tags 'auth' -OperationId 'whois' -PassThru |
    #   Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content @{  'application/json' = (New-PodeOABoolProperty -Name 'Success' -Default $true | New-PodeOAStringProperty -Name 'Username' | New-PodeOAIntProperty -Name 'UserId' | New-PodeOAObjectProperty ) } -PassThru |
    #  Add-PodeOAResponse -StatusCode 401 -Description 'Authentication failure' -Content @{  'application/json' = (New-PodeOABoolProperty -Name 'Success' -Default $false | New-PodeOAStringProperty -Name 'Username' | New-PodeOAStringProperty -Name 'Message' | New-PodeOAObjectProperty ) }
}