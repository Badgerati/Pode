<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with various routes, tasks, and security.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081. It demonstrates how to handle GET and PUT requests,
    set up security, define tasks, and use Pode's view engine.

.NOTES
    Author: Pode Team
    License: MIT License

.EXAMPLE
    To build and start the Docker container, use:
    docker-compose up --force-recreate --build
#>
try {
    Import-Module /usr/local/share/powershell/Modules/Pode/Pode.psm1 -Force -ErrorAction Stop
}
catch { throw }


# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on *:8081
    Add-PodeEndpoint -Address * -Port 8081 -Protocol Http
    Set-PodeSecurity -Type Simple

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    Add-PodeTask -Name 'Test' -ScriptBlock {
        'a string'
        4
        return @{ InnerValue = 'hey look, a value!' }
    }

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        Set-PodeResponseStatus -Code 500
    }

    # PUT update a file to trigger monitor
    Add-PodeRoute -Method Put -Path '/file' -ScriptBlock {
        'Hello, world!' | Out-File -FilePath "$($PodeContext.Server.Root)/file.txt" -Append -Force
    }

    Add-PodeRoute -Method Get -Path '/user/:userId' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ UserId = $WebEvent.Parameters['userId'] }
    }

    Add-PodeRoute -Method Get -Path '/run-task' -ScriptBlock {
        $result = Invoke-PodeTask -Name 'Test' -Wait
        Write-PodeJsonResponse -Value @{ Result = $result }
    }

}
