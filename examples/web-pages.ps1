param(
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 1 -Verbose {
    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http -Name '8090Address'
    Add-PodeEndpoint -Address * -Port $Port -Protocol Http -Name '8085Address' -RedirectTo '8090Address'

    # allow the local ip and some other ips
    # Add-PodeAccessRule -Access Allow -Type IP -Values @('127.0.0.1', '[::1]')
    # Add-PodeAccessRule -Access Allow -Type IP -Values @('192.169.0.1', '192.168.0.2')

    # deny an ip
    # Add-PodeAccessRule -Access Deny -Type IP -Values 10.10.10.10
    # Add-PodeAccessRule -Access Deny -Type IP -Values '10.10.0.0/24'
    # Add-PodeAccessRule -Access Deny -Type IP -Values all

    # limit
    # Add-PodeLimitRule -Type IP -Values all -Limit 100 -Seconds 5

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

    # GET request for web page on "localhost:8085/"
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

    Add-PodeRoute -Method Get -Path '/api/*/hello' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for every hello route' }
    }

    $hmm = 'well well'
    Add-PodeRoute -Method Get -Path '/script' -FilePath './modules/route_script.ps1'

}