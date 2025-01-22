
<#
.SYNOPSIS
    Displays key information about the Pode server on the console.

.DESCRIPTION
    The Show-PodeConsoleInfo function provides detailed information about the current Pode server instance,
    including version, process ID (PID), server state, active endpoints, and OpenAPI definitions.
    The function supports clearing the console before displaying the details and can conditionally show additional
    server control commands depending on the server state and configuration.

.PARAMETER ClearHost
    Clears the console screen before displaying server information.

.PARAMETER Force
    Overrides the console's quiet mode to display the server information.

.PARAMETER ShowTopSeparator
    Adds a horizontal divider line at the top of the console output.

.NOTES
    This is an internal function and may change in future releases of Pode.
    It is intended for displaying real-time server information during runtime.
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

    # Exit the function if PodeContext is not initialized
    # or if the console is in quiet mode and the Force switch is not used
    if (!$PodeContext -or ($PodeContext.Server.Console.Quiet -and !$Force)) {
        return
    }

    # Retrieve the current server state and optionally include a timestamp.
    $serverState = Get-PodeServerState

    # Determine status and additional display options based on the server state.
    if ($serverState -eq [Pode.PodeServerState]::Suspended) {
        $status = $Podelocale.suspendedMessage
        $statusColor = [System.ConsoleColor]::Yellow
        $showHelp = (!$PodeContext.Server.Console.DisableConsoleInput -and $PodeContext.Server.Console.ShowHelp)
        $noHeaderNewLine = $false
        $ctrlH = !$showHelp
        $footerSeparator = $false
        $topSeparator = $ShowTopSeparator.IsPresent
        $headerSeparator = $true
    }
    elseif ($serverState -eq [Pode.PodeServerState]::Suspending) {
        $status = $Podelocale.suspendingMessage
        $statusColor = [System.ConsoleColor]::Yellow
        $showHelp = $false
        $noHeaderNewLine = $false
        $ctrlH = $false
        $footerSeparator = $false
        $topSeparator = $false
        $headerSeparator = $false
    }
    elseif ($serverState -eq [Pode.PodeServerState]::Resuming) {
        $status = $Podelocale.resumingMessage
        $statusColor = [System.ConsoleColor]::Yellow
        $showHelp = $false
        $noHeaderNewLine = $false
        $ctrlH = $false
        $footerSeparator = $false
        $topSeparator = $false
        $headerSeparator = $false
    }
    elseif ($serverState -eq [Pode.PodeServerState]::Restarting) {
        $status = $Podelocale.restartingMessage
        $statusColor = [System.ConsoleColor]::Yellow
        $showHelp = $false
        $noHeaderNewLine = $false
        $ctrlH = $false
        $footerSeparator = $false
        $topSeparator = $false
        $headerSeparator = $false
    }
    elseif ($serverState -eq [Pode.PodeServerState]::Starting) {
        $status = $Podelocale.startingMessage
        $statusColor = [System.ConsoleColor]::Yellow
        $showHelp = $false
        $noHeaderNewLine = $false
        $ctrlH = $false
        $footerSeparator = $false
        $topSeparator = $ShowTopSeparator.IsPresent
        $headerSeparator = $false
    }
    elseif ($serverState -eq [Pode.PodeServerState]::Running) {
        $status = $Podelocale.runningMessage
        $statusColor = [System.ConsoleColor]::Green
        $showHelp = (!$PodeContext.Server.Console.DisableConsoleInput -and $PodeContext.Server.Console.ShowHelp)
        $noHeaderNewLine = $false
        $ctrlH = !$showHelp
        $footerSeparator = $false
        $topSeparator = $ShowTopSeparator.IsPresent
        $headerSeparator = $true
    }
    elseif ($serverState -eq [Pode.PodeServerState]::Terminating) {
        $status = $Podelocale.terminatingMessage
        $statusColor = [System.ConsoleColor]::Red
        $showHelp = $false
        $noHeaderNewLine = $false
        $ctrlH = $false
        $footerSeparator = $false
        $topSeparator = $false
        $headerSeparator = $false
    }
    elseif ($serverState -eq [Pode.PodeServerState]::Terminated) {
        $status = $Podelocale.terminatedMessage
        $statusColor = [System.ConsoleColor]::Red
        $showHelp = $false
        $noHeaderNewLine = $false
        $ctrlH = $false
        $footerSeparator = $false
        $topSeparator = $ShowTopSeparator.IsPresent
        $headerSeparator = $true
    }

    if ($ClearHost -or $PodeContext.Server.Console.ClearHost) {
        Clear-Host
    }
    elseif ($topSeparator ) {
        # Write a horizontal divider line to the console.
        Write-PodeHostDivider -Force $true
    }

    # Write the header line with dynamic status color
    Write-PodeConsoleHeader -Status $Status -StatusColor $StatusColor -Force:$Force -NoNewLine:$noHeaderNewLine

    # Optionally display a horizontal divider after the header.
    if ($headerSeparator) {
        # Write a horizontal divider line to the console.
        Write-PodeHostDivider -Force $true
    }

    # Display endpoints and OpenAPI information if the server is running.
    if ($serverState -eq [Pode.PodeServerState]::Running) {
        if ($PodeContext.Server.Console.ShowEndpoints) {
            # state what endpoints are being listened on
            Show-PodeConsoleEndpointsInfo -Force:$Force
        }
        if ($PodeContext.Server.Console.ShowOpenAPI) {
            # state the OpenAPI endpoints for each definition
            Show-PodeConsoleOAInfo -Force:$Force
        }
    }

    # Show help commands if enabled or hide them conditionally.
    if ($showHelp) {
        Show-PodeConsoleHelp
    }

    elseif ($ctrlH ) {
        Show-PodeConsoleHelp -Hide
    }

    # Optionally display a footer separator.
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

.PARAMETER Force
    Overrides the -Quiet flag of the server.

.PARAMETER Divider
    Specifies the position of the divider: 'Header' or 'Footer'.
    Default is 'Footer'.

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
        $Hide,

        [switch]
        $Force,

        [string]
        [ValidateSet('Header', 'Footer')]
        $Divider = 'Footer'
    )
    # Retrieve centralized key mapping for keyboard shortcuts
    $KeyBindings = $PodeContext.Server.Console.KeyBindings

    # Define help section color variables
    $helpHeaderColor = $PodeContext.Server.Console.Colors.HelpHeader
    $helpKeyColor = $PodeContext.Server.Console.Colors.HelpKey
    $helpDescriptionColor = $PodeContext.Server.Console.Colors.HelpDescription
    $helpDividerColor = $PodeContext.Server.Console.Colors.HelpDivider

    # Add a header divider if specified
    if ($Divider -eq 'Header') {
        Write-PodeHostDivider -Force $Force
    }

    # Display the "Show Help" option if the $Hide parameter is specified
    if ($Hide) {
        Write-PodeKeyBinding -Key $KeyBindings.Help -ForegroundColor $helpKeyColor -Force:$Force
        # Message: 'Show Help'
        Write-PodeHost $Podelocale.showHelpMessage   -ForegroundColor $helpDescriptionColor -Force:$Force
    }
    else {
        # Determine the text for resuming or suspending the server based on its state

        $resumeOrSuspend = if ($serverState -eq 'Suspended') {
            $Podelocale.ResumeServerMessage
        }
        else {
            $Podelocale.SuspendServerMessage
        }

        # Determine whether to display "Enable" or "Disable Server" based on the server state
        $enableOrDisable = if (Test-PodeServerIsEnabled) { $Podelocale.disableHttpServerMessage } else { $Podelocale.enableHttpServerMessage }

        # Display the header for the help section
        Write-PodeHost $Podelocale.serverControlCommandsTitle -ForegroundColor $helpHeaderColor -Force:$Force

        if ($headerSeparator) {
            # Write a horizontal divider line to the console.
            Write-PodeHostDivider -Force $true
        }

        # Display key bindings and their descriptions
        if (!$PodeContext.Server.Console.DisableTermination) {
            Write-PodeKeyBinding -Key $KeyBindings.Terminate -ForegroundColor $helpKeyColor -Force:$Force
            Write-PodeHost "$($Podelocale.GracefullyTerminateMessage)" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        if ($PodeContext.Server.AllowedActions.Restart) {
            Write-PodeKeyBinding -Key $KeyBindings.Restart -ForegroundColor $helpKeyColor -Force:$Force
            Write-PodeHost "$($Podelocale.RestartServerMessage)" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        if ($PodeContext.Server.AllowedActions.Suspend) {
            Write-PodeKeyBinding -Key $KeyBindings.Suspend -ForegroundColor $helpKeyColor -Force:$Force
            Write-PodeHost "$resumeOrSuspend" -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        if (($serverState -eq 'Running') -and $PodeContext.Server.AllowedActions.Disable) {
            Write-PodeKeyBinding -Key $KeyBindings.Disable -ForegroundColor $helpKeyColor -Force:$Force
            # Message: 'Enable HTTP Server' or 'Disable HTTP Server'
            Write-PodeHost $enableOrDisable -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        Write-PodeKeyBinding -Key $KeyBindings.Help -ForegroundColor $helpKeyColor -Force:$Force
        # Message: 'Hide Help'
        Write-PodeHost $Podelocale.hideHelpMessage -ForegroundColor $helpDescriptionColor -Force:$Force

        # If an HTTP endpoint exists and the server is running, display the browser shortcut
        if ((Get-PodeEndpointUrl) -and ($serverState -ne 'Suspended')) {
            Write-PodeKeyBinding -Key $KeyBindings.Browser -ForegroundColor $helpKeyColor -Force:$Force
            # Message: Open the default HTTP endpoint in the default browser.
            Write-PodeHost $Podelocale.OpenHttpEndpointMessage -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        # Display a divider for grouping commands
        Write-PodeHost ' ----' -ForegroundColor $helpDividerColor -Force:$Force

        # Show metrics only if the server is running or suspended
        if (('Running', 'Suspended') -contains $serverState ) {
            Write-PodeKeyBinding -Key $KeyBindings.Metrics -ForegroundColor $helpKeyColor -Force:$Force
            # Message: Show Metrics
            Write-PodeHost $Podelocale.showMetricsMessage -ForegroundColor $helpDescriptionColor -Force:$Force
        }

        # Show endpoints and OpenAPI only if the server is running
        if ($serverState -eq 'Running') {
            Write-PodeKeyBinding -Key $KeyBindings.Endpoints -ForegroundColor $helpKeyColor -Force:$Force
            if ($PodeContext.Server.Console.ShowEndpoints) {
                # Message: Hide Endpoints
                Write-PodeHost $Podelocale.hideEndpointsMessage -ForegroundColor $helpDescriptionColor -Force:$Force
            }
            else {
                # Message: Show Endpoints
                Write-PodeHost $Podelocale.showEndpointsMessage -ForegroundColor $helpDescriptionColor -Force:$Force
            }

            # Check if OpenAPI is enabled and display its toggle option
            if (Test-PodeOAEnabled) {
                Write-PodeKeyBinding -Key $KeyBindings.OpenAPI -ForegroundColor $helpKeyColor -Force:$Force
                if ($PodeContext.Server.Console.ShowOpenAPI) {
                    # Message: Hide OpenAPI
                    Write-PodeHost $Podelocale.hideOpenAPIMessage -ForegroundColor $helpDescriptionColor -Force:$Force
                }
                else {
                    # Message: Show OpenAPI
                    Write-PodeHost $Podelocale.showOpenAPIMessage -ForegroundColor $helpDescriptionColor -Force:$Force
                }
            }
        }

        # Display the Clear Console and Quiet Mode options
        Write-PodeKeyBinding -Key $KeyBindings.Clear -ForegroundColor $helpKeyColor -Force:$Force
        Write-PodeHost $Podelocale.clearConsoleMessage -ForegroundColor $helpDescriptionColor -Force:$Force

        Write-PodeKeyBinding -Key $KeyBindings.Quiet -ForegroundColor $helpKeyColor -Force:$Force
        if ($PodeContext.Server.Console.Quiet) {
            # Message: Disable Quiet Mode
            Write-PodeHost $Podelocale.disableQuietModeMessage   -ForegroundColor $helpDescriptionColor -Force:$Force
        }
        else {
            # Message: Enable Quiet Mode
            Write-PodeHost $Podelocale.enableQuietModeMessage  -ForegroundColor $helpDescriptionColor -Force:$Force
        }

    }

    # Add a footer divider if specified
    if ($Divider -eq 'Footer') {
        Write-PodeHostDivider -Force $Force
    }
}

<#
.SYNOPSIS
    Writes a formatted key binding with "Ctrl+" prefix to the console.

.DESCRIPTION
    The `Write-PodeKeyBinding` function formats and displays a key binding in the console.
    For digit keys (e.g., `D1`, `D2`), it removes the `D` prefix for better readability,
    displaying them as `Ctrl+1`, `Ctrl+2`, etc. Other keys (e.g., `B`, `R`) are displayed as-is.
    The output is colorized based on the provided foreground color.

.PARAMETER Key
    The key binding to display, as a string. Examples include `D1` for the `1` key,
    or `B` for the `B` key.

.PARAMETER ForegroundColor
    The color to use for the key binding text in the console.

.PARAMETER Force
    Forces the console output to bypass any restrictions. This is useful for ensuring
    the output is always displayed regardless of console constraints.

.EXAMPLE
    Write-PodeKeyBinding -Key 'D1' -ForegroundColor Yellow -Force

    Writes: "Ctrl+1   : " to the console in yellow text.

.EXAMPLE
    Write-PodeKeyBinding -Key 'B' -ForegroundColor Green

    Writes: "Ctrl+B   : " to the console in green text.

.NOTES
    This function is specifically designed for Pode's internal console display system.
    It simplifies the formatting of key bindings for easier understanding by end users.
    Adjustments for non-standard keys can be added as needed.
#>
function Write-PodeKeyBinding {
    param (
        # The key binding to display (e.g., 'D1', 'B')
        [string]$Key,

        # The foreground color for the console text
        [System.ConsoleColor]
        $ForegroundColor,

        # Force writing to the console, even in restricted environments
        [switch]
        $Force
    )

    # Format the key binding:
    # - Remove the "D" prefix for digit keys (D0-D9), displaying them as "Ctrl+1" instead of "Ctrl+D1"
    # - Leave other keys (e.g., 'B', 'R') unchanged
    $k = if ($Key -like 'D[0-9]') {
        $Key.Substring(1)  # Extract the digit part of the key (e.g., '1' from 'D1')
    }
    else {
        $Key  # Use the key as-is for non-digit keys
    }
    # Write the formatted key binding to the console
    Write-PodeHost "$("Ctrl-$k".PadRight(8)): " -ForegroundColor $ForegroundColor -NoNewLine -Force:$Force
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

.PARAMETER Divider
    Specifies the position of the divider: 'Header' or 'Footer'.
    Default is 'Footer'.

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
        $Force,

        [string]
        [ValidateSet('Header', 'Footer')]
        $Divider = 'Footer'
    )

    # Set default colors if not explicitly defined in PodeContext
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

    if ($null -ne $PodeContext.Server.Console.Colors.EndpointsProtocol) {
        $protocolsColor = $PodeContext.Server.Console.Colors.EndpointsProtocol
    }
    else {
        $protocolsColor = [System.ConsoleColor]::White
    }

    if ($null -ne $PodeContext.Server.Console.Colors.EndpointsFlag) {
        $flagsColor = $PodeContext.Server.Console.Colors.EndpointsFlag
    }
    else {
        $flagsColor = [System.ConsoleColor]::Gray
    }

    if ($null -ne $PodeContext.Server.Console.Colors.EndpointsName) {
        $nameColor = $PodeContext.Server.Console.Colors.EndpointsName
    }
    else {
        $nameColor = [System.ConsoleColor]::Magenta
    }

    # Exit early if no endpoints are available to display
    if ($PodeContext.Server.EndpointsInfo.Length -eq 0) {
        return
    }

    # Add a header divider if specified
    if ($Divider -eq 'Header') {
        Write-PodeHostDivider -Force $Force
    }

    # Group endpoints by protocol (e.g., HTTP, HTTPS)
    $groupedEndpoints = $PodeContext.Server.EndpointsInfo | Group-Object {
        ($_.Url -split ':')[0].ToUpper()
    }

    # Calculate the maximum URL length for alignment of flags
    $maxUrlLength = ($PodeContext.Server.EndpointsInfo | ForEach-Object { $_.Url.Length }) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

    # Display header with the total number of endpoints and threads
    Write-PodeHost ($PodeLocale.listeningOnEndpointsMessage -f $PodeContext.Server.EndpointsInfo.Length, $PodeContext.Threads.General) -ForegroundColor $headerColor -Force:$Force

    # Write a divider line for visual separation
    Write-PodeHostDivider -Force $true

    # Determine if the server is disabled
    $disabled = ! (Test-PodeServerIsEnabled)

    # Loop through grouped endpoints by protocol
    foreach ($group in $groupedEndpoints) {
        # Define the protocol label with consistent spacing
        $protocolLabel = switch ($group.Name) {
            'HTTP' { 'HTTP  :' }
            'HTTPS' { 'HTTPS :' }
            'WS' { 'WS    :' }
            'WSS' { 'WSS   :' }
            'SMTP' { 'SMTP  :' }
            'SMTPS' { 'SMTPS :' }
            'TCP' { 'TCP   :' }
            'TCPS' { 'TCPS  :' }
            default { 'UNKNOWN' }
        }

        # Flag to control whether the protocol label is displayed
        $showGroupLabel = $true
        foreach ($item in $group.Group) {

            # Display the protocol label only for the first item in the group
            if ($showGroupLabel) {
                Write-PodeHost " - $protocolLabel" -ForegroundColor $protocolsColor -Force:$Force -NoNewLine
                $showGroupLabel = $false
            }
            else {
                Write-PodeHost '          ' -Force:$Force -NoNewLine
            }

            # Display the URL
            Write-PodeHost " $($item.Url)" -ForegroundColor $endpointsColor -Force:$Force -NoNewLine

            # Prepare flags for the endpoint
            $flags = @()

            # Add 'Disabled' flag if applicable
            if ($disabled -and ('HTTP', 'HTTPS' -contains $group.Name)) {
                $flags += 'Disabled'
            }

            # Add Name flag if it doesn't match a GUID
            if (![string]::IsNullOrEmpty($item.Name) -and ($item.Name -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) {
                $flags += "`b$($item.Name)"
            }

            # Add remaining flags
            if ($item.DualMode) { $flags += 'DualMode' }
            if ($item.Default) { $flags += 'Default' }

            # Display flags if any are present
            if ($flags.Count -gt 0) {
                # Calculate padding dynamically
                $urlPadding = $maxUrlLength - $item.Url.Length + 4
                Write-PodeHost $(' ' * $urlPadding + '[') -ForegroundColor $flagsColor -Force:$Force -NoNewLine

                $index = 0
                foreach ($flag in $flags) {
                    switch ($flag) {
                        { $flag[0] -eq [char]8 } {
                            # Display Name flag
                            Write-PodeHost 'Name: ' -ForegroundColor $flagsColor -Force:$Force -NoNewLine
                            Write-PodeHost "$flag" -ForegroundColor $nameColor -Force:$Force -NoNewLine
                        }
                        'Disabled' {
                            # Display Disabled flag
                            Write-PodeHost 'Disabled' -ForegroundColor Yellow -Force:$Force -NoNewLine
                        }
                        default {
                            # Display other flags
                            Write-PodeHost "$flag" -ForegroundColor $flagsColor -Force:$Force -NoNewLine
                        }
                    }

                    # Append comma if not the last flag
                    if (++$index -lt $flags.Length) {
                        Write-PodeHost ', ' -ForegroundColor $flagsColor -Force:$Force -NoNewLine
                    }
                }

                # Close the flag block
                Write-PodeHost ']' -ForegroundColor $flagsColor -Force:$Force
            }
            else {
                # End line if no flags are present
                Write-PodeHost
            }
        }
    }

    # Add a footer divider if specified
    if ($Divider -eq 'Footer') {
        Write-PodeHostDivider -Force $Force
    }
}



<#
.SYNOPSIS
    Displays metrics for the Pode server in the console.

.DESCRIPTION
    This function outputs various server metrics, such as uptime and restart counts,
    to the Pode console with styled colors based on the Pode context. The function
    ensures a visually clear representation of the metrics for quick monitoring.

.EXAMPLE
    Show-PodeConsoleMetric

    This command displays the Pode server metrics in the console with the
    appropriate headers, labels, and values styled using Pode-defined colors.

.NOTES
    This function depends on the PodeContext and related server configurations
    for retrieving metrics and console colors. Ensure that Pode is running and
    configured correctly.

.OUTPUTS
    None. This function writes output directly to the console.

#>
function Show-PodeConsoleMetric {
    # Determine the color for the labels
    $headerColor = $PodeContext.Server.Console.Colors.MetricsHeader
    $labelColor = $PodeContext.Server.Console.Colors.MetricsLabel
    $valueColor = $PodeContext.Server.Console.Colors.MetricsValue

    # Write a horizontal divider line to separate the header
    Write-PodeHostDivider -Force $true

    # Write the metrics header with the current timestamp
    Write-PodeHost "$($Podelocale.serverMetricsMessage) [$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')]" -ForegroundColor $headerColor

    # Write another horizontal divider line for separation
    Write-PodeHostDivider -Force $true

    # Display the total uptime
    Write-PodeHost "$($Podelocale.totalUptimeMessage) " -ForegroundColor $labelColor -NoNewLine
    Write-PodeHost (Get-PodeServerUptime  -Format Verbose -Total -ExcludeMilliseconds) -ForegroundColor $valueColor

    # If the server restarted, display uptime since last restart
    if ((Get-PodeServerRestartCount) -gt 0) {
        Write-PodeHost "$($Podelocale.uptimeSinceLastRestartMessage) "-ForegroundColor $labelColor -NoNewLine
        Write-PodeHost (Get-PodeServerUptime -Format Verbose -ExcludeMilliseconds) -ForegroundColor $valueColor
    }

    # Display the total number of server restarts
    Write-PodeHost "$($Podelocale.totalRestartMessage) " -ForegroundColor $labelColor -NoNewLine
    Write-PodeHost (Get-PodeServerRestartCount) -ForegroundColor $valueColor

    Write-PodeHost 'Requests' -ForegroundColor $labelColor
    Write-PodeHost '  Total       : ' -ForegroundColor $labelColor -NoNewLine
    Write-PodeHost (Get-PodeServerActiveRequestMetric -CountType Total) -ForegroundColor $valueColor
    Write-PodeHost '  Queued      : ' -ForegroundColor $labelColor -NoNewLine
    Write-PodeHost (Get-PodeServerActiveRequestMetric -CountType Queued) -ForegroundColor $valueColor
    Write-PodeHost '  Processing  : ' -ForegroundColor $labelColor -NoNewLine
    Write-PodeHost (Get-PodeServerActiveRequestMetric -CountType Processing) -ForegroundColor $valueColor

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

.PARAMETER Divider
    Specifies the position of the divider: 'Header' or 'Footer'.
    Default is 'Footer'.

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
        $Force,

        [string]
        [ValidateSet('Header', 'Footer')]
        $Divider = 'Footer'
    )


    # Default header initialization
    $openAPIHeader = $false

    # Determine the color for the labels
    $headerColor = $PodeContext.Server.Console.Colors.OpenApiHeaders
    $titleColor = $PodeContext.Server.Console.Colors.OpenApiTitles
    $subtitleColor = $PodeContext.Server.Console.Colors.OpenApiSubtitles
    $urlColor = $PodeContext.Server.Console.Colors.OpenApiUrls



    # Iterate through OpenAPI definitions
    foreach ($key in $PodeContext.Server.OpenAPI.Definitions.Keys) {
        $bookmarks = $PodeContext.Server.OpenAPI.Definitions[$key].hiddenComponents.bookmarks
        if (!$bookmarks) {
            continue
        }

        # Print the header only once
        # Write-PodeHost -Force:$Force
        if (!$openAPIHeader) {

            # Add a header divider if specified
            if ($Divider -eq 'Header') {
                Write-PodeHostDivider -Force $Force
            }

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
    # Add a footer divider if specified and OpenAPI is defined
    if ($openAPIHeader -and ($Divider -eq 'Footer')) {
        # Write a horizontal divider line to the console.
        Write-PodeHostDivider -Force $true
    }
}

<#
.SYNOPSIS
    Clears any remaining keys in the console input buffer.

.DESCRIPTION
    The `Clear-PodeKeyPressed` function checks if there are any keys remaining in the input buffer
    and discards them, ensuring that no leftover key presses interfere with subsequent reads.

.EXAMPLE
    Clear-PodeKeyPressed
    [Console]::ReadKey($true)

    This example clears the buffer and then reads a new key without interference.

.NOTES
    This function is useful when using `[Console]::ReadKey($true)` to prevent previous key presses
    from affecting the input.

#>
function Clear-PodeKeyPressed {
    # Clear any remaining keys in the input buffer
    while (![Console]::IsInputRedirected -and [Console]::KeyAvailable) {
        $null = [Console]::ReadKey($true)
    }
}

<#
.SYNOPSIS
	Tests if a specific key combination is pressed in the Pode console.

.DESCRIPTION
	This function checks if a key press matches a specified character and modifier combination. It supports detecting Control key presses on all platforms and Shift key presses on Unix systems.

.PARAMETER Key
	Optional. Specifies the key to test. If not provided, the function retrieves the key using `Get-PodeConsoleKey`.

.PARAMETER Character
	Mandatory. Specifies the character to test against the key press.

.EXAMPLE
	Test-PodeKeyPressed -Character 'C'

	Checks if the Control+C combination is pressed.

.NOTES
	This function is intended for use in scenarios where Pode's console input is enabled.
#>
function Test-PodeKeyPressed {
    param(
        [Parameter()]
        $Key = $null,

        [Parameter(Mandatory = $true)]
        [System.ConsoleKey]
        $Character
    )

    # If console input is disabled, return false
    if (($null -eq $Key) -or $PodeContext.Server.Console.DisableConsoleInput) {
        return $false
    }

    # Test the key press against the character and modifiers
    return (($null -ne $Key) -and ($Key.Key -ieq $Character) -and
        (($Key.Modifiers -band [ConsoleModifiers]::Control) -or ((Test-PodeIsUnix) -and ($Key.Modifiers -band [ConsoleModifiers]::Shift))))
}

<#
.SYNOPSIS
	Gets the next key press from the Pode console.

.DESCRIPTION
	This function checks if a key is available in the console input buffer and retrieves it. If the console input is redirected or no key is available, the function returns `$null`.

.EXAMPLE
	Get-PodeConsoleKey

	Retrieves the next key press from the Pode console input buffer.

.NOTES
	This function is useful for scenarios requiring real-time console key handling.
#>
function Get-PodeConsoleKey {
    try {
        if ([Console]::IsInputRedirected -or ![Console]::KeyAvailable) {
            return $null
        }

        return [Console]::ReadKey($true)
    }
    finally {
        Clear-PodeKeyPressed
    }
}

<#
.SYNOPSIS
    Processes console actions and cancellation token triggers for the Pode server using a centralized key mapping.

.DESCRIPTION
    The `Invoke-PodeConsoleAction` function uses a hashtable to define and centralize key mappings,
    allowing for easier updates and a cleaner implementation.

.PARAMETER serverState
    The current state of the Pode server, retrieved using Get-PodeServerState,
    which determines whether actions like suspend, disable, or restart can be executed.

.NOTES
    This function is part of Pode's internal utilities and may change in future releases.

.EXAMPLE
    Invoke-PodeConsoleAction

    Processes the next key press or cancellation token to execute the corresponding server action.
#>
function Invoke-PodeConsoleAction {
    param(
        [Parameter(Mandatory = $true)]
        [Pode.PodeServerState]
        $ServerState
    )
    # Get the next key press if console input is enabled
    $Key = Get-PodeConsoleKey
    if ($null -ne $key) {
        if ($key.Modifiers -ne 'Control') {
            return
        }
        else {
            Write-Verbose "The Console received CTRL+$($key.Key)"
        }
    }

    # Centralized key mapping
    $KeyBindings = $PodeContext.Server.Console.KeyBindings

    # Browser action
    if (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Browser) {
        # Open the browser
        Show-PodeConsoleEndpointUrl
    }
    # Toggle help display
    elseif (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Help) {
        $PodeContext.Server.Console.ShowHelp = !$PodeContext.Server.Console.ShowHelp
        if ($PodeContext.Server.Console.ShowHelp) {
            Show-PodeConsoleHelp -Divider Footer
        }
        else {
            Show-PodeConsoleInfo -ShowTopSeparator
        }
    }
    # Toggle OpenAPI display
    elseif (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.OpenAPI) {
        $PodeContext.Server.Console.ShowOpenAPI = !$PodeContext.Server.Console.ShowOpenAPI

        if ($PodeContext.Server.Console.ShowOpenAPI) {
            if (Test-PodeServerState -State Running) {
                if ($PodeContext.Server.Console.ShowOpenAPI) {
                    # state what endpoints are being listened on
                    Show-PodeConsoleOAInfo -Force:$Force -Divider Footer
                }
            }
        }
        else {
            Show-PodeConsoleInfo -ShowTopSeparator
        }
    }
    # Toggle endpoints display
    elseif (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Endpoints) {
        $PodeContext.Server.Console.ShowEndpoints = !$PodeContext.Server.Console.ShowEndpoints
        if ($PodeContext.Server.Console.ShowEndpoints) {
            if (Test-PodeServerState -State Running) {
                if ($PodeContext.Server.Console.ShowEndpoints) {
                    # state what endpoints are being listened on
                    Show-PodeConsoleEndpointsInfo -Force:$Force -Divider Footer
                }
            }
        }
        else {
            Show-PodeConsoleInfo -ShowTopSeparator
        }
    }
    # Clear console
    elseif (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Clear) {
        Show-PodeConsoleInfo -ClearHost
    }
    # Toggle quiet mode
    elseif (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Quiet) {
        $PodeContext.Server.Console.Quiet = !$PodeContext.Server.Console.Quiet
        Show-PodeConsoleInfo -ClearHost -Force
    }
    # Show metrics
    elseif ((([Pode.PodeServerState]::Running, [Pode.PodeServerState]::Suspended) -contains $serverState ) -and (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Metrics)) {
        Show-PodeConsoleMetric
    }

    # Handle restart actions
    if ($PodeContext.Server.AllowedActions.Restart) {
        if (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Restart) {
            Close-PodeCancellationTokenRequest -Type Restart
            Restart-PodeInternalServer
        }
        elseif (Test-PodeCancellationTokenRequest -Type Restart) {
            Restart-PodeInternalServer
        }
    }
    if (! $PodeContext.Server.Console.DisableTermination) {
        # Terminate server
        if ( (Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Terminate)) {
            Close-PodeCancellationTokenRequest -Type Terminate
            return
        }
        elseif ((Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Disable)) {
            # Handle enable/disable server actions
            if ($PodeContext.Server.AllowedActions.Disable -and ($serverState -eq [Pode.PodeServerState]::Running)) {
                if (Test-PodeServerIsEnabled) {
                    Close-PodeCancellationTokenRequest -Type Disable
                }
                else {
                    Reset-PodeCancellationToken -Type Disable
                }

                Write-PodeConsoleHeader -DisableHttp

            }
        }
        elseif ((Test-PodeKeyPressed -Key $Key -Character $KeyBindings.Suspend)) {
            # Handle suspend/resume actions
            if ($PodeContext.Server.AllowedActions.Suspend) {
                if ($serverState -eq [Pode.PodeServerState]::Suspended) {
                    Set-PodeResumeToken
                }
                elseif ($serverState -eq [Pode.PodeServerState]::Running) {
                    Set-PodeSuspendToken
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Retrieves the default console settings for Pode.

.DESCRIPTION
    The `Get-PodeDefaultConsole` function returns a hashtable containing the default console configuration for Pode. This includes settings for termination, console input, output formatting, timestamps, and color themes, as well as key bindings for console navigation.

.OUTPUTS
    [hashtable]
        A hashtable representing the default console settings, including termination behavior, display options, colors, and key bindings.

.EXAMPLE
    $consoleSettings = Get-PodeDefaultConsole
    Write-Output $consoleSettings

    This example retrieves the default console settings and displays them.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeDefaultConsole {
    # Refer to https://learn.microsoft.com/en-us/dotnet/api/system.consolekey?view=net-9.0 for ConsoleKey Enum
    if ($Host.Name -eq 'Visual Studio Code Host' ) {
        $KeyBindings = @{        # Define custom key bindings for controls.
            Browser   = [System.ConsoleKey]::B            # Open the default browser.
            Help      = [System.ConsoleKey]::F2           # Show/hide help instructions.
            OpenAPI   = [System.ConsoleKey]::F3            # Show/hide OpenAPI information.
            Endpoints = [System.ConsoleKey]::F4            # Show/hide endpoints.
            Clear     = [System.ConsoleKey]::L            # Clear the console output.
            Quiet     = [System.ConsoleKey]::F12           # Toggle quiet mode.
            Terminate = [System.ConsoleKey]::C            # Terminate the server.
            Restart   = [System.ConsoleKey]::F6            # Restart the server.
            Disable   = [System.ConsoleKey]::F7            # Disable the server.
            Suspend   = [System.ConsoleKey]::F9          # Suspend the server.
            Metrics   = [System.ConsoleKey]::F10            # Show Metrics.
        }
    }
    else {
        $KeyBindings = @{        # Define custom key bindings for controls.
            Browser   = [System.ConsoleKey]::B            # Open the default browser.
            Help      = [System.ConsoleKey]::H            # Show/hide help instructions.
            OpenAPI   = [System.ConsoleKey]::O            # Show/hide OpenAPI information.
            Endpoints = [System.ConsoleKey]::E            # Show/hide endpoints.
            Clear     = [System.ConsoleKey]::L            # Clear the console output.
            Quiet     = [System.ConsoleKey]::Q            # Toggle quiet mode.
            Terminate = [System.ConsoleKey]::C            # Terminate the server.
            Restart   = [System.ConsoleKey]::R            # Restart the server.
            Disable   = [System.ConsoleKey]::D            # Disable the server.
            Suspend   = [System.ConsoleKey]::P            # Suspend the server.
            Metrics   = [System.ConsoleKey]::M            # Show Metrics.
        }
    }
    return @{
        DisableTermination  = $false    # Prevent Ctrl+C from terminating the server.
        DisableConsoleInput = $false    # Disable all console input controls.
        Quiet               = $false    # Suppress console output.
        ClearHost           = $false    # Clear the console output at startup.
        ShowOpenAPI         = $true     # Display OpenAPI information.
        ShowEndpoints       = $true     # Display listening endpoints.
        ShowHelp            = $false    # Show help instructions in the console.
        ShowDivider         = $true     # Display dividers between sections.
        DividerLength       = 75        # Length of dividers in the console.
        ShowTimeStamp       = $true     # Display timestamp in the header.

        Colors              = @{            # Customize console colors.
            Header            = [System.ConsoleColor]::White      # The server's header section, including the Pode version and timestamp.
            EndpointsHeader   = [System.ConsoleColor]::Yellow     # The header for the endpoints list.
            Endpoints         = [System.ConsoleColor]::Cyan       # The endpoints URLs.
            EndpointsProtocol = [System.ConsoleColor]::White     # The endpoints protocol.
            EndpointsFlag     = [System.ConsoleColor]::Gray     # The endpoints flags.
            EndpointsName     = [System.ConsoleColor]::Magenta     # The endpoints Name.
            OpenApiUrls       = [System.ConsoleColor]::Cyan       # URLs listed under the OpenAPI information section.
            OpenApiHeaders    = [System.ConsoleColor]::Yellow     # Section headers for OpenAPI information.
            OpenApiTitles     = [System.ConsoleColor]::White      # The OpenAPI "default" title.
            OpenApiSubtitles  = [System.ConsoleColor]::Yellow     # Subtitles under OpenAPI (e.g., Specification, Documentation).
            HelpHeader        = [System.ConsoleColor]::Yellow     # Header for the Help section.
            HelpKey           = [System.ConsoleColor]::Green      # Key bindings listed in the Help section (e.g., Ctrl+c).
            HelpDescription   = [System.ConsoleColor]::White      # Descriptions for each Help section key binding.
            HelpDivider       = [System.ConsoleColor]::Gray       # Dividers used in the Help section.
            Divider           = [System.ConsoleColor]::DarkGray   # Dividers between console sections.
            MetricsHeader     = [System.ConsoleColor]::Yellow     # Header for the Metric section.
            MetricsLabel      = [System.ConsoleColor]::White      # Labels for values displayed in the Metrics section.
            MetricsValue      = [System.ConsoleColor]::Green      # The actual values displayed in the Metrics section.
        }
        KeyBindings         = $KeyBindings
    }

}


<#
.SYNOPSIS
    Writes a formatted header to the Pode console with server details and status.

.DESCRIPTION
    The Write-PodeConsoleHeader function writes a customizable header line to the Pode console.
    The header includes server details such as version, process ID (PID), and current status,
    along with optional HTTP status information. It dynamically adjusts its output based on
    the provided parameters and Pode context settings, including timestamp and colors.

.PARAMETER Status
    The status message to display in the header (e.g., Running, Suspended).

.PARAMETER StatusColor
    The color to use for the status message in the console.

.PARAMETER NoNewLine
    Prevents the addition of a newline after the header output.

.PARAMETER Force
    Forces the header to be written even if console restrictions are active.

.PARAMETER DisableHttp
    Displays HTTP status in the header, indicating whether HTTP is enabled or disabled.

.NOTES
    This is an internal function and may change in future releases of Pode.
    It is used to format and display the header for the Pode server in the console.
#>
function Write-PodeConsoleHeader {
    [CmdletBinding(DefaultParameterSetName = 'Status')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Status')]
        [string] $Status,

        [Parameter(Mandatory = $true, ParameterSetName = 'Status')]
        [System.ConsoleColor] $StatusColor,

        [switch] $NoNewLine,

        [switch] $Force,

        [Parameter(Mandatory = $true, ParameterSetName = 'DisableHttp')]
        [switch] $DisableHttp
    )

    # Get the configured header color from Pode context.
    $headerColor = $PodeContext.Server.Console.Colors.Header

    # If DisableHttp is set, override the Status and StatusColor parameters.
    if ($DisableHttp) {
        $Status = $Podelocale.runningMessage
        $StatusColor = [System.ConsoleColor]::Green
    }

    # Generate a timestamp if enabled in the Pode context.
    $timestamp = if ($PodeContext.Server.Console.ShowTimeStamp) {
        "[$([datetime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))]"
    }
    else {
        ''
    }

    # Write the header with timestamp, Pode version, and status.
    Write-PodeHost "`r$timestamp Pode $(Get-PodeVersion) (PID: $($PID)) [" -ForegroundColor $headerColor -Force:$Force -NoNewLine
    Write-PodeHost "$Status" -ForegroundColor $StatusColor -Force:$Force -NoNewLine

    if ($DisableHttp) {
        # Append HTTP status to the header if DisableHttp is enabled.
        Write-PodeHost '] - HTTP ' -ForegroundColor $headerColor -Force:$Force -NoNewLine
        if (Test-PodeCancellationTokenRequest -Type Disable) {
            Write-PodeHost 'Disabled' -ForegroundColor Yellow
        }
        else {
            Write-PodeHost 'Enabled' -ForegroundColor Green
        }
    }
    else {
        # Close the header without HTTP status.
        Write-PodeHost ']    ' -ForegroundColor $headerColor -Force:$Force -NoNewLine:$NoNewLine
    }
}

<#
.SYNOPSIS
    Sets override configurations for the Pode server console.

.DESCRIPTION
    This function updates the Pode server's console configuration by applying override settings based on the specified parameters. These configurations include disabling termination, console input, enabling quiet mode, and more.

.PARAMETER DisableTermination
    Sets an override to disable termination of the Pode server from the console.

.PARAMETER DisableConsoleInput
    Sets an override to disable input from the console for the Pode server.

.PARAMETER Quiet
    Sets an override to enable quiet mode, suppressing console output.

.PARAMETER ClearHost
    Sets an override to clear the host on startup.

.PARAMETER HideOpenAPI
    Sets an override to hide the OpenAPI documentation display.

.PARAMETER HideEndpoints
    Sets an override to hide the endpoints list display.

.PARAMETER ShowHelp
    Sets an override to show help information in the console.

.PARAMETER Daemon
    Sets an override to enable daemon mode, which combines quiet mode, disabled console input, and disabled termination.

.NOTES
    This function is used to dynamically apply override settings for the Pode server console configuration.
#>
function Set-PodeConsoleOverrideConfiguration {
    param (
        [switch]
        $DisableTermination,

        [switch]
        $DisableConsoleInput,

        [switch]
        $Quiet,

        [switch]
        $ClearHost,

        [switch]
        $HideOpenAPI,

        [switch]
        $HideEndpoints,

        [switch]
        $ShowHelp,

        [switch]
        $Daemon
    )

    # Apply override settings
    if ($DisableTermination.IsPresent) {
        $PodeContext.Server.Console.DisableTermination = $true
    }
    if ($DisableConsoleInput.IsPresent) {
        $PodeContext.Server.Console.DisableConsoleInput = $true
    }
    if ($Quiet.IsPresent) {
        $PodeContext.Server.Console.Quiet = $true
    }
    if ($ClearHost.IsPresent) {
        $PodeContext.Server.Console.ClearHost = $true
    }
    if ($HideOpenAPI.IsPresent) {
        $PodeContext.Server.Console.ShowOpenAPI = $false
    }
    if ($HideEndpoints.IsPresent) {
        $PodeContext.Server.Console.ShowEndpoints = $false
    }
    if ($ShowHelp.IsPresent) {
        $PodeContext.Server.Console.ShowHelp = $true
    }
    if ($Daemon.IsPresent) {
        $PodeContext.Server.Console.Quiet = $true
        $PodeContext.Server.Console.DisableConsoleInput = $true
        $PodeContext.Server.Console.DisableTermination = $true
    }

    # Apply IIS-specific overrides
    if ($PodeContext.Server.IsIIS) {
        $PodeContext.Server.Console.DisableTermination = $true
        $PodeContext.Server.Console.DisableConsoleInput = $true

        # If running under Azure Web App, enforce quiet mode
        if (!(Test-PodeIsEmpty $env:WEBSITE_IIS_SITE_NAME)) {
            $PodeContext.Server.Console.Quiet = $true
        }
    }
}


<#
.SYNOPSIS
    Launches the Pode endpoint URL in the default browser.

.DESCRIPTION
    This function retrieves the URL of the Pode endpoint using Get-PodeEndpointUrl. If the URL is valid
    and not null or whitespace, it triggers a browser event using Invoke-PodeEvent and opens the
    URL in the system's default web browser using Start-Process.

.EXAMPLE
    Show-PodeConsoleEndpointUrl
    This example retrieves the Pode endpoint URL and opens it in the default browser if available.

.NOTES
    Ensure the Pode endpoint is correctly set up and running. This function relies on the Pode framework.
#>

function Show-PodeConsoleEndpointUrl {
    $url = Get-PodeEndpointUrl
    if (![string]::IsNullOrWhitespace($url)) {
        Invoke-PodeEvent -Type Browser
        Start-Process $url
    }
}

<#
.SYNOPSIS
    Checks if the current PowerShell session supports console-like features.

.DESCRIPTION
    This function determines if the current PowerShell session is running in a host
    that typically indicates a console-like environment where `Ctrl+C` can interrupt.
    On Windows, it validates the standard input and output handles.
    On non-Windows systems, it checks against known supported hosts.

.OUTPUTS
    [bool]
    Returns `$true` if running in a console-like environment, `$false` otherwise.

.EXAMPLE
    Test-PodeHasConsole
    # Returns `$true` if the session supports console-like behavior.
#>
function Test-PodeHasConsole {

    if (Test-PodeIsISEHost) {
        return $true
    }

    if (@('ConsoleHost', 'Visual Studio Code Host') -contains $Host.Name) {

        if (Test-PodeIsWindows) {
            $handleTypeMap = @{
                Input  = -10
                Output = -11
                Error  = -12
            }
            # On Windows, validate standard input and output handles
            return ([Pode.NativeMethods]::IsHandleValid($handleTypeMap.Input) -and `
                    [Pode.NativeMethods]::IsHandleValid($handleTypeMap.Output) -and `
                    [Pode.NativeMethods]::IsHandleValid($handleTypeMap.Error)
            )
        }
        # On Linux or Mac
        $handleTypeMap = @{
            Input  = 0
            Output = 1
            Error  = 2
        }
        return ([Pode.NativeMethods]::IsTerminal($handleTypeMap.Input) -and `
                [Pode.NativeMethods]::IsTerminal($handleTypeMap.Output) -and `
                [Pode.NativeMethods]::IsTerminal($handleTypeMap.Error)
        )  
    }
    return $false
}

<#
.SYNOPSIS
    Determines if the current PowerShell session is running in the ConsoleHost.

.DESCRIPTION
    This function checks if the session's host name matches 'ConsoleHost',
    which typically represents a native terminal environment in PowerShell.

.OUTPUTS
    [bool]
    Returns `$true` if the current host is 'ConsoleHost', otherwise `$false`.

.EXAMPLE
    Test-PodeIsConsoleHost
    # Returns `$true` if running in ConsoleHost, `$false` otherwise.
#>
function Test-PodeIsConsoleHost {
    return $Host.Name -eq 'ConsoleHost'
}