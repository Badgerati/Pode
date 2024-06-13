try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # add two endpoints
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Tcp

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # catch-all for http
    Add-PodeVerb -Verb '*' -Close -ScriptBlock {
        $TcpEvent.Request.Body | Out-Default
        Write-PodeTcpClient -Message "HTTP/1.1 200 `r`nConnection: close`r`n`r`n<b>Hello, there</b>"
        # navigate to "http://localhost:8081"
    }

}