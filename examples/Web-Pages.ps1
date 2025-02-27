<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with various routes, access rules, logging, and request handling.

.DESCRIPTION
    This script sets up a Pode server listening on multiple endpoints with request redirection.
    It demonstrates how to handle GET, POST, and other HTTP requests, set up access and limit rules,
    implement custom logging, and serve web pages using Pode's view engine.

.PARAMETER Port
    The port number on which the server will listen. Default is 8081.

.EXAMPLE
    To run the sample: ./Web-Pages.ps1

    Invoke-RestMethod -Uri http://localhost:8081/ -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/variable -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/error -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/redirect -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/redirect-port -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/download -Method Get
    Invoke-RestMethod -Uri http://localhost:8081/testuser/details -Method Post
    Invoke-RestMethod -Uri http://localhost:8081/all -Method Merge
    Invoke-RestMethod -Uri http://localhost:8081//api/test/hello -Method Get

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Pages.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [int]
    $Port = 8081
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
Start-PodeServer -Threads 2 -Verbose {
    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8090 -Protocol Http -Name '8090Address'
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http -Name "$($Port)Address" -RedirectTo '8090Address'

    # allow the local ip and some other ips
    # Add-PodeAccessRule -Access Allow -Type IP -Values @('127.0.0.1', '[::1]')
    # Add-PodeAccessRule -Access Allow -Type IP -Values @('192.169.0.1', '192.168.0.2')

    # deny an ip
    # Add-PodeAccessRule -Access Deny -Type IP -Values 10.10.10.10
    # Add-PodeAccessRule -Access Deny -Type IP -Values '10.10.0.0/24'
    # Add-PodeAccessRule -Access Deny -Type IP -Values all
    # Add-PodeLimitAccessRule -Name 'Main' -Action Deny -Component @(
    #     New-PodeLimitIPComponent -IP '127.0.0.1'
    #     New-PodeLimitRouteComponent -Path '/error'
    # )

    # limit
    # Add-PodeLimitRule -Type IP -Values all -Limit 100 -Seconds 5
    # Add-PodeLimitRateRule -Name 'Main' -Limit 5 -Duration 10000 -Component @(
    #     New-PodeLimitIPComponent #-IP '127.0.0.2'
    #     New-PodeLimitRouteComponent -Path '/'
    # )
    # Add-PodeLimitRateRule -Name 'Debounce' -Limit 1 -Duration 10000 -Component @(
    #     New-PodeLimitIPComponent
    #     New-PodeLimitRouteComponent
    #     New-PodeLimitMethodComponent -Method Get, Post
    # )

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal -Batch 10 -BatchTimeout 10 | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

    # wire up a custom logger
    $logType = New-PodeLoggingMethod -Custom -ScriptBlock {
        param($item)
        $item.HttpMethod | Out-Default
    }

    $logType | Add-PodeLogger -Name 'custom' -ScriptBlock {
        param($item)
        return @{
            HttpMethod = $item.HttpMethod
        }
    }

    Use-PodeRoutes -Path './routes'

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # $WebEvent.Request | Write-PodeLog -Name 'custom'
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # Set an output variable
    Add-PodeRoute -Method Post -Path '/variable' -ScriptBlock {
        Out-PodeVariable -Name $WebEvent.Data.Name -Value $WebEvent.Data.Value
        Out-PodeVariable -Name Pode_Complex_Object -Value @{ Name = 'Joe'; Age = 42 }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        Set-PodeResponseStatus -Code 500
    }

    # GET request to page that merely redirects to google
    Add-PodeRoute -Method Get -Path '/redirect' -ScriptBlock {
        Move-PodeResponseUrl -Url 'https://google.com'
    }

    # GET request that redirects to same host, just different port
    Add-PodeRoute -Method Get -Path '/redirect-port' -ScriptBlock {
        if ($WebEvent.Request.Url.Port -ne 8086) {
            Move-PodeResponseUrl -Port 8086
        }
        else {
            Write-PodeJsonResponse -Value @{ 'value' = 'you got redirected!'; }
        }
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

    # GET and POST request with parameters
    Add-PodeRoute -Method Get, Post -Path '/:userId/details' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'userId' = $WebEvent.Parameters['userId'] }
    }

    # ALL request, that supports every method and it a default drop route
    Add-PodeRoute -Method * -Path '/all' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for every http method' }
    }

    Add-PodeRoute -Method Get -Path '/api/test' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for test route' }
    }

    Add-PodeRoute -Method Get -Path '/api/*/hello' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for every hello route' }
    }

    Add-PodeRoute -Method Delete -Path '/delete' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for delete method' }
    }

    $script:hmm = 'well well'
    Add-PodeRoute -Method Get -Path '/script' -FilePath './modules/RouteScript.ps1'

}