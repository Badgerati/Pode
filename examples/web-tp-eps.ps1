$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Endpoint *:8085 -Protocol HTTP

    # log requests to the terminal
    logger terminal

    # import the EPS module to each runspace
    Import-PodeModule -Name EPS

    # set view engine to EPS renderer
    Set-PodeViewEngine -Type EPS -ScriptBlock {
        param($path, $data)

        if ($null -eq $data) {
            return (Invoke-EpsTemplate -Path $path)
        }
        else {
            return (Invoke-EpsTemplate -Path $path -Binding $data)
        }
    }

    # GET request for web page on "localhost:8085/"
    route 'get' '/' {
        Write-PodeViewResponse -Path 'index' -Data @{ 'numbers' = @(1, 2, 3); 'date' = [DateTime]::UtcNow; }
    }

}