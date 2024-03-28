$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8086
Start-PodeServer {

    Add-PodeEndpoint -Address 'localhost' -Port 8086 -Protocol Http -DualMode

    # request logging
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging

    # can be hit by sending a GET request to "localhost:8086/api/test"
    Add-PodeRoute -Method Get -Path '/api/test' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'hello' = 'world'; }
    }

    # can be hit by sending a POST request to "localhost:8086/api/test"
    Add-PodeRoute -Method Post -Path '/api/test' -ContentType 'application/json' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'hello' = 'world'; 'name' = $WebEvent.Data['name']; }
    }

    # returns details for an example user
    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'user' = $WebEvent.Parameters['userId']; }
    }

    # returns details for an example user
    Add-PodeRoute -Method Get -Path '/api/users/:userId/messages' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'user' = $WebEvent.Parameters['userId']; }
    }

}