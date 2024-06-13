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
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Tcp -Name 'EP1' -Acknowledge 'Hello there!' -CRLFMessageEnd
    Add-PodeEndpoint -Address localhost -Hostname 'foo.pode.com' -Port 9000 -Protocol Tcp -Name 'EP2' -Acknowledge 'Hello there!' -CRLFMessageEnd

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