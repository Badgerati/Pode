<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with various HTTPS certificate options.

.DESCRIPTION
    This script sets up a Pode server listening on port 8443 with HTTPS enabled using different certificate options based on the input parameter.
    It demonstrates how to handle GET requests and serve web pages with Pode's view engine.

.PARAMETER CertType
    Specifies the type of certificate to use for HTTPS. Valid values are 'SelfSigned', 'CertificateWithPassword', 'Certificate', and 'CertificateThumbprint'.
    Default is 'SelfSigned'.

.EXAMPLE
     To run the sample: ./Web-PagesHttps.ps1

    Invoke-RestMethod -Uri https://localhost:8443/ -Method Get
    Invoke-RestMethod -Uri https://localhost:8443/error -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-PagesHttps.ps1
.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [string]
    [ValidateSet('SelfSigned', 'CertificateWithPassword', 'Certificate' , 'CertificateThumbprint')]
    $CertType = 'SelfSigned'
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
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

# create a server, flagged to generate a self-signed cert for dev/testing
Start-PodeServer {

    # bind to ip/port and set as https with self-signed cert
    switch ($CertType) {
        'SelfSigned' {
            Add-PodeEndpoint -Address localhost -Port 8443 -Protocol Https -SelfSigned
        }
        'CertificateWithPassword' {
            Add-PodeEndpoint -Address localhost -Port 8443 -Protocol Https -Certificate './certs/cert.pem' -CertificateKey './certs/key.pem' -CertificatePassword 'test'
        }
        'Certificate' {
            Add-PodeEndpoint -Address localhost -Port 8443 -Protocol Https -Certificate './certs/cert_nodes.pem' -CertificateKey './certs/key_nodes.pem'
        }
        'CertificateThumbprint' { Add-PodeEndpoint -Address localhost -Port 8443 -Protocol Https -CertificateThumbprint '2A623A8DC46ED42A13B27DD045BFC91FDDAEB957' }
    }
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

}
