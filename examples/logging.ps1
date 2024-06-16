param(
    [ValidateSet('Terminal', 'File', 'Custom', 'Syslog')]
    [string]
    $LoggingType = 'Syslog',

    [switch]
    $Raw
)

try {
    $FileBrowserPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $podePath = Split-Path -Parent -Path (Split-Path -Parent -Path $FileBrowserPath)
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop -MaximumVersion 2.99.99
    }
}
catch { throw }
# or just:
# Import-Module Pode

# create a server, and start listening on port 8085
Start-PodeServer -browse {

    Add-PodeEndpoint -Address localhost -Port 8085 -Protocol Http
    Set-PodeViewEngine -Type Pode

    switch ($LoggingType.ToLowerInvariant()) {
        'terminal' {
            $logging = New-PodeLoggingMethod -Terminal

            $logging | Enable-PodeRequestLogging -Raw:$Raw
            $logging | Enable-PodeErrorLogging -Raw:$Raw
            $logging | Enable-PodeLogging -Name 'custom' -Raw:$Raw
        }

        'file' {
            $logging = New-PodeLoggingMethod -File -Name 'requests' -MaxDays 4

            $logging | Enable-PodeRequestLogging -Raw:$Raw
            $logging | Enable-PodeErrorLogging -Raw:$Raw
            $logging | Enable-PodeLogging -Name 'custom' -Raw:$Raw
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

            $logging | Enable-PodeRequestLogging -Raw:$Raw
            $logging | Enable-PodeErrorLogging -Raw:$Raw
            $logging | Enable-PodeLogging -Name 'custom' -Raw:$Raw
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
