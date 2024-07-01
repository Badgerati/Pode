try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # add two endpoints
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Tcp -CRLFMessageEnd #-Acknowledge 'Welcome!'
    # Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Tcps -SelfSigned -CRLFMessageEnd -TlsMode Explicit -Acknowledge 'Welcome!'
    # Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Tcps -SelfSigned -CRLFMessageEnd -TlsMode Implicit -Acknowledge 'Welcome!'

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeVerb -Verb 'HELLO' -ScriptBlock {
        Write-PodeTcpClient -Message "HI"
        'here' | Out-Default
    }

    Add-PodeVerb -Verb 'HELLO2 :username' -ScriptBlock {
        Write-PodeTcpClient -Message "HI2, $($TcpEvent.Parameters.username)"
    }

    Add-PodeVerb -Verb * -ScriptBlock {
        Write-PodeTcpClient -Message 'Unrecognised verb sent'
    }

    # Add-PodeVerb -Verb * -Close -ScriptBlock {
    #     $TcpEvent.Request.Body | Out-Default
    #     Write-PodeTcpClient -Message "HTTP/1.1 200 `r`nConnection: close`r`n`r`n<b>Hello, there</b>"
    # }

    # Add-PodeVerb -Verb 'STARTTLS' -UpgradeToSsl

    # Add-PodeVerb -Verb 'STARTTLS' -ScriptBlock {
    #     Write-PodeTcpClient -Message 'TLS GO AHEAD'
    #     $TcpEvent.Request.UpgradeToSSL()
    # }

    # Add-PodeVerb -Verb 'QUIT' -Close

    Add-PodeVerb -Verb 'QUIT' -ScriptBlock {
        Write-PodeTcpClient -Message 'Bye!'
        Close-PodeTcpClient
    }

    Add-PodeVerb -Verb 'HELLO3' -ScriptBlock {
        Write-PodeTcpClient -Message "Hi! What's your name?"
        $name = Read-PodeTcpClient -CRLFMessageEnd
        Write-PodeTcpClient -Message "Hi, $($name)!"
    }
}