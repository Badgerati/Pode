$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# web-pages-https.ps1 example notes:
# ----------------------------------
# Adding a self-signed/existing cert only supported for Windows.
# This will not clear the binding afterwards (netsh http delete sslcert 0.0.0.0:8443), nor will it remove the certificate
# from the personal store.  Cleanup should be done manually as required. Generated self-signed cert for fqdn localhost,
# this is just for dev/testing and proof of concept
#
# to use the hostname listener, you'll need to add "pode.foo.com  127.0.0.1" to your hosts file
# ----------------------------------

# create a server, flagged to generate a self-signed cert for dev/testing
Start-PodeServer {

    # bind to ip/port and set as https with self-signed cert
    Add-PodeEndpoint -Address *:8443 -Protocol HTTPS -SelfSigned
    #listen "pode.foo.com:8443" https -cert self

    # set view engine for web pages
    Set-PodeViewEngine -Type Pode

    # GET request for web page at "/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($session)
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        param($session)
        Set-PodeResponseStatus -Code 500
    }

}
