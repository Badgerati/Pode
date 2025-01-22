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
    Add-PodeEndpoint -Address 'localhost' -Protocol 'Http' -Port '80'

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
            return @{ Success = $false; Reason = 'No X-API-KEY Header found' }
        }

        # Validate API key
        if ($key -eq 'test_user') {
            return @{ Success = $true; User = 'test_user'; UserId = 1 }
        }

        # Return failure for invalid users
        return @{ Success = $false; User = $key; UserId = -1; Reason = 'Not existing user' }
    }

    # Define an API route with manual authentication error handling
    Add-PodeRoute -PassThru -Method 'Get' -Path '/api/v3/' -Authentication 'APIKey' -NoMiddlewareAuthentication -ScriptBlock {
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
}
