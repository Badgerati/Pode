try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

$LOGGING_TYPE = 'terminal' # Terminal, File, Custom

# create a server, and start listening on port 8081
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    Set-PodeViewEngine -Type Pode

    switch ($LOGGING_TYPE.ToLowerInvariant()) {
        'terminal' {
            New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
        }

        'file' {
            New-PodeLoggingMethod -File -Name 'requests' -MaxDays 4 | Enable-PodeRequestLogging
        }

        'custom' {
            $type = New-PodeLoggingMethod -Custom -ScriptBlock {
                param($item)
                # send request row to S3
            }

            $type | Enable-PodeRequestLogging
        }
    }

    # GET request for web page on "localhost:8081/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {
        Set-PodeResponseStatus -Code 500
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

}
