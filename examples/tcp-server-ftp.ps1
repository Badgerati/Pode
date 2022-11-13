$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 9000
Start-PodeServer {

    # add two endpoints
    Add-PodeEndpoint -Address * -Port 9000 -Protocol Tcp -CRLFMessageEnd -Acknowledge '220 Ready!'

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeVerb -Verb * -ScriptBlock {
        $TcpEvent.Request.Body | Out-Default
        Write-PodeTcpClient -Message '502 Command not Implemented'
    }
}