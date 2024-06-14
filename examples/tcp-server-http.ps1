$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 9000
Start-PodeServer -Threads 2 {

    # add two endpoints
    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Tcp

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # catch-all for http
    Add-PodeVerb -Verb '*' -Close -ScriptBlock {
        $TcpEvent.Request.Body | Out-Default
        Write-PodeTcpClient -Message "HTTP/1.1 200 `r`nConnection: close`r`n`r`n<b>Hello, there</b>"
        # navigate to "http://localhost:9000"
    }

}