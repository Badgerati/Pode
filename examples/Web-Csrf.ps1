<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with CSRF protection using either session or cookie-based tokens.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081. It includes CSRF protection, which can be configured
    to use either session-based tokens or cookie-based global secrets. The script also sets up a basic route for
    serving an index page with a CSRF token and a POST route to handle form submissions.

.PARAMETER Type
    Specifies the type of CSRF protection to use. Valid values are 'Cookie' and 'Session'. Default is 'Session'.

.EXAMPLE
    To run the sample: ./Web-Csrf.ps1

    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/token -Method Post

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Csrf.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [Parameter()]
    [ValidateSet('Cookie', 'Session')]
    [string]
    $Type = 'Session'
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

# create a server, and start listening on port 8081
Start-PodeServer -Threads 2 {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # set csrf middleware, then either session middleware, or cookie global secret
    switch ($Type.ToLowerInvariant()) {
        'cookie' {
            Set-PodeCookieSecret -Value 'rem' -Global
            Enable-PodeCsrfMiddleware -UseCookies
        }

        'session' {
            Enable-PodeSessionMiddleware -Duration 120
            Enable-PodeCsrfMiddleware
        }
    }

    # GET request for index page, and to make a token
    # this route will work, as GET methods are ignored by CSRF by default
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $token = (New-PodeCsrfToken)
        Write-PodeViewResponse -Path 'index-csrf' -Data @{ 'csrfToken' = $token } -FlashMessages
    }

    # POST route for form with and without csrf token
    Add-PodeRoute -Method Post -Path '/token' -ScriptBlock {
        Move-PodeResponseUrl -Url '/'
    }

}