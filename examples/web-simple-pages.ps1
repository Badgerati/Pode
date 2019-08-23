$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# create a server, and start listening on port 8090
Start-PodeServer -Threads 2 {

    # listen on localhost:8090
    Add-PodeEndpoint -Address localhost:8090 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodePage -Name Processes -ScriptBlock { Get-Process }
    Add-PodePage -Name Services -ScriptBlock { Get-Service }

    # make routes for functions - with every route requires authentication
    #ConvertTo-PodeRoute -Commands @('Get-ChildItem', 'Get-Host', 'Invoke-Expression') -Middleware (Get-PodeAuthMiddleware -Name 'Validate' -Sessionless) -Verbose

    # make routes for every exported command in Pester
    # ConvertTo-PodeRoute -Module Pester -Verbose

}