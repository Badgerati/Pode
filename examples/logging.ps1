param(
    [ValidateSet('Terminal', 'File', 'mylog', 'Syslog')]
    [string]
    $LoggingType = 'Syslog',

    [switch]
    $Raw
)

try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
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

# create a server, and start listening on port 8085
Start-PodeServer -browse {

    Add-PodeEndpoint -Address localhost -Port 8085 -Protocol Http
    Set-PodeViewEngine -Type Pode

    switch ($LoggingType.ToLowerInvariant()) {
        'terminal' {
            $logging = New-PodeLoggingMethod -Terminal
        }

        'file' {
            $logging = New-PodeLoggingMethod -File -Name 'requests' -MaxDays 4
        }

        'custom' {
            $logging = New-PodeLoggingMethod -Custom -ScriptBlock {
                param($item)
                # send request row to S3
            }
        }

        'syslog' {
            $logging = New-PodeLoggingMethod -syslog  -Server 127.0.0.1  -Transport UDP -AsUTC -ISO8601
        }
    }
    $logging | Enable-PodeMainLogging -Raw:$Raw
    $logging | Enable-PodeRequestLogging -Raw:$Raw
    $logging | Enable-PodeErrorLogging -Raw:$Raw
    $logging | Enable-PodeGeneralLogging -Name 'mylog' -Raw:$Raw

    Write-PodeLog -Name 'mylog' -Message 'just started' -Level 'Info'
    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeLog -Name  'mylog' -Message 'My custom log' -Level 'Info'
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
