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
Start-PodeServer -Threads 1 -ScriptBlock {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # set view engine to pode renderer
    Set-PodeViewEngine -Type Pode

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
}