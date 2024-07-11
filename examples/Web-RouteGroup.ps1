<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with middleware and basic authentication.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081. It demonstrates how to use middleware,
    route groups, and basic authentication. The server includes routes under the '/api' and '/auth' paths,
    with specific middleware and authentication requirements.

.EXAMPLE
    # Example of invoking a request to an authenticated route:
    Invoke-RestMethod -Uri http://localhost:8081/auth/route1 -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }

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


$message = 'Kenobi'

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    $mid1 = New-PodeMiddleware -ScriptBlock {
        'here1' | Out-Default
    }

    $mid2 = New-PodeMiddleware -ScriptBlock {
        'here2' | Out-Default
    }

    Add-PodeRouteGroup -Path '/api' -Middleware $mid1 -Routes {
        Add-PodeRoute -Method Get -Path '/route1' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ ID = 1 }
        }

        Add-PodeRouteGroup -Path '/inner' -Routes {
            Add-PodeRoute -Method Get -Path '/route2' -Middleware $using:mid2 -ScriptBlock {
                Write-PodeJsonResponse -Value @{ ID = 2 }
            }

            Add-PodeRoute -Method Get -Path '/route3' -ScriptBlock {
                "Hello there, $($using:message)" | Out-Default
                Write-PodeJsonResponse -Value @{ ID = 3 }
            }
        }
    }


    # Invoke-RestMethod -Uri http://localhost:8081/auth/route1 -Method Post -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Basic' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{ ID = 'M0R7Y302' }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    Add-PodeRouteGroup -Path '/auth' -Authentication Basic -Routes {
        Add-PodeRoute -Method Post -Path '/route1' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ ID = 1 }
        }

        Add-PodeRoute -Method Post -Path '/route2' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ ID = 2 }
        }

        Add-PodeRoute -Method Post -Path '/route3' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ ID = 3 }
        }
    }

}