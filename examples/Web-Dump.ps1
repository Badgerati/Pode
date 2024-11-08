<#
.SYNOPSIS
    Initializes and starts a Pode server with OpenAPI support and error logging.

.DESCRIPTION
    This script sets up a Pode server with HTTP endpoints, error logging, and OpenAPI documentation.
    It also includes a sample route to simulate a critical error and dump the server's memory state.

 .EXAMPLE
    To run the sample: ./Web-Dump.ps1

    OpenAPI Info:
    Specification:
        http://localhost:8081/openapi
    Documentation:
        http://localhost:8081/docs

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-Dump.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

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

# Start Pode server with specified script block
Start-PodeServer -Threads 4  -ScriptBlock {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8083 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8025 -Protocol Smtp
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Ws -Name 'WS1'
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Http -Name 'WS'
    Add-PodeEndpoint -Address localhost -Port 8100 -Protocol Tcp


    # set view engine to pode renderer
    Set-PodeViewEngine -Type Html

    # Enable error logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging


    # Enable OpenAPI documentation

    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'   -DisableMinimalDefinitions -NoDefaultResponses

    Add-PodeOAInfo -Title 'Dump - OpenAPI 3.0.3' -Version 1.0.1
    Add-PodeOAServerEndpoint -url '/api/v3' -Description 'default endpoint'

    # Enable OpenAPI viewers
    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode

    # Enable OpenAPI editor and bookmarks
    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'

    # Setup session details
    Enable-PodeSessionMiddleware -Duration 120 -Extend

    # Define API routes
    Add-PodeRouteGroup -Path '/api/v3'   -Routes {

        Add-PodeRoute -PassThru -Method Get -Path '/dump' -ScriptBlock {
            $format = $WebEvent.Query['format']
            try {
                # Simulate a critical error
                throw [System.DivideByZeroException] 'Simulated divide by zero error'
            }
            catch {
                $_ | Invoke-PodeDump  -Format $format
            }
        } | Set-PodeOARouteInfo -Summary 'Dump state' -Description 'Dump the memory state of the server.' -Tags 'dump'  -OperationId 'dump'-PassThru |
            Set-PodeOARequest -Parameters (New-PodeOAStringProperty -Name 'format' -Description 'Dump export format.' -Enum 'json', 'clixml', 'txt', 'bin', 'yaml' -Default 'json' | ConvertTo-PodeOAParameter -In Query )
    }

    Add-PodeVerb -Verb 'HELLO' -ScriptBlock {
        Write-PodeTcpClient -Message 'HI'
        'here' | Out-Default
    }

    # setup an smtp handler
    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
        Write-PodeHost '- - - - - - - - - - - - - - - - - -'
        Write-PodeHost $SmtpEvent.Email.From
        Write-PodeHost $SmtpEvent.Email.To
        Write-PodeHost '|'
        Write-PodeHost $SmtpEvent.Email.Body
        Write-PodeHost '|'
        # Write-PodeHost $SmtpEvent.Email.Data
        # Write-PodeHost '|'
        $SmtpEvent.Email.Attachments | Out-Default
        if ($SmtpEvent.Email.Attachments.Length -gt 0) {
            #$SmtpEvent.Email.Attachments[0].Save('C:\temp')
        }
        Write-PodeHost '|'
        $SmtpEvent.Email | Out-Default
        $SmtpEvent.Request | out-default
        $SmtpEvent.Email.Headers | out-default
        Write-PodeHost '- - - - - - - - - - - - - - - - - -'
    }

    # GET request for web page
    Add-PodeRoute -Method Get -Path '/' -EndpointName 'WS' -ScriptBlock {
        Write-PodeViewResponse -Path 'websockets'
    }

    # SIGNAL route, to return current date
    Add-PodeSignalRoute -Path '/' -ScriptBlock {
        $msg = $SignalEvent.Data.Message

        if ($msg -ieq '[date]') {
            $msg = [datetime]::Now.ToString()
        }

        Send-PodeSignal -Value @{ message = $msg }
    }
}