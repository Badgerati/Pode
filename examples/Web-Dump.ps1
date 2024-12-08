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
5
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
Start-PodeServer -Threads 4 -EnablePool Tasks -ScriptBlock {

    # listen on localhost:8081
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Https -SelfSigned
    Add-PodeEndpoint -Address localhost -Port 8083 -Protocol Http
    Add-PodeEndpoint -Address localhost -Port 8025 -Protocol Smtp
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Ws -Name 'WS1'
    Add-PodeEndpoint -Address localhost -Port 8091 -Protocol Http -Name 'WS'
    Add-PodeEndpoint -Address localhost -Port 8100 -Protocol Tcp
    Add-PodeEndpoint -Address localhost -Port 9002 -Protocol Tcps -SelfSigned

    Set-PodeTaskConcurrency -Maximum 10

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

        Add-PodeRoute -Method Get -Path '/task/async' -PassThru -ScriptBlock {
            Invoke-PodeTask -Name 'Test' -ArgumentList @{ value = 'wizard' } | Out-Null
            Write-PodeJsonResponse -Value @{ Result = 'jobs done' }
        } | Set-PodeOARouteInfo -Summary 'Task'
    }

    Add-PodeVerb -Verb 'HELLO' -ScriptBlock {
        Write-PodeTcpClient -Message 'HI'
        'here'
    }

    # setup an smtp handler
    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
        Write-Verbose '- - - - - - - - - - - - - - - - - -'
        Write-Verbose $SmtpEvent.Email.From
        Write-Verbose $SmtpEvent.Email.To
        Write-Verbose '|'
        Write-Verbose $SmtpEvent.Email.Body
        Write-Verbose '|'
        # Write-Verbose $SmtpEvent.Email.Data
        # Write-Verbose '|'
        $SmtpEvent.Email.Attachments
        if ($SmtpEvent.Email.Attachments.Length -gt 0) {
            #$SmtpEvent.Email.Attachments[0].Save('C:\temp')
        }
        Write-Verbose '|'
        $SmtpEvent.Email
        $SmtpEvent.Request
        $SmtpEvent.Email.Headers
        Write-Verbose '- - - - - - - - - - - - - - - - - -'
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

    Add-PodeVerb -Verb 'QUIT' -ScriptBlock {
        Write-PodeTcpClient -Message 'Bye!'
        Close-PodeTcpClient
    }

    Add-PodeVerb -Verb 'HELLO3' -ScriptBlock {
        Write-PodeTcpClient -Message "Hi! What's your name?"
        $name = Read-PodeTcpClient -CRLFMessageEnd
        Write-PodeTcpClient -Message "Hi, $($name)!"
    }


    Add-PodeTask -Name 'Test' -ScriptBlock {
        param($value)
        Start-PodeSleep -Seconds 10
        Write-Verbose  "a $($value) is comming"
        Start-PodeSleep -Seconds 10
        Write-Verbose  "a $($value) is comming...2"
        Start-PodeSleep -Seconds 10
        Write-Verbose  "a $($value) is comming...3"
        Start-PodeSleep -Seconds 10
        Write-Verbose  "a $($value) is comming...4"
        Start-PodeSleep -Seconds 10
        Write-Verbose  "a $($value) is comming...5"
        Start-PodeSleep -Seconds 10
        Write-Verbose "a $($value) is comming...6"
        Start-PodeSleep -Seconds 10
        Write-Verbose  "a $($value) is never late, it arrives exactly when it means to"
    }
    # schedule minutely using predefined cron
    $message = 'Hello, world!'
    Add-PodeSchedule -Name 'predefined' -Cron '@minutely' -Limit 2 -ScriptBlock {
        param($Event, $Message1, $Message2)
        Write-Verbose     $using:message
        Get-PodeSchedule -Name 'predefined'
        Write-Verbose "Last: $($Event.Sender.LastTriggerTime)"
        Write-Verbose  "Next: $($Event.Sender.NextTriggerTime)"
        Write-Verbose  "Message1: $($Message1)"
        Write-Verbose "Message2: $($Message2)"
    }

    Add-PodeSchedule -Name 'from-file' -Cron '@minutely' -FilePath './scripts/schedule.ps1'

    # schedule defined using two cron expressions
    Add-PodeSchedule -Name 'two-crons' -Cron @('0/3 * * * *', '0/5 * * * *') -ScriptBlock {
        Write-Verbose  'double cron'
        Get-PodeSchedule -Name 'two-crons' | Out-Default
    }

    # schedule to run every tuesday at midnight
    Add-PodeSchedule -Name 'tuesdays' -Cron '0 0 * * TUE' -ScriptBlock {
        # logic
    }

    # schedule to run every 5 past the hour, starting in 2hrs
    Add-PodeSchedule -Name 'hourly-start' -Cron '5,7,9 * * * *' -ScriptBlock {
        # logic
    } -StartTime ([DateTime]::Now.AddHours(2))

    # schedule to run every 10 minutes, and end in 2hrs
    Add-PodeSchedule -Name 'every-10mins-end' -Cron '0/10 * * * *' -ScriptBlock {
        # logic
    } -EndTime ([DateTime]::Now.AddHours(2))

    # adhoc invoke a schedule's logic
    Add-PodeRoute -Method Get -Path '/api/run' -ScriptBlock {
        Invoke-PodeSchedule -Name 'predefined' -ArgumentList @{
            Message1 = 'Hello!'
            Message2 = 'Bye!'
        }
    }

}