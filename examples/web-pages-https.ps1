$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# web-pages-https.ps1 example notes:
# ----------------------------------#
# to use the hostname listener, you'll need to add "pode.foo.com  127.0.0.1" to your hosts file
# ----------------------------------

# create a server, flagged to generate a self-signed cert for dev/testing
Start-PodeServer {
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels Error

    # bind to ip/port and set as https with self-signed cert
    Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -SelfSigned
    #Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -Certificate './certs/cert.pem' -CertificateKey './certs/key.pem' -CertificatePassword 'test'
    #Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -Certificate './certs/cert_nodes.pem' -CertificateKey './certs/key_nodes.pem'
    #Add-PodeEndpoint -Address * -Port 8443 -Protocol Https -CertificateThumbprint '2A623A8DC46ED42A13B27DD045BFC91FDDAEB957'

    # set view engine for web pages
    Set-PodeViewEngine -Type Pode

    # GET request for web page at "/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        Set-PodeResponseStatus -Code 500
    }

    Add-PodeRoute -Method 'GET' -Path '/test' -ScriptBlock {
        Write-PodeTextResponse -Value (Get-Date)
    }

}
