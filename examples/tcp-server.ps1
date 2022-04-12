$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8999
Start-PodeServer -Threads 2 {

    # add two endpoints
    Add-PodeEndpoint -Address * -Port 8999 -Protocol Tcp -Name 'EP1' -Acknowledge 'Hello there!' -CRLFMessageEnd
    Add-PodeEndpoint -Address '127.0.0.2' -Hostname 'foo.pode.com' -Port 8999 -Protocol Tcp -Name 'EP2' -Acknowledge 'Hello there!' -CRLFMessageEnd

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # hello verb for endpoint1
    Add-PodeVerb -Verb 'HELLO :forename :surname' -EndpointName EP1 -ScriptBlock {
        Write-PodeTcpClient -Message "HI 1, $($TcpEvent.Parameters.forename) $($TcpEvent.Parameters.surname)"
        "HI 1, $($TcpEvent.Parameters.forename) $($TcpEvent.Parameters.surname)" | Out-Default
    }

    # hello verb for endpoint2
    Add-PodeVerb -Verb 'HELLO :forename :surname' -EndpointName EP2 -ScriptBlock {
        Write-PodeTcpClient -Message "HI 2, $($TcpEvent.Parameters.forename) $($TcpEvent.Parameters.surname)"
        "HI 2, $($TcpEvent.Parameters.forename) $($TcpEvent.Parameters.surname)" | Out-Default
    }

    # catch-all verb for both endpoints
    Add-PodeVerb -Verb '*' -ScriptBlock {
        Write-PodeTcpClient -Message "Unrecognised verb sent"
    }

    # quit verb for both endpoints
    Add-PodeVerb -Verb 'Quit' -Close

}