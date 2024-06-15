$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
if (Test-Path -Path "$($path)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
}
else {
    Import-Module -Name 'Pode'
}
# or just:
# Import-Module Pode

$LOGGING_TYPE = 'syslog' # Terminal, File, Custom

# create a server, and start listening on port 8085
Start-PodeServer -browse {

    Add-PodeEndpoint -Address localhost -Port 8085 -Protocol Http
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
        'syslog' {
            $logging = New-PodeLoggingMethod -syslog  -Server 127.0.0.1  -Transport UDP

            $logging | Enable-PodeRequestLogging
            $logging | Enable-PodeErrorLogging
            $logging | Enable-PodeLogging -Name 'custom'


        }
    }
    Write-PodeLog -Name 'custom' -Message 'just started' -Level 'Info'
    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeLog -Name  'custom' -Message 'My custom log' -Level 'Info'
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }

    # GET request throws fake "500" server error status code
    Add-PodeRoute -Method Get -Path '/error' -ScriptBlock {

        Set-PodeResponseStatus -Code 500
    }

    Add-PodeRoute -Method Get -Path '/exception' -ScriptBlock {
        try {
            throw 'something happened'
        }
        catch {
            $_ | Write-PodeErrorLog
        }
        Set-PodeResponseStatus -Code 500
    }

    # GET request to download a file
    Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'Anger.jpg'
    }

}
