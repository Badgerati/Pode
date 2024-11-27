<#
.SYNOPSIS
    Registers a new Pode-based PowerShell worker as a service on Windows, Linux, or macOS.

.DESCRIPTION
    The `Register-PodeService` function configures and registers a Pode-based service that runs a PowerShell worker across multiple platforms
    (Windows, Linux, macOS). It creates the service with parameters such as paths to the worker script, log files, and service-specific settings.
    A `srvsettings.json` configuration file is generated, and the service can be optionally started after registration.

.PARAMETER Name
    Specifies the name of the service to be registered. This is a required parameter.

.PARAMETER Description
    A brief description of the service. Defaults to "This is a Pode service."

.PARAMETER DisplayName
    Specifies the display name for the service (Windows only). Defaults to "Pode Service($Name)".

.PARAMETER StartupType
    Specifies the startup type of the service ('Automatic' or 'Manual'). Defaults to 'Automatic'.

.PARAMETER ParameterString
    Any additional parameters to pass to the worker script when the service is run. Defaults to an empty string.

.PARAMETER LogServicePodeHost
    Enables logging for the Pode service host. If not provided, the service runs in quiet mode.

.PARAMETER ShutdownWaitTimeMs
    Maximum time in milliseconds to wait for the service to shut down gracefully before forcing termination. Defaults to 30,000 milliseconds (30 seconds).

.PARAMETER StartMaxRetryCount
    The maximum number of retries to start the PowerShell process before giving up. Default is 3 retries.

.PARAMETER StartRetryDelayMs
    The delay (in milliseconds) between retry attempts to start the PowerShell process. Default is 5,000 milliseconds (5 seconds).

.PARAMETER WindowsUser
    Specifies the username under which the service will run on Windows. Defaults to the current user if not provided.

.PARAMETER LinuxUser
    Specifies the username under which the service will run on Linux. Defaults to the current user if not provided.

.PARAMETER Agent
    A switch to create an Agent instead of a Daemon on macOS (macOS only).

.PARAMETER Start
    A switch to start the service immediately after registration.

.PARAMETER Password
    A secure password for the service account (Windows only). If omitted, the service account defaults to 'NT AUTHORITY\SYSTEM'.

.PARAMETER SecurityDescriptorSddl
    A security descriptor in SDDL format, specifying the permissions for the service (Windows only).

.PARAMETER SettingsPath
    Specifies the directory to store the service configuration file (`<name>_svcsettings.json`). If not provided, a default directory is used.

.PARAMETER LogPath
    Specifies the path for the service log files. If not provided, a default log directory is used.

.PARAMETER LogLevel
    Specifies the log verbosity level. Valid values are 'Debug', 'Info', 'Warn', 'Error', or 'Critical'. Defaults to 'Info'.

.PARAMETER LogMaxFileSize
    Specifies the maximum size of the log file in bytes. Defaults to 10 MB (10,485,760 bytes).

.EXAMPLE
    Register-PodeService -Name "PodeExampleService" -Description "Example Pode Service" -ParameterString "-Verbose"

    This example registers a Pode service named "PodeExampleService" with verbose logging enabled.

.NOTES
    - Supports cross-platform service registration on Windows, Linux, and macOS.
    - Generates a `srvsettings.json` file with service-specific configurations.
    - Automatically starts the service using the `-Start` switch after registration.
    - Dynamically obtains the PowerShell executable path for compatibility across platforms.
#>
function Register-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Description = 'This is a Pode service.',

        [Parameter()]
        [string]
        $DisplayName = "Pode Service($Name)",

        [Parameter()]
        [string]
        [validateset('Manual', 'Automatic')]
        $StartupType = 'Automatic',

        [Parameter()]
        [string]
        $SecurityDescriptorSddl,

        [Parameter()]
        [string]
        $ParameterString = '',

        [Parameter()]
        [switch]
        $LogServicePodeHost,

        [Parameter()]
        [int]
        $ShutdownWaitTimeMs = 30000,

        [Parameter()]
        [int]
        $StartMaxRetryCount = 3,

        [Parameter()]
        [int]
        $StartRetryDelayMs = 5000,

        [Parameter()]
        [string]
        $WindowsUser,

        [Parameter()]
        [string]
        $LinuxUser,

        [Parameter()]
        [switch]
        $Start,

        [Parameter()]
        [switch]
        $Agent,

        [Parameter()]
        [securestring]
        $Password,

        [Parameter()]
        [string]
        $SettingsPath,

        [Parameter()]
        [string]
        $LogPath,

        [Parameter()]
        [string]
        [validateset('Debug', 'Info', 'Warn', 'Error', 'Critical')]
        $LogLevel = 'Info',

        [Parameter()]
        [Int64]
        $LogMaxFileSize = 10 * 1024 * 1024
    )

    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    try {
        # Obtain the script path and directory
        if ($MyInvocation.ScriptName) {
            $ScriptPath = $MyInvocation.ScriptName
            $MainScriptPath = Split-Path -Path $ScriptPath -Parent
        }
        else {
            return $null
        }
        # Define log paths and ensure the log directory exists
        if (! $LogPath) {
            $LogPath = Join-Path -Path $MainScriptPath -ChildPath 'logs'
        }

        if (! (Test-Path -Path $LogPath -PathType Container)) {
            $null = New-Item -Path $LogPath -ItemType Directory -Force
        }

        $LogFilePath = Join-Path -Path $LogPath -ChildPath "$($Name)_svc.log"

        # Dynamically get the PowerShell executable path
        $PwshPath = (Get-Process -Id $PID).Path

        # Define configuration directory and settings file path
        if (!$SettingsPath) {
            $SettingsPath = Join-Path -Path $MainScriptPath -ChildPath 'svc_settings'
        }

        if (! (Test-Path -Path $SettingsPath -PathType Container)) {
            $null = New-Item -Path $settingsPath -ItemType Directory
        }

        if (Test-PodeIsWindows) {
            if ([string]::IsNullOrEmpty($WindowsUser)) {
                if ( ($null -ne $Password)) {
                    $UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                }
            }
            else {
                $UserName = $WindowsUser
                if ( ($null -eq $Password)) {
                    throw ($Podelocale.passwordRequiredForServiceUserException -f $UserName)
                }
            }
        }
        elseif ($IsLinux) {
            if ([string]::IsNullOrEmpty($LinuxUser)) {
                $UserName = [System.Environment]::UserName
            }
            else {
                $UserName = $LinuxUser
            }
        }

        $settingsFile = Join-Path -Path $settingsPath -ChildPath "$($Name)_svcsettings.json"
        Write-Verbose -Message "Service '$Name' setting : $settingsFile."

        # Generate the service settings JSON file
        $jsonContent = @{
            PodeMonitorWorker = @{
                ScriptPath         = $ScriptPath
                PwshPath           = $PwshPath
                ParameterString    = $ParameterString
                LogFilePath        = $LogFilePath
                Quiet              = !$LogServicePodeHost.IsPresent
                DisableTermination = $true
                ShutdownWaitTimeMs = $ShutdownWaitTimeMs
                Name               = $Name
                StartMaxRetryCount = $StartMaxRetryCount
                StartRetryDelayMs  = $StartRetryDelayMs
                LogLevel           = $LogLevel.ToUpper()
                LogMaxFileSize     = $LogMaxFileSize
            }
        }

        # Save JSON to the settings file
        $jsonContent | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8

        # Determine OS architecture and call platform-specific registration functions
        $osArchitecture = Get-PodeOSPwshArchitecture

        if ([string]::IsNullOrEmpty($osArchitecture)) {
            Write-Verbose 'Unsupported Architecture'
            return $false
        }

        # Get the directory path where the Pode module is installed and store it in $binPath
        $binPath = Join-Path -Path ((Get-Module -Name Pode).ModuleBase) -ChildPath 'Bin'

        if (Test-PodeIsWindows) {
            $param = @{
                Name                   = $Name
                Description            = $Description
                DisplayName            = $DisplayName
                StartupType            = $StartupType
                BinPath                = $binPath
                SettingsFile           = $settingsFile
                Credential             = if ($Password) { [pscredential]::new($UserName, $Password) }else { $null }
                SecurityDescriptorSddl = $SecurityDescriptorSddl
                OsArchitecture         = "win-$osArchitecture"
            }
            $operation = Register-PodeMonitorWindowsService @param
        }
        elseif ($IsLinux) {
            $param = @{
                Name           = $Name
                Description    = $Description
                BinPath        = $binPath
                SettingsFile   = $settingsFile
                User           = $User
                Group          = $Group
                Start          = $Start
                OsArchitecture = "linux-$osArchitecture"
            }
            $operation = Register-PodeLinuxService @param
        }
        elseif ($IsMacOS) {
            $param = @{
                Name           = $Name
                Description    = $Description
                BinPath        = $binPath
                SettingsFile   = $settingsFile
                User           = $User
                OsArchitecture = "osx-$osArchitecture"
                LogPath        = $LogPath
                Agent          = $Agent
            }

            $operation = Register-PodeMacService @param
        }

        # Optionally start the service if requested
        if (  $operation -and $Start.IsPresent) {
            $operation = Start-PodeService -Name $Name
        }

        return $operation
    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
	Start a Pode-based service on Windows, Linux, or macOS.

.DESCRIPTION
	The `Start-PodeService` function ensures that a specified Pode-based service is running. If the service is not registered or fails to start, the function throws an error. It supports platform-specific service management commands:
	- Windows: Uses `sc.exe`.
	- Linux: Uses `systemctl`.
	- macOS: Uses `launchctl`.

.PARAMETER Name
	The name of the service to start.

.PARAMETER Async
	Indicates whether to return immediately after issuing the start command. If not specified, the function waits until the service reaches the 'Running' state.

.PARAMETER Timeout
	The maximum time, in seconds, to wait for the service to reach the 'Running' state when not using `-Async`. Defaults to 10 seconds.

.EXAMPLE
	Start-PodeService -Name 'MyService'

	Starts the service named 'MyService' if it is not already running.

.EXAMPLE
	Start-PodeService -Name 'MyService' -Async

	Starts the service named 'MyService' and returns immediately.

.NOTES
	- This function checks for necessary administrative/root privileges before execution.
	- Service state management behavior:
		- If the service is already running, no action is taken.
		- If the service is not registered, an error is thrown.
	- Service name is retrieved from the `srvsettings.json` file if available.
	- Platform-specific commands are invoked to manage service states:
		- Windows: `sc.exe start`.
		- Linux: `sudo systemctl start`.
		- macOS: `sudo launchctl start`.
	- Errors and logs are captured for debugging purposes.
#>
function Start-PodeService {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch] $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [ValidateRange(1, 300)]
        [int] $Timeout = 10
    )
    try {
        # Ensure administrative/root privileges
        Confirm-PodeAdminPrivilege

        # Get the service status
        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }

        Write-Verbose -Message "Service '$Name' current state: $($service.Status)."

        # Handle the current service state
        switch ($service.Status) {
            'Running' {
                Write-Verbose -Message "Service '$Name' is already running."
                return $true
            }
            'Suspended' {
                Write-Verbose -Message "Service '$Name' is suspended. Cannot start a suspended service."
                return $false
            }
            'Stopped' {
                Write-Verbose -Message "Service '$Name' is currently stopped. Attempting to start..."
            }
            { $_ -eq 'Starting' -or $_ -eq 'Stopping' -or $_ -eq 'Pausing' -or $_ -eq 'Resuming' } {
                Write-Verbose -Message "Service '$Name' is transitioning state ($($service.Status)). Cannot start at this time."
                return $false
            }
            default {
                Write-Verbose -Message "Service '$Name' is in an unknown state ($($service.Status))."
                return $false
            }
        }

        # Start the service based on the OS
        $serviceStarted = $false
        if (Test-PodeIsWindows) {
            $serviceStarted = Invoke-PodeWinElevatedCommand -Command 'sc.exe' -Arguments "start '$Name'"
        }
        elseif ($IsLinux) {
            $serviceStarted = Start-PodeLinuxService -Name $Name
        }
        elseif ($IsMacOS) {
            $serviceStarted = Start-PodeMacOsService -Name $Name
        }

        # Check if the service start command failed
        if (!$serviceStarted) {
            throw ($PodeLocale.serviceCommandFailedException -f 'Start', $Name)
        }

        # Handle async or wait for start
        if ($Async) {
            Write-Verbose -Message "Async mode: Service start command issued for '$Name'."
            return $true
        }
        else {
            Write-Verbose -Message "Waiting for service '$Name' to start (timeout: $Timeout seconds)..."
            return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
	Stop a Pode-based service on Windows, Linux, or macOS.

.DESCRIPTION
	The `Stop-PodeService` function ensures that a specified Pode-based service is stopped. If the service is not registered or fails to stop, the function throws an error. It supports platform-specific service management commands:
	- Windows: Uses `sc.exe`.
	- Linux: Uses `systemctl`.
	- macOS: Uses `launchctl`.

.PARAMETER Name
	The name of the service to stop.

.PARAMETER Async
	Indicates whether to return immediately after issuing the stop command. If not specified, the function waits until the service reaches the 'Stopped' state.

.PARAMETER Timeout
	The maximum time, in seconds, to wait for the service to reach the 'Stopped' state when not using `-Async`. Defaults to 10 seconds.

.EXAMPLE
	Stop-PodeService -Name 'MyService'

	Stops the service named 'MyService' if it is currently running.

.EXAMPLE
	Stop-PodeService -Name 'MyService' -Async

	Stops the service named 'MyService' and returns immediately.

.NOTES
	- This function checks for necessary administrative/root privileges before execution.
	- Service state management behavior:
		- If the service is not running, no action is taken.
		- If the service is not registered, an error is thrown.
	- Service name is retrieved from the `srvsettings.json` file if available.
	- Platform-specific commands are invoked to manage service states:
		- Windows: `sc.exe`.
		- Linux: `sudo systemctl stop`.
		- macOS: `sudo launchctl stop`.
	- Errors and logs are captured for debugging purposes.

#>
function Stop-PodeService {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch]
        $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [ValidateRange(1, 300)]
        [int]
        $Timeout = 10
    )
    try {
        # Ensure administrative/root privileges
        Confirm-PodeAdminPrivilege

        # Get the service status
        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }

        Write-Verbose -Message "Service '$Name' current state: $($service.Status)."

        # Handle service states
        switch ($service.Status) {
            'Stopped' {
                Write-Verbose -Message "Service '$Name' is already stopped."
                return $true
            }
            { $_ -eq 'Running' -or $_ -eq 'Suspended' } {
                Write-Verbose -Message "Service '$Name' is currently $($service.Status). Attempting to stop..."
            }
            { $_ -eq 'Starting' -or $_ -eq 'Stopping' -or $_ -eq 'Pausing' -or $_ -eq 'Resuming' } {
                Write-Verbose -Message "Service '$Name' is transitioning state ($($service.Status)). Cannot stop at this time."
                return $false
            }
            default {
                Write-Verbose -Message "Service '$Name' is in an unknown state ($($service.Status))."
                return $false
            }
        }

        # Stop the service
        $serviceStopped = $false
        if (Test-PodeIsWindows) {
            $serviceStopped = Invoke-PodeWinElevatedCommand -Command 'sc.exe' -Arguments "stop '$Name'"
        }
        elseif ($IsLinux) {
            $serviceStopped = Stop-PodeLinuxService -Name $Name
        }
        elseif ($IsMacOS) {
            $serviceStopped = Stop-PodeMacOsService -Name $Name
        }

        if (!$serviceStopped) {
            throw ($PodeLocale.serviceCommandFailedException -f 'Stop', $Name)
        }

        # Handle async or wait for stop
        if ($Async) {
            Write-Verbose -Message "Async mode: Service stop command issued for '$Name'."
            return $true
        }
        else {
            Write-Verbose -Message "Waiting for service '$Name' to stop (timeout: $Timeout seconds)..."
            return Wait-PodeServiceStatus -Name $Name -Status Stopped -Timeout $Timeout
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
}


<#
.SYNOPSIS
	Suspend a specified service on Windows systems.

.DESCRIPTION
	The `Suspend-PodeService` function attempts to suspend a specified service by name. This functionality is supported only on Windows systems using `sc.exe`. On Linux and macOS, the suspend functionality for services is not natively available, and an appropriate error message is returned.

.PARAMETER Name
	The name of the service to suspend.

.PARAMETER Async
	Indicates whether to return immediately after issuing the suspend command. If not specified, the function waits until the service reaches the 'Suspended' state.

.PARAMETER Timeout
	The maximum time, in seconds, to wait for the service to reach the 'Suspended' state when not using `-Async`. Defaults to 10 seconds.

.EXAMPLE
	Suspend-PodeService -Name 'MyService'

	Suspends the service named 'MyService' if it is currently running.

.NOTES
	- This function requires administrative/root privileges to execute.
	- Platform-specific behavior:
		- Windows: Uses `sc.exe` with the `pause` argument.
		- Linux: Sends the `SIGTSTP` signal to the service process.
		- macOS: Sends the `SIGTSTP` signal to the service process.
	- On Linux and macOS, an error is logged if the signal command fails or the functionality is unavailable.
	- If the service is already suspended, no action is taken.
	- If the service is not registered, an error is thrown.

#>
function Suspend-PodeService {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch] $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [ValidateRange(1, 300)]
        [int] $Timeout = 10
    )
    try {
        # Ensure administrative/root privileges
        Confirm-PodeAdminPrivilege

        # Get the service status
        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }

        Write-Verbose -Message "Service '$Name' current state: $($service.Status)."

        # Handle the current service state
        switch ($service.Status) {
            'Suspended' {
                Write-Verbose -Message "Service '$Name' is already suspended."
                return $true
            }
            'Running' {
                Write-Verbose -Message "Service '$Name' is currently running. Attempting to suspend..."
            }
            'Stopped' {
                Write-Verbose -Message "Service '$Name' is stopped. Cannot suspend a stopped service."
                return $false
            }
            { $_ -eq 'Starting' -or $_ -eq 'Stopping' -or $_ -eq 'Pausing' -or $_ -eq 'Resuming' } {
                Write-Verbose -Message "Service '$Name' is transitioning state ($($service.Status)). Cannot suspend at this time."
                return $false
            }
            default {
                Write-Verbose -Message "Service '$Name' is in an unknown state ($($service.Status))."
                return $false
            }
        }

        # Suspend the service based on the OS
        $serviceSuspended = $false
        if (Test-PodeIsWindows) {
            $serviceSuspended = Invoke-PodeWinElevatedCommand -Command 'sc.exe' -Arguments "pause '$Name'"
        }
        elseif ($IsLinux -or $IsMacOS) {
            $serviceSuspended = ( Send-PodeServiceSignal -Name $Name -Signal 'SIGTSTP')
        }

        # Check if the service suspend command failed
        if (!$serviceSuspended) {
            throw ($PodeLocale.serviceCommandFailedException -f 'Suspend', $Name)
        }

        # Handle async or wait for suspend
        if ($Async) {
            Write-Verbose -Message "Async mode: Service suspend command issued for '$Name'."
            return $true
        }
        else {
            Write-Verbose -Message "Waiting for service '$Name' to suspend (timeout: $Timeout seconds)..."
            return Wait-PodeServiceStatus -Name $Name -Status Suspended -Timeout $Timeout
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
}


<#
.SYNOPSIS
	Resume a specified service on Windows systems.

.DESCRIPTION
	The `Resume-PodeService` function attempts to resume a specified service by name. This functionality is supported only on Windows systems using `sc.exe`. On Linux and macOS, the resume functionality for services is not natively available, and an appropriate error message is returned.

.PARAMETER Name
	The name of the service to resume.

.PARAMETER Async
	Indicates whether to return immediately after issuing the resume command. If not specified, the function waits until the service reaches the 'Running' state.

.PARAMETER Timeout
	The maximum time, in seconds, to wait for the service to reach the 'Running' state when not using `-Async`. Defaults to 10 seconds.

.EXAMPLE
	Resume-PodeService -Name 'MyService'

	Resumes the service named 'MyService' if it is currently paused.

.NOTES
	- This function requires administrative/root privileges to execute.
	- Platform-specific behavior:
		- Windows: Uses `sc.exe` with the `continue` argument.
		- Linux: Sends the `SIGCONT` signal to the service process.
		- macOS: Sends the `SIGCONT` signal to the service process.
	- On Linux and macOS, an error is logged if the signal command fails or the functionality is unavailable.
	- If the service is not paused, no action is taken.
	- If the service is not registered, an error is thrown.

#>
function Resume-PodeService {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch] $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [ValidateRange(1, 300)]
        [int] $Timeout = 10
    )
    try {
        # Ensure administrative/root privileges
        Confirm-PodeAdminPrivilege

        # Get the service status
        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }

        Write-Verbose -Message "Service '$Name' current state: $($service.Status)."

        # Handle the current service state
        switch ($service.Status) {
            'Running' {
                Write-Verbose -Message "Service '$Name' is already running. No need to resume."
                return $true
            }
            'Suspended' {
                Write-Verbose -Message "Service '$Name' is currently suspended. Attempting to resume..."
            }
            'Stopped' {
                Write-Verbose -Message "Service '$Name' is stopped. Cannot resume a stopped service."
                return $false
            }
            { $_ -eq 'Starting' -or $_ -eq 'Stopping' -or $_ -eq 'Pausing' -or $_ -eq 'Resuming' } {
                Write-Verbose -Message "Service '$Name' is transitioning state ($($service.Status)). Cannot resume at this time."
                return $false
            }
            default {
                Write-Verbose -Message "Service '$Name' is in an unknown state ($($service.Status))."
                return $false
            }
        }

        # Resume the service based on the OS
        $serviceResumed = $false
        if (Test-PodeIsWindows) {
            $serviceResumed = Invoke-PodeWinElevatedCommand -Command 'sc.exe' -Arguments "continue '$Name'"
        }
        elseif ($IsLinux -or $IsMacOS) {
            $serviceResumed = Send-PodeServiceSignal -Name $Name -Signal 'SIGCONT'
        }

        # Check if the service resume command failed
        if (!$serviceResumed) {
            throw ($PodeLocale.serviceCommandFailedException -f 'Resume', $Name)
        }

        # Handle async or wait for resume
        if ($Async) {
            Write-Verbose -Message "Async mode: Service resume command issued for '$Name'."
            return $true
        }
        else {
            Write-Verbose -Message "Waiting for service '$Name' to resume (timeout: $Timeout seconds)..."
            return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
}

<#
.SYNOPSIS
    Unregisters a Pode-based service across different platforms (Windows, Linux, and macOS).

.DESCRIPTION
    The `Unregister-PodeService` function removes a Pode-based service by checking its status and unregistering it from the system.
    The function can stop the service forcefully if it is running, and then remove the service from the service manager.
    It works on Windows, Linux (systemd), and macOS (launchctl).

.PARAMETER Force
    A switch parameter that forces the service to stop before unregistering. If the service is running and this parameter is not specified,
    the function will throw an error.

.PARAMETER Name
    The name of the service.

.EXAMPLE
    Unregister-PodeService -Force

    Unregisters the Pode-based service, forcefully stopping it if it is currently running.

.EXAMPLE
    Unregister-PodeService

    Unregisters the Pode-based service if it is not running. If the service is running, the function throws an error unless the `-Force` parameter is used.

.NOTES
    - The function retrieves the service name from the `srvsettings.json` file located in the script directory.
    - On Windows, it uses `Get-Service`, `Stop-Service`, and `Remove-Service`.
    - On Linux, it uses `systemctl` to stop, disable, and remove the service.
    - On macOS, it uses `launchctl` to stop and unload the service.
#>
function Unregister-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter()]
        [switch]
        $Force
    )

    # Ensure administrative/root privileges
    Confirm-PodeAdminPrivilege

    # Get the service status
    $service = Get-PodeServiceStatus -Name $Name
    if (!$service) {
        throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
    }

    Write-Verbose -Message "Service '$Name' current state: $($service.Status)."

    # Handle service state
    if ($service.Status -ne 'Stopped') {
        if ($Force) {
            Write-Verbose -Message "Service '$Name' is not stopped. Stopping the service due to -Force parameter."
            Stop-PodeService -Name $Name
            Write-Verbose -Message "Service '$Name' has been stopped."
        }
        else {
            Write-Verbose -Message "Service '$Name' is not stopped. Use -Force to stop and unregister it."
            return $false
        }
    }

    if (Test-PodeIsWindows) {

        # Remove the service
        $null = Invoke-PodeWinElevatedCommand -Command  'sc.exe' -Arguments "delete '$Name'"
        if (Get-PodeService -Name $Name -ErrorAction SilentlyContinue) {
            Write-Verbose -Message "Service '$Name' unregistered failed."
            throw ($PodeLocale.serviceUnRegistrationException -f $Name)
        }

        Write-Verbose -Message "Service '$Name' unregistered successfully."

        # Remove the service configuration
        if ($service.PathName -match '"([^"]+)" "([^"]+)"') {
            $argument = $Matches[2]
            if ( (Test-Path -Path ($argument) -PathType Leaf)) {
                Remove-Item -Path ($argument) -ErrorAction SilentlyContinue
            }
        }
        return $true

    }

    elseif ($IsLinux) {
        if (! (Disable-PodeLinuxService -Name $Name)) {
            Write-Verbose -Message "Service '$Name' unregistered failed."
            throw ($PodeLocale.serviceUnRegistrationException -f $Name)
        }

        Write-Verbose -Message "Service '$Name' unregistered successfully."

        # Read the content of the service file
        if ((Test-path -path $service.PathName -PathType Leaf)) {
            $serviceFileContent = & sudo cat $service.PathName
            # Extract the SettingsFile from the ExecStart line using regex
            $execStart = ($serviceFileContent | Select-String -Pattern 'ExecStart=.*\s+(.*)').ToString()
            # Find the index of '/PodeMonitor ' in the string
            $index = $execStart.IndexOf('/PodeMonitor ') + ('/PodeMonitor '.Length)
            # Extract everything after '/PodeMonitor '
            $settingsFile = $execStart.Substring($index).trim('"')

            & sudo rm $settingsFile
            Write-Verbose -Message "Settings file '$settingsFile' removed."

            & sudo rm $service.PathName
            Write-Verbose -Message "Service file '$($service.PathName)' removed."
        }

        # Reload systemd to apply changes
        & sudo systemctl daemon-reload
        Write-Verbose -Message 'Systemd daemon reloaded.'
        return $true
    }

    elseif ($IsMacOS) {
        # Disable and unregister the service
        if (!(Disable-PodeMacOsService -Name $Name)) {
            Write-Verbose -Message "Service '$Name' unregistered failed."
            throw ($PodeLocale.serviceUnRegistrationException -f $Name)
        }

        Write-Verbose -Message "Service '$Name' unregistered successfully."

        # Check if the plist file exists
        if (Test-Path -Path $service.PathName) {
            # Read the content of the plist file
            $plistXml = [xml](Get-Content -Path $service.PathName -Raw)
            if ($plistXml.plist.dict.array.string.Count -ge 2) {
                # Extract the second string in the ProgramArguments array (the settings file path)
                $settingsFile = $plistXml.plist.dict.array.string[1]
                if ($service.Sudo) {
                    & sudo rm $settingsFile
                    Write-Verbose -Message "Settings file '$settingsFile' removed."

                    & sudo rm $service.PathName
                    Write-Verbose -Message "Service file '$($service.PathName)' removed."
                }
                else {
                    Remove-Item -Path $settingsFile -ErrorAction SilentlyContinue
                    Write-Verbose -Message "Settings file '$settingsFile' removed."

                    Remove-Item -Path $service.PathName -ErrorAction SilentlyContinue
                    Write-Verbose -Message "Service file '$($service.PathName)' removed."
                }
            }
        }
    }
}


<#
.SYNOPSIS
    Retrieves the status of a Pode service across different platforms (Windows, Linux, and macOS).

.DESCRIPTION
    The `Get-PodeService` function checks if a Pode-based service is running or stopped on the host system.
    It supports Windows (using `Get-Service`), Linux (using `systemctl`), and macOS (using `launchctl`).
    The function returns a consistent result across all platforms by providing the service name and status in
    a hashtable format. The status is mapped to common states like "Running," "Stopped," "Starting," and "Stopping."

.PARAMETER Name
    The name of the service.

.OUTPUTS
    Hashtable
        The function returns a hashtable containing the service name and its status.
        For example: @{ Name = "MyService"; Status = "Running" }

.EXAMPLE
    Get-PodeService

    Retrieves the current status of the Pode service defined in the `srvsettings.json` configuration file.

.EXAMPLE
    Get-PodeService

    On Windows:
    @{ Name = "MyService"; Status = "Running" }

    On Linux:
    @{ Name = "MyService"; Status = "Stopped" }

    On macOS:
    @{ Name = "MyService"; Status = "Unknown" }

.NOTES
    - The function reads the service name from the `srvsettings.json` file in the script's directory.
    - For Windows, it uses the `Get-Service` cmdlet.
    - For Linux, it uses `systemctl` to retrieve the service status.
    - For macOS, it uses `launchctl` to check if the service is running.
#>
function Get-PodeService {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege
    return Get-PodeServiceStatus -Name $Name
}

<#
.SYNOPSIS
	Restart a Pode service on Windows, Linux, or macOS by sending the appropriate restart signal.

.DESCRIPTION
	The `Restart-PodeService` function handles the restart operation for a Pode service across multiple platforms:
	- Windows: Sends a restart control signal (128) using `sc.exe control`.
	- Linux/macOS: Sends the `SIGHUP` signal to the service's process ID.

.PARAMETER Name
	The name of the Pode service to restart.

.PARAMETER Async
	Indicates whether to return immediately after issuing the restart command. If not specified, the function waits until the service reaches the 'Running' state.

.PARAMETER Timeout
	The maximum time, in seconds, to wait for the service to reach the 'Running' state when not using `-Async`. Defaults to 10 seconds.

.EXAMPLE
	Restart-PodeService -Name "MyPodeService"

	Attempts to restart the Pode service named "MyPodeService" on the current platform.

.EXAMPLE
	Restart-PodeService -Name "AnotherService" -Verbose

	Restarts the Pode service named "AnotherService" with detailed verbose output.

.NOTES
	- This function requires administrative/root privileges to execute.
	- Platform-specific behavior:
		- Windows: Uses `sc.exe control` with the signal `128` to restart the service.
		- Linux/macOS: Sends the `SIGHUP` signal to the service process.
	- If the service is not running or suspended, no restart signal is sent.
	- If the service is not registered, an error is thrown.
	- Errors and logs are captured for debugging purposes.

#>
function Restart-PodeService {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch]
        $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [int]
        $Timeout = 10
    )
    Write-Verbose -Message "Attempting to restart service '$Name' on platform $([System.Environment]::OSVersion.Platform)..."

    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    try {

        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            # Service is not registered
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }

        if ('Running' -ne $service.Status ) {
            Write-Verbose -Message "Service '$Name' is not Running."
            return $false
        }
        if (Test-PodeIsWindows) {

            Write-Verbose -Message "Sending restart (128) signal to service '$Name'."
            if ( Invoke-PodeWinElevatedCommand -Command 'sc control' -Arguments "'$Name' 128") {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
                }
            }
            throw ($PodeLocale.serviceCommandFailedException -f 'sc.exe control {0} 128', $Name)

        }
        elseif ($IsLinux) {
            # Start the service
            if (((Send-PodeServiceSignal -Name $Name -Signal 'SIGHUP'))) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
                }
            }
            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f 'sudo systemctl start', $Name)

        }
        elseif ($IsMacOS) {
            # Start the service
            if (((Send-PodeServiceSignal -Name $Name -Signal 'SIGHUP'))) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
                }
            }
            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f 'sudo systemctl start', $Name)
        }
    }
    catch {
        # Log and display the error
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }

    Write-Verbose -Message "Service '$Name' restart operation completed successfully."
    return $true
}


