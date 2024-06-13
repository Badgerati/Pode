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

# create a server, and start listening
Start-PodeServer -Threads 5 {

    # listen
    Add-PodeEndpoint -Address localhost -Port 8081 -Certificate './certs/pode-cert.pfx' -CertificatePassword '1234' -Protocol Https
    # Add-PodeEndpoint -Address localhost -Port 8081 -SelfSigned -Protocol Https

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeJsonResponse -Value @{
            Kenobi = 'Hello, there'
        }
    }
}