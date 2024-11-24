<#
.SYNOPSIS
    Tests if the Pode service is enabled.

.DESCRIPTION
    This function checks if the Pode service is enabled by verifying if the `Service` key exists in the `$PodeContext.Server` hashtable.

.OUTPUTS
    [Bool] - `$true` if the 'Service' key exists, `$false` if it does not.

.EXAMPLE
    Test-PodeServiceEnabled

    Returns `$true` if the Pode service is enabled, otherwise returns `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeServiceEnabled {

    # Check if the 'Service' key exists in the $PodeContext.Server hashtable
    return $PodeContext.Server.ContainsKey('Service')
}

<#
.SYNOPSIS
    Starts the Pode Service Heartbeat using a named pipe for communication with a C# service.

.DESCRIPTION
    This function starts a named pipe server in PowerShell that listens for commands from a C# application. It supports two commands:
    - 'shutdown': to gracefully stop the Pode server.
    - 'restart': to restart the Pode server.

.PARAMETER None
    The function takes no parameters. It retrieves the pipe name from the Pode service context.

.EXAMPLE
    Start-PodeServiceHearthbeat

    This command starts the Pode service monitoring and waits for 'shutdown' or 'restart' commands from the named pipe.

.NOTES
    This is an internal function and may change in future releases of Pode.

    The function uses Pode's context for the service to manage the pipe server. The pipe listens for messages sent from a C# client
    and performs actions based on the received message.

    If the pipe receives a 'shutdown' message, the Pode server is stopped.
    If the pipe receives a 'restart' message, the Pode server is restarted.

    Global variable example:  $global:PodeService=@{DisableTermination=$true;Quiet=$false;Pipename='ssss'}
#>
function Start-PodeServiceHearthbeat {

    # Check if the Pode service is enabled
    if (Test-PodeServiceEnabled) {

        # Define the script block for the client receiver, listens for commands via the named pipe
        $scriptBlock = {
            $serviceState = 'running'
            while (!$PodeContext.Tokens.Cancellation.IsCancellationRequested) {

                Write-PodeHost -Message "Initialize Listener Pipe $($PodeContext.Server.Service.PipeName)" -Force
                Write-PodeHost -Message "Service State: $serviceState" -Force
                Write-PodeHost -Message "Total Uptime: $(Get-PodeServerUptime -Total -Readable -OutputType Verbose -ExcludeMilliseconds)" -Force
                Write-PodeHost -Message "Uptime Since Last Restart: $(Get-PodeServerUptime -Readable -OutputType Verbose -ExcludeMilliseconds)" -Force
                Write-PodeHost -Message "Total Number of Restart: $(Get-PodeServerRestartCount)" -Force
                try {
                    Start-Sleep -Milliseconds 100
                    # Create a named pipe server stream
                    $pipeStream = [System.IO.Pipes.NamedPipeServerStream]::new(
                        $PodeContext.Server.Service.PipeName,
                        [System.IO.Pipes.PipeDirection]::InOut,
                        1, # Max number of allowed concurrent connections
                        [System.IO.Pipes.PipeTransmissionMode]::Byte,
                        [System.IO.Pipes.PipeOptions]::None
                    )

                    Write-PodeHost -Message "Waiting for connection to the $($PodeContext.Server.Service.PipeName) pipe." -Force
                    $pipeStream.WaitForConnection()  # Wait until a client connects
                    Write-PodeHost -Message "Connected to the $($PodeContext.Server.Service.PipeName) pipe." -Force

                    # Create a StreamReader to read incoming messages from the pipe
                    $reader = [System.IO.StreamReader]::new($pipeStream)

                    # Process incoming messages in a loop as long as the pipe is connected
                    while ($pipeStream.IsConnected) {
                        $message = $reader.ReadLine()  # Read message from the pipe
                        if ( $PodeContext.Tokens.Cancellation.IsCancellationRequested) {
                            return
                        }

                        if ($message) {
                            Write-PodeHost -Message "Received message: $message" -Force

                            switch ($message) {
                                'shutdown' {
                                    # Process 'shutdown' message
                                    Write-PodeHost -Message 'Server requested shutdown. Closing Pode ...' -Force
                                    $serviceState = 'stopping'
                                    Write-PodeHost -Message "Service State: $serviceState" -Force
                                    Close-PodeServer  # Gracefully stop Pode server
                                    Start-Sleep 1
                                    Write-PodeHost -Message 'Closing Service Monitoring Heartbeat' -Force
                                    return  # Exit the loop
                                }

                                'restart' {
                                    # Process 'restart' message
                                    Write-PodeHost -Message 'Server requested restart. Restarting Pode ...' -Force

                                    $serviceState = 'starting'
                                    Write-PodeHost -Message "Service State: $serviceState" -Force
                                    Start-Sleep 1
                                    Restart-PodeServer  # Restart Pode server
                                    Write-PodeHost -Message 'Closing Service Monitoring Heartbeat' -Force
                                    Start-Sleep 1
                                    return
                                    # Exit the loop
                                }

                                'suspend' {
                                    # Process 'suspend' message
                                    Write-PodeHost -Message 'Server requested suspend. Suspending Pode ...' -Force
                                    Start-Sleep 5
                                    $serviceState = 'suspended'
                                    #Suspend-PodeServer  # Suspend Pode server
                                    # return  # Exit the loop
                                }

                                'resume' {
                                    # Process 'resume' message
                                    Write-PodeHost -Message 'Server requested resume. Resuming Pode ...' -Force
                                    Start-Sleep 5
                                    $serviceState = 'running'
                                    #Resume-PodeServer  # Resume Pode server
                                    #  return  # Exit the loop
                                }
                            }

                        }
                        break
                    }
                }
                catch {
                    $_ | Write-PodeErrorLog  # Log any errors that occur during pipe operation
                    throw $_
                }
                finally {
                    if ($reader) {
                        $reader.Dispose()
                    }
                    if ( $pipeStream) {
                        $pipeStream.Dispose()  # Always dispose of the pipe stream when done
                        Write-PodeHost -Message "Disposing Listener Pipe $($PodeContext.Server.Service.PipeName)" -Force
                    }
                }

            }
            Write-PodeHost -Message 'Closing Service Monitoring Heartbeat' -Force
        }

        # Assign a name to the Pode service
        $PodeContext.Server.Service['Name'] = 'Service'
        Write-Verbose -Message 'Starting service monitoring'

        # Start the runspace that runs the client receiver script block
        $PodeContext.Server.Service['Runspace'] = Add-PodeRunspace -Type 'Service' -ScriptBlock ($scriptBlock) -PassThru
    }
}

<#
.SYNOPSIS
    Registers a Pode service as a macOS LaunchAgent/Daemon.

.DESCRIPTION
    The `Register-PodeMacService` function creates a macOS plist file for the Pode service. It sets up the service
    to run using `launchctl`, specifying options such as autostart, logging, and the executable path.

.PARAMETER Name
    The name of the Pode service. This is used to identify the service in macOS.

.PARAMETER Description
    A brief description of the service. This is not included in the plist file but can be useful for logging.

.PARAMETER BinPath
    The path to the directory where the PodeMonitor executable is located.

.PARAMETER SettingsFile
    The path to the configuration file (e.g., `srvsettings.json`) that the Pode service will use.

.PARAMETER User
    The user under which the Pode service will run.

.PARAMETER Start
    If specified, the service will be started after registration.

.PARAMETER Autostart
    If specified, the service will automatically start when the system boots.

.PARAMETER OsArchitecture
    Specifies the architecture of the operating system (e.g., `osx-x64` or `osx-arm64`).

.PARAMETER Agent
    A switch to create an Agent instead of a Daemon in MacOS.

.OUTPUTS
    Returns $true if successful.

.EXAMPLE
    Register-PodeMacService -Name 'MyPodeService' -Description 'My Pode service' -BinPath '/path/to/bin' `
        -SettingsFile '/path/to/srvsettings.json' -User 'podeuser' -Start -Autostart -OsArchitecture 'osx-arm64'

    Registers a Pode service on macOS and starts it immediately with autostart enabled.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Register-PodeMacService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [string]
        $Description,

        [string]
        $BinPath,

        [string]
        $SettingsFile,

        [string]
        $User,

        [string]
        $OsArchitecture,

        [string]
        $LogPath,

        [switch]
        $Agent
    )

    $nameService = "pode.$Name.service".Replace(' ', '_')

    # Check if the service is already registered
    if ((Test-PodeMacOsServiceIsRegistered $nameService)) {
        # Service is already registered.
        throw ($PodeLocale.serviceAlreadyRegisteredException -f $nameService)
    }

    # Determine whether the service should run at load
    $runAtLoad = if ($Autostart.IsPresent) { '<true/>' } else { '<false/>' }
    if ($Agent) {
        $plistPath = "$($HOME)/Library/LaunchAgents/$($nameService).plist"
    }
    else {
        $plistPath = "/Library/LaunchDaemons/$($nameService).plist"
    }
    # Create the plist content
    @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$nameService</string>

    <key>ProgramArguments</key>
    <array>
        <string>$BinPath/$OsArchitecture/PodeMonitor</string> <!-- Path to your published executable -->
        <string>$SettingsFile</string> <!-- Path to your configuration file -->
    </array>

    <key>WorkingDirectory</key>
    <string>$BinPath</string>

    <key>RunAtLoad</key>
    $runAtLoad

    <key>StandardOutPath</key>
    <string>$LogPath/$nameService.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$LogPath/$nameService.stderr.log</string>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <!-- Enable advanced restart and recovery options
    <key>EnableTransactions</key>
    <true/>
    -->
</dict>
</plist>
"@ | Set-Content -Path $plistPath -Encoding UTF8

    Write-Verbose  -Message "Service '$nameService' WorkingDirectory : $($BinPath)."

    chmod +r $plistPath

    try {
        # Load the plist with launchctl
        if ($Agent) {
            launchctl load $plistPath
        }
        else {
            sudo launchctl load $plistPat
        }
        # Verify the service is now registered
        if (! (Test-PodeMacOsServiceIsRegistered $nameService)) {
            # Service registration failed.
            throw ($PodeLocale.serviceRegistrationException -f $nameService)
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_  # Rethrow the error after logging
        return $false
    }

    return $true
}


<#
.SYNOPSIS
    Registers a new systemd service on a Linux system to run a Pode-based PowerShell worker.

.DESCRIPTION
    The `Register-PodeLinuxService` function configures and registers a new systemd service on a Linux system.
    It sets up the service with the specified parameters, generates the service definition file, enables the service,
    and optionally starts it. It can also create the necessary user if it does not exist.

.PARAMETER Name
    The name of the systemd service to be registered.

.PARAMETER Description
    A brief description of the service. Defaults to an empty string.

.PARAMETER BinPath
    The path to the directory containing the `PodeMonitor` executable.

.PARAMETER SettingsFile
    The path to the settings file for the Pode worker.

.PARAMETER User
    The name of the user under which the service will run. If the user does not exist, it will be created unless the `SkipUserCreation` switch is used.

.PARAMETER Group
    The group under which the service will run. Defaults to the same as the `User` parameter.

.PARAMETER OsArchitecture
    The architecture of the operating system (e.g., `x64`, `arm64`). Used to locate the appropriate binary.

.OUTPUTS
    Returns $true if successful.

.EXAMPLE
    Register-PodeLinuxService -Name "PodeExampleService" -Description "An example Pode service" `
        -BinPath "/usr/local/bin" -SettingsFile "/etc/pode/example-settings.json" `
        -User "podeuser" -Group "podegroup" -Start -OsArchitecture "x64"

    Registers a new systemd service named "PodeExampleService", creates the necessary user and group,
    generates the service file, enables the service, and starts it.

.EXAMPLE
    Register-PodeLinuxService -Name "PodeExampleService" -BinPath "/usr/local/bin" `
        -SettingsFile "/etc/pode/example-settings.json" -User "podeuser" -SkipUserCreation `
        -OsArchitecture "arm64"

    Registers a new systemd service without creating the user, and does not start the service immediately.

.NOTES
    - This function assumes systemd is the init system on the Linux machine.
    - The function will check if the service is already registered and will throw an error if it is.
    - If the user specified by the `User` parameter does not exist, the function will create it unless the `SkipUserCreation` switch is used.
    - This is an internal function and may change in future releases of Pode.
#>
function Register-PodeLinuxService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [string]
        $Description,

        [string]
        $BinPath,

        [string]
        $SettingsFile,

        [string]
        $User,

        [string]
        $Group,

        [switch]
        $Start,

        [string]
        $OsArchitecture
    )
    $nameService = "$Name.service".Replace(' ', '_')
    $null = systemctl status $nameService 2>&1

    # Check if the service is already registered
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3) {
        # Service is already registered.
        throw ($PodeLocale.serviceAlreadyRegisteredException -f $nameService )
    }
    # Create a temporary file
    $tempFile = [System.IO.Path]::GetTempFileName()

    $execStart = "$BinPath/$OsArchitecture/PodeMonitor `"$SettingsFile`""
    # Create the service file
    @"
[Unit]
Description=$Description
After=network.target

[Service]
ExecStart=$execStart
WorkingDirectory=$BinPath
Restart=always
User=$User
KillMode=process
Environment=NOTIFY_SOCKET=/run/systemd/notify
Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1
# Uncomment and adjust if needed
# Group=$Group
# Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
"@ | Set-Content -Path $tempFile  -Encoding UTF8

    Write-Verbose  -Message "Service '$nameService' ExecStart : $execStart)."

    sudo cp $tempFile "/etc/systemd/system/$nameService"

    Remove-Item -path $tempFile -ErrorAction SilentlyContinue

    # Enable the service and check if it fails
    try {
        if (!(Enable-PodeLinuxService -Name $nameService)) {
            # Service registration failed.
            throw ($PodeLocale.serviceRegistrationException -f $nameService)
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_  # Rethrow the error after logging
        return $false
    }

    return $true
}

<#
.SYNOPSIS
    Registers a new Windows service to run a Pode-based PowerShell worker.

.DESCRIPTION
    The `Register-PodeMonitorWindowsService` function configures and registers a new Windows service to run a Pode-based PowerShell worker.
    It sets up the service with the specified parameters, including paths to the Pode monitor executable, configuration file,
    credentials, and security descriptor. The service can be optionally started immediately after registration.

.PARAMETER Name
    The name of the Windows service to be registered.

.PARAMETER Description
    A brief description of the service. Defaults to an empty string.

.PARAMETER DisplayName
    The display name of the service, as it will appear in the Windows Services Manager.

.PARAMETER StartupType
    Specifies how the service is started. Options are: 'Automatic', 'Manual', or 'Disabled'. Defaults to 'Automatic'.

.PARAMETER BinPath
    The path to the directory containing the `PodeMonitor` executable.

.PARAMETER SettingsFile
    The path to the configuration file for the Pode worker.

.PARAMETER Credential
    A `PSCredential` object specifying the credentials for the account under which the service will run.

.PARAMETER SecurityDescriptorSddl
    An SDDL string (Security Descriptor Definition Language) used to define the security of the service.

.PARAMETER OsArchitecture
    The architecture of the operating system (e.g., `x64`, `arm64`). Used to locate the appropriate binary.

.OUTPUTS
    Returns $true if successful.

.EXAMPLE
    Register-PodeMonitorWindowsService -Name "PodeExampleService" -DisplayName "Pode Example Service" `
        -BinPath "C:\Pode" -SettingsFile "C:\Pode\settings.json" `
        -StartupType "Automatic" -Credential (Get-Credential) -Start -OsArchitecture "x64"

    Registers a new Windows service named "PodeExampleService", creates the service with credentials,
    generates the service, and starts it.

.EXAMPLE
    Register-PodeMonitorWindowsService -Name "PodeExampleService" -BinPath "C:\Pode" `
        -SettingsFile "C:\Pode\settings.json" -OsArchitecture "x64"

    Registers a new Windows service without credentials or immediate startup.

.NOTES
    - This function assumes the service binary exists at the specified `BinPath`.
    - It checks if the service already exists and throws an error if it does.
    - This is an internal function and may change in future releases of Pode.
#>

function Register-PodeMonitorWindowsService {
    param(
        [string]
        $Name,

        [string]
        $Description,

        [string]
        $DisplayName,

        [string]
        $StartupType,

        [string]
        $BinPath,

        [string]
        $SettingsFile,

        [pscredential]
        $Credential,

        [string]
        $SecurityDescriptorSddl,

        [string]
        $OsArchitecture
    )


    # Check if service already exists
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
        # Service is already registered.
        throw ($PodeLocale.serviceAlreadyRegisteredException -f "$Name")

    }

    # Parameters for New-Service
    $params = @{
        Name           = $Name
        BinaryPathName = "`"$BinPath\$OsArchitecture\PodeMonitor.exe`" `"$SettingsFile`""
        DisplayName    = $DisplayName
        StartupType    = $StartupType
        Description    = $Description
        #DependsOn      = 'NetLogon'
    }
    if ($SecurityDescriptorSddl) {
        $params['SecurityDescriptorSddl'] = $SecurityDescriptorSddl
    }
    Write-Verbose -Message "Service '$Name' BinaryPathName : $($params['BinaryPathName'])."

    try {
        $paramsString = $params.GetEnumerator() | ForEach-Object { "-$($_.Key) '$($_.Value)'" }

        $sv = Invoke-PodeWinElevatedCommand -Command 'New-Service' -Arguments ($paramsString -join ' ') -Credential $Credential

        if (!$sv) {
            # Service registration failed.
            throw ($PodeLocale.serviceRegistrationException -f "$Name")
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_  # Rethrow the error after logging
        return $false
    }

    return $true
}





function Test-PodeUserServiceCreationPrivilege {
    # Get the list of user privileges
    $privileges = whoami /priv | Where-Object { $_ -match 'SeCreateServicePrivilege' }

    if ($privileges) {
        return $true
    }
    else {
        return $false
    }
}

<#
.SYNOPSIS
    Confirms if the current user has the necessary privileges to run the script.

.DESCRIPTION
    This function checks if the user has administrative privileges on Windows or root/sudo privileges on Linux/macOS.
    If the user does not have the required privileges, the script will output an appropriate message and exit.

.PARAMETER None
    This function does not accept any parameters.

.EXAMPLE
    Confirm-PodeAdminPrivilege

    This will check if the user has the necessary privileges to run the script. If not, it will output an error message and exit.

.OUTPUTS
    Exits the script if the necessary privileges are not available.

.NOTES
    This function works across Windows, Linux, and macOS, and checks for either administrative/root/sudo privileges or specific service-related permissions.
#>

function Confirm-PodeAdminPrivilege {
    # Check for administrative privileges
    if (! (Test-PodeAdminPrivilege -Elevate)) {
        if (Test-PodeIsWindows -and (Test-PodeUserServiceCreationPrivilege)) {
            Write-PodeHost "Insufficient privileges. This script requires Administrator access or the 'SERVICE_CHANGE_CONFIG' (SeCreateServicePrivilege) permission to continue." -ForegroundColor Red
            exit
        }

        # Message for non-Windows (Linux/macOS)
        Write-PodeHost 'Insufficient privileges. This script must be run as root or with sudo permissions to continue.' -ForegroundColor Red
        exit
    }
}

<#
.SYNOPSIS
    Tests if a Linux service is registered.

.DESCRIPTION
    Checks if a specified Linux service is registered by using the `systemctl status` command.
    It returns `$true` if the service is found or its status code matches either `0` or `3`.

.PARAMETER Name
    The name of the Linux service to test.

.OUTPUTS
    [bool]
    Returns `$true` if the service is registered; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeLinuxServiceIsRegistered {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $systemctlStatus = systemctl status $Name 2>&1
    $isRegistered = ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3)
    Write-Verbose -Message ($systemctlStatus -join '`n')
    return $isRegistered
}

<#
.SYNOPSIS
    Tests if a Linux service is active.

.DESCRIPTION
    Checks if a specified Linux service is currently active by using the `systemctl is-active` command.
    It returns `$true` if the service is active.

.PARAMETER Name
    The name of the Linux service to check.

.OUTPUTS
    [bool]
    Returns `$true` if the service is active; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeLinuxServiceIsActive {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $systemctlIsActive = systemctl is-active $Name 2>&1
    $isActive = $systemctlIsActive -eq 'active'
    Write-Verbose -Message ($systemctlIsActive -join '`n')
    return $isActive
}

<#
.SYNOPSIS
    Disables a Linux service.

.DESCRIPTION
    Disables a specified Linux service by using the `sudo systemctl disable` command.
    It returns `$true` if the service is successfully disabled.

.PARAMETER Name
    The name of the Linux service to disable.

.OUTPUTS
    [bool]
    Returns `$true` if the service is successfully disabled; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Disable-PodeLinuxService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $systemctlDisable = sudo systemctl disable $Name 2>&1
    $success = $LASTEXITCODE -eq 0
    Write-Verbose -Message ($systemctlDisable -join '`n')
    return $success
}

<#
.SYNOPSIS
    Enables a Linux service.

.DESCRIPTION
    Enables a specified Linux service by using the `sudo systemctl enable` command.
    It returns `$true` if the service is successfully enabled.

.PARAMETER Name
    The name of the Linux service to enable.

.OUTPUTS
    [bool]
    Returns `$true` if the service is successfully enabled; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Enable-PodeLinuxService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $systemctlEnable = sudo systemctl enable $Name 2>&1
    $success = $LASTEXITCODE -eq 0
    Write-Verbose -Message ($systemctlEnable -join '`n')
    return $success
}

<#
.SYNOPSIS
    Stops a Linux service.

.DESCRIPTION
    Stops a specified Linux service by using the `systemctl stop` command.
    It returns `$true` if the service is successfully stopped.

.PARAMETER Name
    The name of the Linux service to stop.

.OUTPUTS
    [bool]
    Returns `$true` if the service is successfully stopped; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Stop-PodeLinuxService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    #return (Send-PodeServiceSignal -Name $Name -Signal SIGTERM)
    $serviceStopInfo = sudo systemctl stop  $("$Name.service".Replace(' ', '_')) 2>&1
    $success = $LASTEXITCODE -eq 0
    Write-Verbose -Message ($serviceStopInfo -join "`n")
    return $success
}

<#
.SYNOPSIS
    Starts a Linux service.

.DESCRIPTION
    Starts a specified Linux service by using the `systemctl start` command.
    It returns `$true` if the service is successfully started.

.PARAMETER Name
    The name of the Linux service to start.

.OUTPUTS
    [bool]
    Returns `$true` if the service is successfully started; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeLinuxService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $serviceStartInfo = sudo systemctl start $Name 2>&1
    $success = $LASTEXITCODE -eq 0
    Write-Verbose -Message ($serviceStartInfo -join "`n")
    return $success
}

<#
.SYNOPSIS
    Tests if a macOS service is registered.

.DESCRIPTION
    Checks if a specified macOS service is registered by using the `launchctl list` command.
    It returns `$true` if the service is registered.

.PARAMETER Name
    The name of the macOS service to test.

.OUTPUTS
    [bool]
    Returns `$true` if the service is registered; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeMacOsServiceIsRegistered {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $systemctlStatus = launchctl list $Name 2>&1
    $isRegistered = ($LASTEXITCODE -eq 0)
    Write-Verbose -Message ($systemctlStatus -join '`n')
    return $isRegistered
}

<#
.SYNOPSIS
    Checks if a Pode service is registered on the current operating system.

.DESCRIPTION
    This function determines if a Pode service with the specified name is registered,
    based on the operating system. It delegates the check to the appropriate
    platform-specific function or logic.

.PARAMETER Name
    The name of the Pode service to check.

.EXAMPLE
    Test-PodeServiceIsRegistered -Name 'MyService'

    Checks if the Pode service named 'MyService' is registered.

.NOTES
   This is an internal function and may change in future releases of Pode.
#>
function Test-PodeServiceIsRegistered {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    if (Test-PodeIsWindows) {
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"
        return $null -eq $service
    }
    if ($IsLinux) {
        return Test-PodeLinuxServiceIsRegistered -Name $Name
    }
    if ($IsMacOS) {
        return Test-PodeMacOsServiceIsRegistered -Name $Name
    }
}

<#
.SYNOPSIS
    Checks if a Pode service is active and running on the current operating system.

.DESCRIPTION
    This function determines if a Pode service with the specified name is active (running),
    based on the operating system. It delegates the check to the appropriate platform-specific
    function or logic.

.PARAMETER Name
    The name of the Pode service to check.

.EXAMPLE
    Test-PodeServiceIsActive -Name 'MyService'

    Checks if the Pode service named 'MyService' is active and running.

.NOTES
   This is an internal function and may change in future releases of Pode.
#>
function Test-PodeServiceIsActive {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    if (Test-PodeIsWindows) {
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($service) {
            # Check if the service is already running
            return ($service.Status -ne 'Running')
        }
        return $false
    }
    if ($IsLinux) {
        return Test-PodeLinuxServiceIsActive -Name $Name
    }
    if ($IsMacOS) {
        return Test-PodeMacOsServiceIsActive -Name $Name
    }

}


<#
.SYNOPSIS
    Tests if a macOS service is active.

.DESCRIPTION
    Checks if a specified macOS service is currently active by looking for the "PID" value in the output of `launchctl list`.
    It returns `$true` if the service is active (i.e., if a PID is found).

.PARAMETER Name
    The name of the macOS service to check.

.OUTPUTS
    [bool]
    Returns `$true` if the service is active; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Test-PodeMacOsServiceIsActive {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $serviceInfo = launchctl list $name
    $isActive = $serviceInfo -match '"PID" = (\d+);'
    Write-Verbose -Message ($serviceInfo -join "`n")
    return $isActive.Count -eq 1
}

<#
.SYNOPSIS
    Retrieves the PID of a macOS service.

.DESCRIPTION
    Retrieves the process ID (PID) of a specified macOS service by using `launchctl list`.
    If the service is not active or a PID cannot be found, the function returns `0`.

PARAMETER Name
    The name of the macOS service whose PID you want to retrieve.

.OUTPUTS
    [int]
    Returns the PID of the service if it is active; otherwise, returns `0`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Get-PodeMacOsServicePid {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $serviceInfo = launchctl list $name
    $pidString = $serviceInfo -match '"PID" = (\d+);'
    Write-Verbose -Message ($serviceInfo -join "`n")
    return $(if ($pidString.Count -eq 1) { ($pidString[0].split('= '))[1].trim(';') } else { 0 })
}

<#
.SYNOPSIS
    Disables a macOS service.

.DESCRIPTION
    Disables a specified macOS service by using `launchctl unload` to unload the service's plist file.
    It returns `$true` if the service is successfully disabled.

.PARAMETER Name
    The name of the macOS service to disable.

.OUTPUTS
    [bool]
    Returns `$true` if the service is successfully disabled; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Disable-PodeMacOsService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $sudo = !(Test-Path -Path "$($HOME)/Library/LaunchAgents/$($Name).plist" -PathType Leaf)
    if ($sudo) {
        $systemctlDisable = sudo launchctl unload "/Library/LaunchDaemons/$Name.plist" 2>&1
    }
    else {
        $systemctlDisable = launchctl unload "$HOME/Library/LaunchAgents/$Name.plist" 2>&1
    }
    $success = $LASTEXITCODE -eq 0
    Write-Verbose -Message ($systemctlDisable -join '`n')
    return $success
}

<#
.SYNOPSIS
    Stops a macOS service.

.DESCRIPTION
    Stops a specified macOS service by using the `launchctl stop` command.
    It returns `$true` if the service is successfully stopped.

.PARAMETER Name
    The name of the macOS service to stop.

.OUTPUTS
    [bool]
    Returns `$true` if the service is successfully stopped; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Stop-PodeMacOsService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (Send-PodeServiceSignal -Name $Name -Signal SIGTERM)
    #  $serviceStopInfo = launchctl stop $Name 2>&1
    # $success = $LASTEXITCODE -eq 0
    # Write-Verbose -Message ($serviceStopInfo -join "`n")
    # return $success
}

<#
.SYNOPSIS
    Starts a macOS service.

.DESCRIPTION
    Starts a specified macOS service by using the `launchctl start` command.
    It returns `$true` if the service is successfully started.

.PARAMETER Name
    The name of the macOS service to start.

.OUTPUTS
    [bool]
    Returns `$true` if the service is successfully started; otherwise, `$false`.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Start-PodeMacOsService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    $sudo = !(Test-Path -Path "$($HOME)/Library/LaunchAgents/$($nameService).plist" -PathType Leaf)
    if ($sudo) {
        $serviceStartInfo = sudo launchctl start $Name 2>&1
    }
    else {
        $serviceStartInfo = launchctl start $Name 2>&1
    }
    $success = $LASTEXITCODE -eq 0
    Write-Verbose -Message ($serviceStartInfo -join "`n")
    return $success
}


function Send-PodeServiceSignal {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateSet('SIGTSTP', 'SIGCONT', 'SIGHUP', 'SIGTERM')]
        [string]
        $Signal
    )

    # Standardize service naming for Linux/macOS
    $nameService = $(if ($IsMacOS) { "pode.$Name.service".Replace(' ', '_') }else { "$Name.service".Replace(' ', '_') })

    $signalMap = @{
        'SIGTSTP' = 20
        'SIGCONT' = 18
        'SIGHUP'  = 1
        'SIGTERM' = 15
    }

    $level = $signalMap[$Signal]
    # Check if the service is registered
    if ((Test-PodeServiceIsRegistered -Name $nameService)) {
        if ((Test-PodeServiceIsActive -Name $nameService)) {
            Write-Verbose -Message "Service '$Name' is active. Sending $Signal signal."
            $svc = Get-PodeService -Name $Name
            if ($svc.Sudo) {
                sudo /bin/kill -$($level) $svc.Pid
            }
            else {
                /bin/kill -$($level) $svc.Pid
            }
            $success = $LASTEXITCODE -eq 0
            if ($success) {
                Write-Verbose -Message "$Signal signal sent to service '$Name'."
            }
            return $success
        }
        else {
            Write-Verbose -Message "Service '$Name' is not running."
        }
    }
    else {
        # Service is not registered
        throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
    }
    return $false
}