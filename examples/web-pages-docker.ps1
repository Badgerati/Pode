Import-Module Pode -Force -ErrorAction Stop

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on *:8085
    Add-PodeEndpoint -Address * -Port 10000 -Protocol Http

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($session)
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        param($session)
        Set-PodeResponseStatus -Code 500
    }

    # PUT update a file to trigger monitor
    Add-PodeRoute -Method Put -Path '/file' -ScriptBlock {
        param($session)
        'Hello, world!' | Out-File -FilePath "$($PodeContext.Server.Root)/file.txt" -Append -Force
    }

}
