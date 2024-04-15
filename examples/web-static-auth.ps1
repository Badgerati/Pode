$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
if (Test-Path -Path "$($path)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
}
else {
    Import-Module -Name 'Pode'
}

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address localhost -Port 8085 -Protocol Http

    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic -Realm 'Pode Static Page' | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # STATIC asset folder route
    Add-PodeStaticRoute -Path '/assets' -Source './assets' -Defaults @('index.html') -Authentication 'Validate'
    Add-PodeStaticRoute -Path '/assets/download' -Source './assets' -DownloadOnly

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'web-static' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request to download a file from static route
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path '/assets/images/Fry.png'
    }

}