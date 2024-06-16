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

# create a server, and start listening
Start-PodeServer -Threads 3 {

    # listen
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Ws
    #Add-PodeEndpoint -Address localhost -Port 8090 -Certificate './certs/pode-cert.pfx' -CertificatePassword '1234' -Protocol Https
    #Add-PodeEndpoint -Address localhost -Port 8091 -Certificate './certs/pode-cert.pfx' -CertificatePassword '1234' -Protocol Wss

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Level Error, Debug, Verbose

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Html

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'websockets'
    }

    # SIGNAL route, to return current date
    Add-PodeSignalRoute -Path '/' -ScriptBlock {
        $msg = $SignalEvent.Data.Message

        if ($msg -ieq '[date]') {
            $msg = [datetime]::Now.ToString()
        }

        Send-PodeSignal -Value @{ message = $msg }
    }
}