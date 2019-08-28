param (
    [int]
    $Port = 8085
)

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 -Browse {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http -Name '8090Address'
    Add-PodeEndpoint -Address * -Port $Port -Protocol Http -RedirectTo '8090Address'

    # allow the local ip and some other ips
    Add-PodeAccessRule -Access Allow -Type IP -Values @('127.0.0.1', '[::1]')
    Add-PodeAccessRule -Access Allow -Type IP -Values @('192.169.0.1', '192.168.0.2')

    # deny an ip
    Add-PodeAccessRule -Access Deny -Type IP -Values 10.10.10.10
    Add-PodeAccessRule -Access Deny -Type IP -Values '10.10.0.0/24'
    Add-PodeAccessRule -Access Deny -Type IP -Values all

    # log requests to the terminal
    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
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

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($e)
        $e.Request | Write-PodeLog -Name 'custom'
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
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
        param($event)
        if ($event.Request.Url.Port -ne 8086) {
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

    # GET request with parameters
    Add-PodeRoute -Method Get -Path '/:userId/details' -ScriptBlock {
        param($event)
        Write-PodeJsonResponse -Value @{ 'userId' = $event.Parameters['userId'] }
    }

    # ALL request, that supports every method and it a default drop route
    Add-PodeRoute -Method * -Path '/all' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for every http method' }
    }

    Add-PodeRoute -Method Get -Path '/api/*/hello' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'value' = 'works for every hello route' }
    }

    Add-PodeRoute -Method Get -Path '/script' -FilePath './modules/route_script.ps1'

}