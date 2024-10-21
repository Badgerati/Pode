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
            Write-PodeServiceLog -Message "Start client receiver for pipe $($PodeContext.Server.Service.PipeName)"
            try {
                # Create a named pipe server stream
                $pipeStream = [System.IO.Pipes.NamedPipeServerStream]::new(
                    $PodeContext.Server.Service.PipeName,
                    [System.IO.Pipes.PipeDirection]::InOut,
                    2, # Max number of allowed concurrent connections
                    [System.IO.Pipes.PipeTransmissionMode]::Byte,
                    [System.IO.Pipes.PipeOptions]::None
                )

                Write-PodeServiceLog -Message "Waiting for connection to the $($PodeContext.Server.Service.PipeName) pipe."
                $pipeStream.WaitForConnection()  # Wait until a client connects
                Write-PodeServiceLog -Message "Connected to the $($PodeContext.Server.Service.PipeName) pipe."

                # Create a StreamReader to read incoming messages from the pipe
                $reader = [System.IO.StreamReader]::new($pipeStream)

                # Process incoming messages in a loop as long as the pipe is connected
                while ($pipeStream.IsConnected) {
                    $message = $reader.ReadLine()  # Read message from the pipe

                    if ($message) {
                        Write-PodeServiceLog -Message "Received message: $message"

                        # Process 'shutdown' message
                        if ($message -eq 'shutdown') {
                            Write-PodeServiceLog -Message 'Server requested shutdown. Closing client...'
                            Close-PodeServer  # Gracefully stop the Pode server
                            break  # Exit the loop

                            # Process 'restart' message
                        }
                        elseif ($message -eq 'restart') {
                            Write-PodeServiceLog -Message 'Server requested restart. Restarting client...'
                            Restart-PodeServer  # Restart the Pode server
                            break  # Exit the loop
                        }
                    }
                }
            }
            catch {
                $_ | Write-PodeServiceLog  # Log any errors that occur during pipe operation
            }
            finally {
                $reader.Dispose()
                $pipeStream.Dispose()  # Always dispose of the pipe stream when done
            }

        }

        # Assign a name to the Pode service
        $PodeContext.Server.Service['Name'] = 'Service'
        Write-PodeServiceLog -Message 'Starting service monitoring'

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
        $LogPath
    )

    # Check if the service is already registered
    if (launchctl list | Select-String "pode.$Name") {
        # Service is already registered.
        throw ($PodeLocale.serviceAlreadyRegisteredException -f "pode.$Name")
    }

    # Determine whether the service should run at load
    $runAtLoad = if ($Autostart.IsPresent) { '<true/>' } else { '<false/>' }

    # Create the plist content
    @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>pode.$Name</string>

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
    <string>$LogPath/pode.$Name.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>$LogPath/pode.$Name.stderr.log</string>

    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
</dict>
</plist>
"@ | Set-Content -Path "$($HOME)/Library/LaunchAgents/pode.$($Name).plist" -Encoding UTF8

    chmod +r "$($HOME)/Library/LaunchAgents/pode.$($Name).plist"

    try {
        # Load the plist with launchctl
        launchctl load "$($HOME)/Library/LaunchAgents/pode.$($Name).plist"

        # Verify the service is now registered
        if (! (launchctl list | Select-String "pode.$Name")) {
            # Service registration failed.
            throw ($PodeLocale.serviceRegistrationException -f "pode.$Name")

        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_  # Rethrow the error after logging
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

.PARAMETER SkipUserCreation
    A switch to skip the creation of the user if it does not exist.

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

        [switch]
        $SkipUserCreation,

        [string]
        $OsArchitecture
    )
    $nameService = "$Name.service".Replace(' ', '\x20')
    $output = bash -c "systemctl status $nameService 2>&1"

    # Check if the service is already registered
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3) {
        # Service is already registered.
        throw ($PodeLocale.serviceAlreadyRegisteredException -f $nameService )
    }
    # Create a temporary file
    $tempFile = [System.IO.Path]::GetTempFileName()
    # Create the service file
    @"
[Unit]
Description=$Description
After=network.target

[Service]
ExecStart=$BinPath/$OsArchitecture/PodeMonitor $SettingsFile
WorkingDirectory=$BinPath
Restart=always
User=$User
Group=$Group
# Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1
# Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
"@ | Set-Content -Path $tempFile  -Encoding UTF8

    sudo cp $tempFile "/etc/systemd/system/$nameService"

    # Create user if needed
    if (!$SkipUserCreation.IsPresent) {
        # Run the id command to check if the user exists
        id $User 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Create the user if it doesn't exist
            sudo useradd -r -s /bin/false $User
        }
    }

    # Enable the service and check if it fails
    try {
        sudo systemctl enable $nameService
        if ($LASTEXITCODE -ne 0) {
            # Service registration failed.
            throw ($PodeLocale.serviceRegistrationException -f $nameService)
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_  # Rethrow the error after logging
    }

    return $true
}



<#
.SYNOPSIS
    Registers a new Windows service to run a Pode-based PowerShell worker.

.DESCRIPTION
    The `Register-PodeWindowsService` function configures and registers a new Windows service to run a Pode-based PowerShell worker.
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
    Register-PodeWindowsService -Name "PodeExampleService" -DisplayName "Pode Example Service" `
        -BinPath "C:\Pode" -SettingsFile "C:\Pode\settings.json" `
        -StartupType "Automatic" -Credential (Get-Credential) -Start -OsArchitecture "x64"

    Registers a new Windows service named "PodeExampleService", creates the service with credentials,
    generates the service, and starts it.

.EXAMPLE
    Register-PodeWindowsService -Name "PodeExampleService" -BinPath "C:\Pode" `
        -SettingsFile "C:\Pode\settings.json" -OsArchitecture "x64"

    Registers a new Windows service without credentials or immediate startup.

.NOTES
    - This function assumes the service binary exists at the specified `BinPath`.
    - It checks if the service already exists and throws an error if it does.
    - This is an internal function and may change in future releases of Pode.
#>

function Register-PodeWindowsService {
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
    if ($Credential) {
        $params['Credential'] = $Credential
    }
    if ($SecurityDescriptorSddl) {
        $params['SecurityDescriptorSddl'] = $SecurityDescriptorSddl
    }

    try {
        $paramsString = $params.GetEnumerator() | ForEach-Object { "-$($_.Key) '$($_.Value)'" }
        $sv = Invoke-PodeWinElevatedCommand -Command 'New-Service' -Arguments ($paramsString -join ' ')

        if (!$sv) {
            # Service registration failed.
            throw ($PodeLocale.serviceRegistrationException -f "$Name")
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        throw $_  # Rethrow the error after logging
    }

    return $true
}


function Write-PodeServiceLog {
    [CmdletBinding(DefaultParameterSetName = 'Message')]
    param(


        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Exception')]
        [System.Exception]
        $Exception,

        [Parameter(ParameterSetName = 'Exception')]
        [switch]
        $CheckInnerException,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Error')]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Message')]
        [string]
        $Message,

        [string]
        $Level = 'Informational',

        [string]
        $Tag = '-',

        [Parameter()]
        [int]
        $ThreadId

    )
    Process {
        $Service = $PodeContext.Server.Service
        if ($null -eq $Service ) {
            $Service = @{Name = 'Not a service' }
        }
        switch ($PSCmdlet.ParameterSetName.ToLowerInvariant()) {

            'message' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Level   = $Level
                        Message = $Message
                        Tag     = $Tag
                    }
                }
                break
            }
            'custom' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Level   = $Level
                        Message = $Message
                        Tag     = $Tag
                    }
                }
                break
            }
            'exception' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Category   = $Exception.Source
                        Message    = $Exception.Message
                        StackTrace = $Exception.StackTrace
                        Level      = $Level
                    }
                }
                Write-PodeErrorLog -Level $Level -CheckInnerException:$CheckInnerException -Exception $Exception
            }

            'error' {
                $logItem = @{
                    Name = $Service.Name
                    Date = (Get-Date).ToUniversalTime()
                    Item = @{
                        Category   = $ErrorRecord.CategoryInfo.ToString()
                        Message    = $ErrorRecord.Exception.Message
                        StackTrace = $ErrorRecord.ScriptStackTrace
                        Level      = $Level
                    }
                }
                Write-PodeErrorLog -Level $Level -ErrorRecord $ErrorRecord
            }
        }

        $lpath = Get-PodeRelativePath -Path './logs' -JoinRoot
        $logItem | ConvertTo-Json -Compress -Depth 5 | Add-Content "$lpath/watchdog-$($Service.Name).log"

    }
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
        if ($IsWindows -and (Test-PodeUserServiceCreationPrivilege)) {
            Write-PodeHost "Insufficient privileges. This script requires Administrator access or the 'SERVICE_CHANGE_CONFIG' (SeCreateServicePrivilege) permission to continue." -ForegroundColor Red
            exit
        }

        # Message for non-Windows (Linux/macOS)
        Write-PodeHost 'Insufficient privileges. This script must be run as root or with sudo permissions to continue.' -ForegroundColor Red
        exit
    }
}