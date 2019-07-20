$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8086
Start-PodeServer {

    Add-PodeEndpoint -Address *:8086 -Protocol Http

    # can be hit by sending a GET request to "localhost:8086/api/test"
    Add-PodeRoute -Method Get -Path '/api/test' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'hello' = 'world'; }
    }

    # can be hit by sending a POST request to "localhost:8086/api/test"
    Add-PodeRoute -Method Post -Path '/api/test' -ContentType 'application/json' -ScriptBlock {
        param($e)
        Write-PodeJsonResponse -Value @{ 'hello' = 'world'; 'name' = $e.Data['name']; }
    }

    # returns details for an example user
    Add-PodeRoute -Method Get -Path '/api/users/:userId' -ScriptBlock {
        param($e)
        $user = Get-DummyUser -UserId $e.Parameters['userId']
        Write-PodeJsonResponse -Value @{ 'user' = $user; }
    }

}