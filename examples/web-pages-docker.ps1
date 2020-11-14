Import-Module /usr/local/share/powershell/Modules/Pode/Pode.psm1 -Force -ErrorAction Stop

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on *:8085
    Add-PodeEndpoint -Address * -Port 10000 -Protocol Http

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8085/"
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

}
