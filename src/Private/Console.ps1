
<#
.SYNOPSIS
    Displays Pode server information on the console, including version, PID, status, endpoints, and control commands.

.DESCRIPTION
    The Show-PodeConsoleInfo function displays key information about the current Pode server instance.
    It optionally clears the console before displaying server details such as version, process ID (PID), and running status.
    If the server is running, it also displays information about active endpoints and OpenAPI definitions.
    Additionally, it provides server control commands like restart, suspend.

.PARAMETER ClearHost
    Clears the console screen before displaying server information.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Show-PodeConsoleInfo {
    param(
        [switch]
        $ClearHost,

        [switch]
        $Force,

        [switch]
        $ShowTopSeparator
    )



    # Get the current server state and timestamp
    $serverState = Get-PodeServerState
    $timestamp = if ($PodeContext.Server.Console.ShowTimeStamp ) { "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" } else { '' }

    if (!$PodeContext) { return }

    # Define color variables with fallback
    $headerColor = if ($null -ne $PodeContext.Server.Console.Colors.Header) {
        $PodeContext.Server.Console.Colors.Header
    }
    else {
        [System.ConsoleColor]::White
    }

    if ($PodeContext.Server.Console.Quiet -and !$Force) {
        return
    }

    switch ($serverState) {
        'Suspended' {
            $status = $Podelocale.suspendedMessage
            $statusColor = [System.ConsoleColor]::Yellow
            $showHelp = (!$PodeContext.Server.Console.DisableConsoleInput -and $PodeContext.Server.Console.ShowHelp)
            $noHeaderNewLine = $false
            $ctrlH = !$showHelp
            $footerSeparator = $false
            $topSeparator = $ShowTopSeparator.IsPresent
            $headerSeparator = $true
            break
        }
        'Suspending' {
            $status = $Podelocale.suspendingMessage
            $statusColor = [System.ConsoleColor]::Yellow
            $showHelp = $false
            $noHeaderNewLine = $true
            $ctrlH = $false
            $footerSeparator = $false
            $topSeparator = $true
            $headerSeparator = $false
            break
        }
        'Resuming' {
            $status = $Podelocale.resumingMessage
            $statusColor = [System.ConsoleColor]::Yellow
            $showHelp = $false
            $noHeaderNewLine = $true
            $ctrlH = $false
            $footerSeparator = $false
            $topSeparator = $true
            $headerSeparator = $false
            break
        }
        'Restarting' {
            $status = $Podelocale.restartingMessage
            $statusColor = [System.ConsoleColor]::Yellow
            $showHelp = $false
            $noHeaderNewLine = $false
            $ctrlH = $false
            $footerSeparator = $false
            $topSeparator = $true
            $headerSeparator = $false
            break
        }
        'Starting' {
            $status = $Podelocale.startingMessage
            $statusColor = [System.ConsoleColor]::Yellow
            $showHelp = $false
            $noHeaderNewLine = $true
            $ctrlH = $false
            $footerSeparator = $false
            $topSeparator = $true
            $headerSeparator = $false
            break
        }
        'Running' {
            $status = $Podelocale.runningMessage
            $statusColor = [System.ConsoleColor]::Green
            $showHelp = (!$PodeContext.Server.Console.DisableConsoleInput -and $PodeContext.Server.Console.ShowHelp)
            $noHeaderNewLine = $false
            $ctrlH = !$showHelp
            $footerSeparator = $false
            $topSeparator = $ShowTopSeparator.IsPresent
            $headerSeparator = $true
            break
        }
        'Terminating' {
            $status = $Podelocale.terminatingMessage
            $statusColor = [System.ConsoleColor]::Red
            $showHelp = $false
            $noHeaderNewLine = $true
            $ctrlH = $false
            $footerSeparator = $false
            $topSeparator = $true
            $headerSeparator = $false
            break
        }
        'Terminated' {
            $status = 'Terminated'
            $statusColor = [System.ConsoleColor]::Red
            $showHelp = $false
            $noHeaderNewLine = $false
            $ctrlH = $false
            $footerSeparator = $false
            $topSeparator = $ShowTopSeparator.IsPresent
            $headerSeparator = $true
            break
        }
        default {
            return
        }
    }

    if ($ClearHost -or $PodeContext.Server.Console.ClearHost) {
        Clear-Host
    }
    elseif ($topSeparator ) {
        # Write a horizontal divider line to the console.
        Write-PodeHostDivider -Force $true
    }

    # Write the header line with dynamic status color
    Write-PodeHost "`r$timestamp Pode $(Get-PodeVersion) (PID: $($PID)) [" -ForegroundColor $headerColor -Force:$Force -NoNewLine
    Write-PodeHost "$status" -ForegroundColor $statusColor -Force:$Force -NoNewLine
    Write-PodeHost ']              ' -ForegroundColor $headerColor -Force:$Force -NoNewLine:$noHeaderNewLine

    if ($headerSeparator) {
        # Write a horizontal divider line to the console.
        Write-PodeHostDivider -Force $true
    }

    if ($serverState -eq 'Running') {
        if ($PodeContext.Server.Console.ShowEndpoints) {
            # state what endpoints are being listened on
            Show-PodeConsoleEndpointsInfo -Force:$Force
        }
        if ($PodeContext.Server.Console.ShowOpenAPI) {
            # state the OpenAPI endpoints for each definition
            Show-PodeConsoleOAInfo -Force:$Force
        }
    }

    if ($showHelp) {
        Show-PodeConsoleHelp
    }
    elseif ($ctrlH ) {
        Show-PodeConsoleHelp -Hide
    }

    if ($footerSeparator) {
        # Write a horizontal divider line to the console.
        Write-PodeHostDivider -Force $true
    }
}


<#
.SYNOPSIS
    Displays or hides the help section for Pode server control commands.

.DESCRIPTION
    The `Show-PodeConsoleHelp` function dynamically displays a list of control commands available for managing the Pode server.
    Depending on the `$Hide` parameter, the help section can either be shown or hidden, with concise descriptions for each command.
    Colors for headers, keys, and descriptions are customizable via the `$PodeContext.Server.Console.Colors` configuration.

.PARAMETER Hide
    Switch to display the "Show Help" option instead of the full help section.

.NOTES
    This function is designed for Pode's internal console display system and may change in future releases.

.EXAMPLE
    Show-PodeConsoleHelp

    Displays the full help section for the Pode server.

.EXAMPLE
    Show-PodeConsoleHelp -Hide

    Displays only the "Show Help" option instead of the full help section.

#>
function Show-PodeConsoleHelp {
    param(
        [switch]
        $Hide
    )

    # Define help section color variables
    $helpHeaderColor = if ($null -ne $PodeContext.Server.Console.Colors.HelpHeader) {
        $PodeContext.Server.Console.Colors.HelpHeader
    }
    else {
        [System.ConsoleColor]::Yellow
    }

    $helpKeyColor = if ($null -ne $PodeContext.Server.Console.Colors.HelpKey) {
        $PodeContext.Server.Console.Colors.HelpKey
    }
    else {
        [System.ConsoleColor]::Green
    }

    $helpDescriptionColor = if ($null -ne $PodeContext.Server.Console.Colors.HelpDescription) {
        $PodeContext.Server.Console.Colors.HelpDescription
    }
    else {
        [System.ConsoleColor]::White
    }

    $helpDividerColor = if ($null -ne $PodeContext.Server.Console.Colors.HelpDivider) {
        $PodeContext.Server.Console.Colors.HelpDivider
    }
    else {
        [System.ConsoleColor]::Gray
    }

    # Show concise "Show Help" option if $Hide is true
    if ($Hide) {
        Write-PodeHost '    Ctrl+H  : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
        Write-PodeHost 'Show Help'  -ForegroundColor $helpDescriptionColor -Force:$Force
    }
    else {
        # Determine resume or suspend message based on server state
        $resumeOrSuspend = if ($serverState -eq 'Suspended') {
            $Podelocale.ResumeServerMessage
        }
        else {
            $Podelocale.SuspendServerMessage
        }

        # Enable or disable server state message
        $enableOrDisable = if (Test-PodeServerIsEnabled) { 'Disable Server' } else { 'Enable Server' }

        # Display help header
        Write-PodeHost $Podelocale.serverControlCommandsTitle -ForegroundColor $helpHeaderColor -Force:$Force

        if ($headerSeparator) {
            # Write a horizontal divider line to the console.
            Write-PodeHostDivider -Force $true
        }

        # Display help commands
        if (!$PodeContext.Server.Console.DisableTermination) {
            Write-PodeHost '    Ctrl+C   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
            Write-PodeHost "$($Podelocale.GracefullyTerminateMessage)" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        if ($PodeContext.Server.AllowedActions.Restart) {
            Write-PodeHost '    Ctrl+R   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
            Write-PodeHost "$($Podelocale.RestartServerMessage)" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        if ($PodeContext.Server.AllowedActions.Suspend) {
            Write-PodeHost '    Ctrl+U   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
            Write-PodeHost "$resumeOrSuspend" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        if (($serverState -eq 'Running') -and $PodeContext.Server.AllowedActions.Disable) {
            Write-PodeHost '    Ctrl+D   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
            Write-PodeHost "$enableOrDisable" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        Write-PodeHost '    Ctrl+H   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
        Write-PodeHost 'Hide Help' -ForegroundColor $helpDescriptionColor -Force:$Force

        if ((Get-PodeEndpointUrl) -and ($serverState -ne 'Suspended')) {
            Write-PodeHost '    Ctrl+B   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
            Write-PodeHost "$($Podelocale.OpenHttpEndpointMessage)" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        Write-PodeHost '    ----' -ForegroundColor $helpDividerColor -Force:$Force

        if ($serverState -eq 'Running') {
            Write-PodeHost '    Ctrl+E   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
            Write-PodeHost "$(if ($PodeContext.Server.Console.ShowEndpoints) { 'Hide' } else { 'Show' }) Endpoints" -ForegroundColor $helpDescriptionColor -Force:$Force

            # Check if OpenApi are in use
            if (Test-PodeOAEnabled) {
                Write-PodeHost '    Ctrl+O   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
                Write-PodeHost "$(if ($PodeContext.Server.Console.ShowOpenAPI) { 'Hide' } else { 'Show' }) OpenAPI" -ForegroundColor $helpDescriptionColor -Force:$Force
            }
        }

        Write-PodeHost '    Ctrl+L   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
        Write-PodeHost 'Clear the Console' -ForegroundColor $helpDescriptionColor -Force:$Force

        Write-PodeHost '    Ctrl+T   : ' -ForegroundColor $helpKeyColor -NoNewLine -Force:$Force
        Write-PodeHost "$(if ($PodeContext.Server.Console.Quiet) { 'Disable' } else { 'Enable' }) Quiet Mode" -ForegroundColor $helpDescriptionColor -Force:$Force

        # Final blank line for spacing
        Write-PodeHost
    }
}



<#
.SYNOPSIS
Writes a visual divider line to the console.

.DESCRIPTION
The `Write-PodeHostDivider` function outputs a horizontal divider line to the console.
For modern environments (PowerShell 6 and above or UTF-8 capable consoles),
it uses the `━` character repeated to form the divider. For older environments
like PowerShell 5.1, it falls back to the `-` character for compatibility.

.PARAMETER Force
Forces the output to display the divider even if certain conditions are not met.

.PARAMETER ForegroundColor
Specifies the foreground color of the divider.

.EXAMPLE
Write-PodeHostDivider

Writes a divider to the console using the appropriate characters for the environment.

.EXAMPLE
Write-PodeHostDivider -Force $true

Writes a divider to the console even if conditions for displaying it are not met.

.NOTES
This function dynamically adapts to the PowerShell version and console encoding, ensuring compatibility across different environments.
#>
function Write-PodeHostDivider {
    param (
        [bool]$Force = $false
    )

    if ($PodeContext.Server.Console.ShowDivider) {
        if ($null -ne $PodeContext.Server.Console.Colors.Divider) {
            $dividerColor = $PodeContext.Server.Console.Colors.Divider
        }
        else {
            $dividerColor = [System.ConsoleColor]::Yellow
        }
        # Determine the divider style based on PowerShell version and encoding support
        $dividerChar = if ($PSVersionTable.PSVersion.Major -ge 6 ) {
            '━' * $PodeContext.Server.Console.DividerLength  # Repeat the '━' character
        }
        else {
            '-' * $PodeContext.Server.Console.DividerLength # Repeat the '-' as a fallback
        }

        # Write the divider with the chosen style
        Write-PodeHost $dividerChar -ForegroundColor $dividerColor -Force:$Force
    }
    else {
        Write-PodeHost
    }
}



<#
.SYNOPSIS
    Displays information about the endpoints the Pode server is listening on.

.DESCRIPTION
    The `Show-PodeConsoleEndpointsInfo` function checks the Pode server's `EndpointsInfo`
    and displays details about each endpoint, including its URL and any specific flags
    such as `DualMode`. It provides a summary of the total number of endpoints and the
    number of general threads handling them.

.PARAMETER Force
    Overrides the -Quiet flag of the server.

.EXAMPLE
    Show-PodeConsoleEndpointsInfo

    This command will output details of all endpoints the Pode server is currently
    listening on, including their URLs and any relevant flags.

.NOTES
    This function uses `Write-PodeHost` to display messages, with the `Yellow` foreground
    color for the summary and other appropriate colors for URLs and flags.
#>
function Show-PodeConsoleEndpointsInfo {
    param(
        [switch]
        $Force
    )

    # Default colors if not set
    if ($null -ne $PodeContext.Server.Console.Colors.EndpointsHeader) {
        $headerColor = $PodeContext.Server.Console.Colors.EndpointsHeader
    }
    else {
        $headerColor = [System.ConsoleColor]::Yellow
    }

    if ($null -ne $PodeContext.Server.Console.Colors.Endpoints) {
        $endpointsColor = $PodeContext.Server.Console.Colors.Endpoints
    }
    else {
        $endpointsColor = [System.ConsoleColor]::Cyan
    }

    # Return early if no endpoints are available
    if ($PodeContext.Server.EndpointsInfo.Length -eq 0) {
        return
    }

    # Display header
    Write-PodeHost ($PodeLocale.listeningOnEndpointsMessage -f $PodeContext.Server.EndpointsInfo.Length, $PodeContext.Threads.General) -ForegroundColor $headerColor -Force:$Force

    # Write a horizontal divider line to the console.
    Write-PodeHostDivider -Force $true
    $disabled = ! (Test-PodeServerIsEnabled)
    # Display each endpoint with extracted protocol
    $PodeContext.Server.EndpointsInfo | ForEach-Object {
        # Extract protocol from the URL
        $protocol = ($_.Url -split ':')[0].ToUpper()

        # Determine protocol label
        $protocolLabel = switch ($protocol) {
            'HTTP' { 'HTTP      ' }
            'HTTPS' { 'HTTPS     ' }
            'WS' { 'WebSocket ' }
            'SMTP' { 'SMTP      ' }
            'SMTPS' { 'SMTPS      ' }
            'TCP' { 'TCP       ' }
            'TCPS' { 'TCPS      ' }
            default { 'UNKNOWN   ' }
        }

        # Handle flags like DualMode
        $flags = @()
        if ($_.DualMode) {
            $flags += 'DualMode'
        }

        if ($disabled -and ('HTTP', 'HTTPS' -contains $protocol)) {
            $flags += 'Disabled'
        }
        $flagString = if ($flags.Length -gt 0) { "[$($flags -join ',')]" } else { [string]::Empty }

        # Display endpoint details
        Write-PodeHost "   - $protocolLabel : $($_.Url) `t$flagString" -ForegroundColor $endpointsColor -Force:$Force
    }

    # Footer
    Write-PodeHost

    # Write a horizontal divider line to the console.
    Write-PodeHostDivider -Force $true
}



<#
.SYNOPSIS
    Displays OpenAPI endpoint information for each definition in Pode.

.DESCRIPTION
    The `Show-PodeConsoleOAInfo` function iterates through the OpenAPI definitions
    configured in the Pode server and displays their associated specification and
    documentation endpoints in the console. The information includes protocol, address,
    and paths for specification and documentation endpoints.

.PARAMETER Force
    Overrides the -Quiet flag of the server.

.EXAMPLE
    Show-PodeConsoleOAInfo

    This command will output the OpenAPI information for all definitions currently
    configured in the Pode server, including specification and documentation URLs.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Show-PodeConsoleOAInfo {
    param(
        [switch]
        $Force
    )

    # Default header initialization
    $openAPIHeader = $false

    # Fallback colors

    $headerColor = if ($null -ne $PodeContext.Server.Console.Colors.OpenApiHeaders) {
        $PodeContext.Server.Console.Colors.OpenApiHeaders
    }
    else {
        [System.ConsoleColor]::Yellow
    }

    $titleColor = if ($null -ne $PodeContext.Server.Console.Colors.OpenApiTitles) {
        $PodeContext.Server.Console.Colors.OpenApiTitles
    }
    else {
        [System.ConsoleColor]::White
    }

    $subtitleColor = if ($null -ne $PodeContext.Server.Console.Colors.OpenApiSubtitles) {
        $PodeContext.Server.Console.Colors.OpenApiSubtitles
    }
    else {
        [System.ConsoleColor]::Yellow
    }

    $urlColor = if ($null -ne $PodeContext.Server.Console.Colors.OpenApiUrls) {
        $PodeContext.Server.Console.Colors.OpenApiUrls
    }
    else {
        [System.ConsoleColor]::Cyan
    }

    # Iterate through OpenAPI definitions
    foreach ($key in $PodeContext.Server.OpenAPI.Definitions.Keys) {
        $bookmarks = $PodeContext.Server.OpenAPI.Definitions[$key].hiddenComponents.bookmarks
        if (!$bookmarks) {
            continue
        }

        # Print the header only once
        # Write-PodeHost -Force:$Force
        if (!$openAPIHeader) {
            Write-PodeHost $PodeLocale.openApiInfoMessage -ForegroundColor $headerColor -Force:$Force

            # Write a horizontal divider line to the console.
            Write-PodeHostDivider -Force $true

            $openAPIHeader = $true
        }

        # Print definition title
        Write-PodeHost " '$key':" -ForegroundColor $titleColor -Force:$Force

        # Determine endpoints for specification and documentation
        if ($bookmarks.route.count -gt 1 -or $bookmarks.route.Endpoint.Name) {
            # Directly use $bookmarks.route.Endpoint
            Write-PodeHost "   $($PodeLocale.specificationMessage):" -ForegroundColor $subtitleColor -Force:$Force
            foreach ($endpoint in $bookmarks.route.Endpoint) {
                Write-PodeHost "     . $($endpoint.Protocol)://$($endpoint.Address)$($bookmarks.openApiUrl)" -ForegroundColor $urlColor -Force:$Force
            }
            Write-PodeHost "   $($PodeLocale.documentationMessage):" -ForegroundColor $subtitleColor -Force:$Force
            foreach ($endpoint in $bookmarks.route.Endpoint) {
                Write-PodeHost "     . $($endpoint.Protocol)://$($endpoint.Address)$($bookmarks.path)" -ForegroundColor $urlColor -Force:$Force
            }
        }
        else {
            # Use EndpointsInfo for fallback
            Write-PodeHost "   $($PodeLocale.specificationMessage):" -ForegroundColor $subtitleColor -Force:$Force
            $PodeContext.Server.EndpointsInfo | ForEach-Object {
                if ($_.Pool -eq 'web') {
                    $url = [System.Uri]::new([System.Uri]::new($_.Url), $bookmarks.openApiUrl)
                    Write-PodeHost "     - $url" -ForegroundColor $urlColor -Force:$Force
                }
            }
            Write-PodeHost "   $($PodeLocale.documentationMessage):" -ForegroundColor $subtitleColor -Force:$Force
            $PodeContext.Server.EndpointsInfo | ForEach-Object {
                if ($_.Pool -eq 'web') {
                    $url = [System.Uri]::new([System.Uri]::new($_.Url), $bookmarks.path)
                    Write-PodeHost "     - $url" -ForegroundColor $urlColor -Force:$Force
                }
            }
        }
    }
    if ($openAPIHeader) {
        # Footer

        # Write a horizontal divider line to the console.
        Write-PodeHostDivider -Force $true
    }
}
