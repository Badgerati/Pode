$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening
Start-PodeServer -Type Pode -Threads 5 {

    # listen
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http
    Add-PodeEndpoint -Address * -Port 8091 -Protocol Ws
    #Add-PodeEndpoint -Address * -Port 8095 -Protocol Http
    #Add-PodeEndpoint -Address * -Port 8090 -CertificateFile './certs/pode-cert.pfx' -CertificatePassword '1234' -Protocol Https

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Html

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'websockets'
    }

    Add-PodeRoute -Method Get -Path '/msg' -ScriptBlock {
        Send-PodeSignal -Data @{ Message = 'Hello, there' }
    }
}