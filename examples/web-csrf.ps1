param(
    [Parameter()]
    [ValidateSet('Cookie', 'Session')]
    [string]
    $Type = 'Session'
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8090
Start-PodeServer -Threads 2 {

    # listen on localhost:8090
    Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http

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