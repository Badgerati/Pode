$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # setup basic auth (base64> username:password in header)
    New-PodeAuthType -Basic | Add-PodeAuth -Name 'Validate' -ScriptBlock {
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

    # listen on localhost:8085
    Add-PodeEndpoint -Address localhost:8090 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # make routes for functions - with every route requires authentication
    ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Middleware (Get-PodeAuthMiddleware -Name 'Validate' -Sessionless) -Verbose

    # make routes for every exported command in Pester
    # ConvertTo-PodeRoute -Module Pester -Verbose

}