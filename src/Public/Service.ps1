<#
.SYNOPSIS
    Registers a new Pode-based PowerShell worker as a service on Windows, Linux, or macOS.

.DESCRIPTION
    The `Register-PodeService` function configures and registers a Pode-based service that runs a PowerShell worker across multiple platforms
    (Windows, Linux, macOS). It creates the service with parameters such as paths to the worker script, log files, and service-specific settings.
    A `srvsettings.json` configuration file is generated and the service can be optionally started after registration.

.PARAMETER Name
    Specifies the name of the service to be registered.

.PARAMETER Description
    A brief description of the service. Defaults to "This is a Pode service."

.PARAMETER DisplayName
    Specifies the display name for the service (Windows only). Defaults to "Pode Service($Name)".

.PARAMETER StartupType
    Specifies the startup type of the service ('Automatic' or 'Manual'). Defaults to 'Automatic'.

.PARAMETER ParameterString
    Any additional parameters to pass to the worker script when the service is run. Defaults to an empty string.

.PARAMETER LogServicePodeHost
    Enables logging for the Pode service host.

.PARAMETER ShutdownWaitTimeMs
    Maximum time in milliseconds to wait for the service to shut down gracefully before forcing termination. Defaults to 30,000 milliseconds.

.PARAMETER StartMaxRetryCount
    The maximum number of retries to start the PowerShell process before giving up.  Default is 3 retries.

.PARAMETER StartRetryDelayMs
    The delay (in milliseconds) between retry attempts to start the PowerShell process. Default is 5,000 milliseconds (5 seconds).

.PARAMETER WindowsUser
    Specifies the username under which the service will run by default is the current user (Windows only).

.PARAMETER LinuxUser
    Specifies the username under which the service will run by default is the current user (Linux Only).

.PARAMETER Agent
    A switch to create an Agent instead of a Daemon in MacOS (MacOS Only).

.PARAMETER Start
    A switch to start the service immediately after registration.

.PARAMETER Password
    A secure password for the service account (Windows only). If omitted, the service account will be 'NT AUTHORITY\SYSTEM'.

.PARAMETER SecurityDescriptorSddl
    A security descriptor in SDDL format, specifying the permissions for the service (Windows only).

.PARAMETER SettingsPath
    Specifies the directory to store the service configuration file (`<name>_svcsettings.json`). If not provided, a default directory is used.

.PARAMETER LogPath
    Specifies the path for the service log files. If not provided, a default log directory is used.

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

        [string]
        $Description = 'This is a Pode service.',

        [string]
        $DisplayName = "Pode Service($Name)",

        [string]
        [validateset('Manual', 'Automatic')]
        $StartupType = 'Automatic',

        [string]
        $SecurityDescriptorSddl,

        [string]
        $ParameterString = '',

        [switch]
        $LogServicePodeHost,

        [int]
        $ShutdownWaitTimeMs = 30000,

        [int]
        $StartMaxRetryCount = 3,

        [int]
        $StartRetryDelayMs = 5000,

        [string]
        $WindowsUser,

        [string]
        $LinuxUser,

        [switch]
        $Start,

        [switch]
        $Agent,

        [securestring]
        $Password,

        [string]
        $SettingsPath,

        [string]
        $LogPath
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
            }
        }

        # Save JSON to the settings file
        $jsonContent | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8

        # Determine OS architecture and call platform-specific registration functions
        $osArchitecture = ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture).ToString().ToLower()

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
            $operation = Register-PodeMonitorWindowsService  @param
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
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch]
        $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [int]
        $Timeout = 10
    )
    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    try {

        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            # Service is not registered
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }
        if ($service.Status -eq 'Running') {
            Write-Verbose -Message "Service '$Name' is already Running."
            return $true
        }
        if ($service.Status -ne 'Stopped') {
            Write-Verbose -Message "Service '$Name' is not Stopped."
            return $false
        }

        if (Test-PodeIsWindows) {
            if ( Invoke-PodeWinElevatedCommand  -Command 'sc.exe' -Arguments "start '$Name'") {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
                }
            }

            throw ($PodeLocale.serviceCommandFailedException -f 'sc.exe start {0}', $Name)

        }
        elseif ($IsLinux) {
            # Start the service
            if ((Start-PodeLinuxService -Name $Name)) {
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
            if ((Start-PodeMacOsService -Name $Name)) {
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
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
    return $true
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
        [int]
        $Timeout = 10
    )
    try {
        # Ensure the script is running with the necessary administrative/root privileges.
        # Exits the script if the current user lacks the required privileges.
        Confirm-PodeAdminPrivilege

        if (Test-PodeIsWindows) {

            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is running
                if ($service.Status -eq 'Running' -or $service.Status -eq 'Paused') {
                    if ( Invoke-PodeWinElevatedCommand  -Command 'sc.exe' -Arguments "stop '$Name'") {
                        if ($Async) {
                            return $true
                        }
                        else {
                            return Wait-PodeServiceStatus -Name $Name -Status Stopped -Timeout $Timeout
                        }
                    }
                    # Service command '{0}' failed on service '{1}'.
                    throw ($PodeLocale.serviceCommandFailedException -f 'sc.exe stop', $Name)
                }
                else {
                    Write-Verbose -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
            }
        }
        elseif ($IsLinux) {
            #Stop the service
            if (( Stop-PodeLinuxService -Name $Name)) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Stopped -Timeout $Timeout
                }
            }

            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f 'sudo systemctl stop', $Name)
        }
        elseif ($IsMacOS) {
            if ((Stop-PodeMacOsService $Name)) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Stopped -Timeout $Timeout
                }
            }
            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f 'launchctl stop', $Name)
        }

    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
    return $true
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
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch]
        $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [int]
        $Timeout = 10
    )
    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    try {

        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            # Service is not registered
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }
        if ($service.Status -eq 'Suspended') {
            Write-Verbose -Message "Service '$Name' is already suspended."
            return $true
        }
        if ($service.Status -ne 'Running') {
            Write-Verbose -Message "Service '$Name' is not running."
            return $false
        }
        if (Test-PodeIsWindows) {
            if (( Invoke-PodeWinElevatedCommand -Command 'sc.exe' -Arguments "pause '$Name'")) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Suspended -Timeout $Timeout
                }
            }

            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f 'sc.exe pause', $Name)
        }
        elseif ($IsLinux) {
            if (( Send-PodeServiceSignal -Name $Name -Signal 'SIGTSTP')) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Paused -Timeout $Timeout
                }
            }

            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f ' sudo /bin/kill -SIGTSTP', $Name)
        }
        elseif ($IsMacOS) {
            if (( Send-PodeServiceSignal -Name $Name -Signal 'SIGTSTP')) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Paused -Timeout $Timeout
                }
            }

            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f '/bin/kill -SIGTSTP  ', $Name)
        }
    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
    return $true
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
        [string]
        $Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Async')]
        [switch]
        $Async,

        [Parameter(Mandatory = $false, ParameterSetName = 'Async')]
        [int]
        $Timeout = 10
    )
    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    try {

        $service = Get-PodeServiceStatus -Name $Name
        if (!$service) {
            # Service is not registered
            throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
        }

        if ($service.Status -ne 'Paused') {
            Write-Verbose -Message "Service '$Name' is not Suspended."
            return $false
        }
        if (Test-PodeIsWindows) {
            if ((  Invoke-PodeWinElevatedCommand  -Command 'sc.exe' -Arguments "continue '$Name'")) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
                }
            }
            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f 'sc.exe continue', $Name)
        }
        elseif ($IsLinux) {
            if (( Send-PodeServiceSignal -Name $Name -Signal 'SIGCONT')) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
                }
            }

            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f ' sudo /bin/kill -SIGCONT', $Name)
        }
        elseif ($IsMacOS) {
            if (( Send-PodeServiceSignal -Name $Name -Signal 'SIGCONT')) {
                if ($Async) {
                    return $true
                }
                else {
                    return Wait-PodeServiceStatus -Name $Name -Status Running -Timeout $Timeout
                }
            }

            # Service command '{0}' failed on service '{1}'.
            throw ($PodeLocale.serviceCommandFailedException -f '/bin/kill -SIGCONT  ', $Name)
        }

    }
    catch {
        $_ | Write-PodeErrorLog
        Write-Error -Exception $_.Exception
        return $false
    }
    return $true
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
        [Parameter()]
        [switch]$Force,

        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    if (Test-PodeIsWindows) {
        # Check if the service exists
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $service) {
            # Service is not registered
            throw ($PodeLocale.serviceIsNotRegisteredException -f "$Name")
        }

        try {
            $pathName = $service.BinaryPathName
            # Check if the service is running before attempting to stop it
            if ($service.Status -eq 'Running') {
                if ($Force.IsPresent) {
                    $null = Invoke-PodeWinElevatedCommand -Command 'Stop-Service' -Arguments "-Name '$Name'"
                    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                    if ($service.Status -eq 'Stopped') {
                        Write-Verbose -Message "Service '$Name' stopped forcefully."
                    }
                    else {
                        # Service command '{0}' failed on service '{1}'.
                        throw ($PodeLocale.serviceCommandFailedException -f 'Stop-Service', $Name)
                    }
                }
                else {
                    # Service is running. Use the -Force parameter to forcefully stop."
                    throw ($Podelocale.serviceIsRunningException -f $Name )
                }
            }

            # Remove the service
            $null = Invoke-PodeWinElevatedCommand -Command  'sc.exe' -Arguments "delete '$Name'"
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $service) {
                Write-Verbose -Message "Service '$Name' unregistered failed."
                throw ($PodeLocale.serviceUnRegistrationException -f $Name)
            }
            Write-Verbose -Message "Service '$Name' unregistered successfully."

            # Remove the service configuration
            if ($pathName) {
                $binaryPath = $pathName.trim('"').split('" "')
                if ((Test-Path -Path ($binaryPath[1]) -PathType Leaf)) {
                    Remove-Item -Path ($binaryPath[1]) -ErrorAction Break
                }
            }
            return $true

        }
        catch {
            $_ | Write-PodeErrorLog
            Write-Error -Exception $_.Exception
            return $false
        }
    }

    elseif ($IsLinux) {
        try {
            # Check if the service is already registered
            if ((Test-PodeLinuxServiceIsRegistered $Name)) {
                # Check if the service is active
                if ((Test-PodeLinuxServiceIsActive -Name  $Name)) {
                    if ($Force.IsPresent) {
                        #Stop the service
                        if (( Stop-PodeLinuxService -Name $Name)) {
                            # Check if the service is active
                            if (!(Test-PodeLinuxServiceIsActive -Name  $Name)) {
                                Write-Verbose -Message "Service '$Name' stopped successfully."
                            }
                            else {
                                # Service command '{0}' failed on service '{1}'.
                                throw ($PodeLocale.serviceCommandFailedException -f 'sudo systemctl stop', $Name)
                            }
                        }
                        else {
                            # Service command '{0}' failed on service '{1}'.
                            throw ($PodeLocale.serviceCommandFailedException -f 'sudo systemctl stop', $Name)
                        }
                    }
                    else {
                        # Service is running. Use the -Force parameter to forcefully stop."
                        throw ($Podelocale.serviceIsRunningException -f $Name)
                    }
                }
                if ((Disable-PodeLinuxService -Name $Name)) {
                    # Read the content of the service file
                    $serviceFilePath = "/etc/systemd/system/$(Get-PodeRealServiceName -Name $Name)"
                    if ((Test-path -path $serviceFilePath -PathType Leaf)) {
                        $serviceFileContent = sudo cat $serviceFilePath

                        # Extract the SettingsFile from the ExecStart line using regex
                        $execStart = ($serviceFileContent | Select-String -Pattern 'ExecStart=.*\s+(.*)').ToString()
                        # Find the index of '/PodeMonitor ' in the string
                        $index = $execStart.IndexOf('/PodeMonitor ') + ('/PodeMonitor '.Length)
                        # Extract everything after '/PodeMonitor '
                        $settingsFile = $execStart.Substring($index)
                        if ((Test-Path -Path $settingsFile -PathType Leaf)) {
                            Remove-Item -Path $settingsFile
                        }
                        sudo rm $serviceFilePath

                        Write-Verbose -Message "Service '$Name' unregistered successfully."
                    }
                    sudo systemctl daemon-reload
                }
                else {
                    Write-Verbose -Message "Service '$Name' unregistered failed."
                    throw ($PodeLocale.serviceUnRegistrationException -f $Name)
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name )
            }
            return $true
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-Error -Exception $_.Exception
            return $false
        }
    }

    elseif ($IsMacOS) {
        try {
            # Check if the service is already registered
            if (Test-PodeMacOsServiceIsRegistered $Name) {
                # Check if the service is active
                if ((Test-PodeMacOsServiceIsActive -Name  $Name)) {
                    if ($Force.IsPresent) {
                        #Stop the service
                        if (( Stop-PodeMacOsService -Name $Name)) {
                            # Check if the service is active
                            if (!(Test-PodeMacOsServiceIsActive -Name  $Name)) {
                                Write-Verbose -Message "Service '$Name' stopped successfully."
                            }
                            else {
                                # Service command '{0}' failed on service '{1}'.
                                throw ($PodeLocale.serviceCommandFailedException -f 'launchctl stop', $Name)
                            }
                        }
                        else {
                            # Service command '{0}' failed on service '{1}'.
                            throw ($PodeLocale.serviceCommandFailedException -f 'launchctl stop', $Name)
                        }
                    }
                    else {
                        # Service is running. Use the -Force parameter to forcefully stop."
                        throw ($Podelocale.serviceIsRunningException -f $Name)
                    }
                }

                if ((Disable-PodeMacOsService -Name $Name)) {
                    $sudo = !(Test-Path -Path "$($HOME)/Library/LaunchAgents/$(Get-PodeRealServiceName -Name $Name).plist" -PathType Leaf)
                    if ($sudo) {
                        $plistFilePath = "/Library/LaunchDaemons/$(Get-PodeRealServiceName -Name $Name).plist"
                    }
                    else {
                        $plistFilePath = "$HOME/Library/LaunchAgents/$(Get-PodeRealServiceName -Name $Name).plist"
                    }
                    #Check if the plist file exists
                    if (Test-Path -Path $plistFilePath) {
                        # Read the content of the plist file
                        $plistXml = [xml](Get-Content -Path $plistFilePath -Raw)

                        # Extract the second string in the ProgramArguments array (the settings file path)
                        $settingsFile = $plistXml.plist.dict.array.string[1]

                        if ((Test-Path -Path $settingsFile -PathType Leaf)) {
                            Remove-Item -Path $settingsFile
                        }

                        Remove-Item -Path $plistFilePath -ErrorAction Break

                        Write-Verbose -Message "Service '$Name' unregistered successfully."
                    }
                }
                else {
                    Write-Verbose -Message "Service '$Name' unregistered failed."
                    throw ($PodeLocale.serviceUnRegistrationException -f $Name)
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name )
            }
            return $true
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-Error -Exception $_.Exception
            return $false
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

        if (@('Running', 'Suspended' ) -inotcontains $service.Status ) {
            Write-Verbose -Message "Service '$Name' is not Running or Suspended."
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
