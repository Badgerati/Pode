<#
.SYNOPSIS
  Demonstrates session management using Pode with basic authentication.

.DESCRIPTION
  This script sets up a Pode web server with a basic authentication endpoint. It tracks user sessions and
  increments a session counter each time the endpoint is accessed.

.EXAMPLE
    To run the sample: ./SessionData.ps1
    $result=Invoke-WebRequest -Uri "http://localhost:8081/auth/basic" -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
    $session = ($result.Headers['pode.sid'] | Select-Object -First 1)

    $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ 'pode.sid' = $session }
    $content = ($result.Content | ConvertFrom-Json)
    $content.Result #should be 2

    $result = Invoke-WebRequest -Uri "$($Endpoint)/auth/basic" -Method Post -Headers @{ 'pode.sid' = $session }
    $content = ($result.Content | ConvertFrom-Json)
    $content.Result #should be 3 and so on...

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/SessionData.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

try {
    # Determine the script directory path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Check if Pode is available from source; otherwise, load it from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }  # Stop execution if Pode module fails to load

# Start the Pode web server
Start-PodeServer -ScriptBlock {

    # Define an HTTP endpoint on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # Add a route to gracefully stop the server
    Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
        Close-PodeServer
    }

    # Enable session middleware with secret-based authentication and session persistence
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 5 -Extend -UseHeaders

    # Define a basic authentication scheme
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Auth' -ScriptBlock {
        param($username, $password)

        # Authenticate user based on predefined credentials
        if (($username -eq 'morty') -and ($password -eq 'pickle')) {
            return @{ User = @{ ID = 'M0R7Y302' } }  # Return user ID if authentication is successful
        }

        return @{ Message = 'Invalid details supplied' }  # Return error message for failed authentication
    }

    # Define a route that requires authentication and maintains session state
    Add-PodeRoute -Method Post -Path '/auth/basic' -Authentication Auth -ScriptBlock {

        # Increment session view count for the authenticated user
        $WebEvent.Session.Data.Views++

        # Return JSON response with session details
        Write-PodeJsonResponse -Value @{
            Result   = 'OK'
            Username = $WebEvent.Auth.User.ID
            Views    = $WebEvent.Session.Data.Views
        }
    }
}
