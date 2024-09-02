<#
.SYNOPSIS
    PowerShell script to set up a Pode server with HTTPS and client certificate authentication.

.DESCRIPTION
    This script sets up a Pode server that listens on a specified port with HTTPS using a self-signed certificate.
    It enables client certificate authentication for securing access to the server.

    .EXAMPLE
    To run the sample: ./Web-AuthBasicClientcert.ps1

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-AuthBasicClientcert.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
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

# create a server, flagged to generate a self-signed cert for dev/testing, but allow client certs for auth
Start-PodeServer {

    # bind to ip/port and set as https with self-signed cert
    Add-PodeEndpoint -Address localhost -Port 8443 -Protocol Https -SelfSigned -AllowClientCertificate

    # set view engine for web pages
    Set-PodeViewEngine -Type Pode

    # setup client cert auth
    New-PodeAuthScheme -ClientCertificate | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($cert, $errors)

        # validate the thumbprint - here you would check a real cert store, or database
        if ($cert.Thumbprint -ieq '3571B3BE3CA202FA56F73691FC258E653D0874C1') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        # an invalid cert
        return @{ Message = 'Invalid certificate supplied' }
    }

    # GET request for web page at "/"
    Add-PodeRoute -Method Get -Path '/' -Authentication 'Validate' -ScriptBlock {
        #$WebEvent.Request.ClientCertificate | out-default
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -Authentication 'Validate' -ScriptBlock {
        Set-PodeResponseStatus -Code 500
    }

}
