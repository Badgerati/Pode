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

.PARAMETER UserName
    Specifies the username under which the service will run by default is the current user.

.PARAMETER CreateUser
    A switch create the user if it does not exist (Linux Only).

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
        $UserName,

        [switch]
        $CreateUser,

        [switch]
        $Start,

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

        if ([string]::IsNullOrEmpty($UserName)) {
            if ($IsWindows) {
                if ( ($null -ne $Password)) {
                    $UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                }
            }
            else {
                $UserName = [System.Environment]::UserName
            }

        }
        else {
            if ($IsWindows -and ($null -eq $Password)) {
                throw ($Podelocale.passwordRequiredForServiceUserException -f $UserName)
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

        if ($IsWindows) {
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
                CreateUser     = $CreateUser
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
    Starts a Pode-based service across different platforms (Windows, Linux, and macOS).

.DESCRIPTION
    The `Start-PodeService` function checks if a Pode-based service is already running, and if not, it starts the service.
    It works on Windows, Linux (systemd), and macOS (launchctl), handling platform-specific service commands to start the service.
    If the service is not registered, it will throw an error.

.PARAMETER Name
    The name of the service.

.EXAMPLE
    Start-PodeService

    Starts the Pode-based service if it is not currently running.

.NOTES
    - The function retrieves the service name from the `srvsettings.json` file located in the script directory.
    - On Windows, it uses `Get-Service` and `Start-Service` to manage the service.
    - On Linux, it uses `systemctl` to manage the service.
    - On macOS, it uses `launchctl` to manage the service.
    - If the service is already running, no action is taken.
    - If the service is not registered, the function throws an error.
#>
function Start-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    try {

        if ($IsWindows) {

            # Get the Windows service
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is already running
                if ($service.Status -ne 'Running') {
                    $null = Invoke-PodeWinElevatedCommand  -Command  'Start-Service' -Arguments "-Name '$Name'"

                    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                    if ($service.Status -eq 'Running') {
                        Write-Verbose -Message "Service '$Name' started successfully."
                    }
                    else {
                        throw ($PodeLocale.serviceCommandFailedException -f 'Start-Service', $Name)
                    }
                }
                else {
                    # Log service is already running
                    Write-Verbose -Message "Service '$Name' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
            }
        }

        elseif ($IsLinux) {
            $nameService = "$Name.service".Replace(' ', '_')
            # Check if the service exists
            if ((Test-PodeLinuxServiceIsRegistered $nameService)) {
                # Check if the service is already running
                if (!(Test-PodeLinuxServiceIsActive -Name $nameService)) {
                    # Start the service
                    if ((Start-PodeLinuxService -Name $nameService)) {
                        # Check if the service is active
                        if ((Test-PodeLinuxServiceIsActive -Name $nameService)) {
                            Write-Verbose -Message "Service '$nameService' started successfully."
                            return $true
                        }
                    }
                    # Service command '{0}' failed on service '{1}'.
                    throw ($PodeLocale.serviceCommandFailedException -f 'sudo systemctl start', $nameService)
                }
                else {
                    # Log service is already running
                    Write-Verbose -Message "Service '$nameService' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService)
            }
        }

        elseif ($IsMacOS) {
            $nameService = "pode.$Name.service".Replace(' ', '_')
            # Check if the service exists
            if ((Test-PodeMacOsServiceIsRegistered $nameService)) {
                # Check if the service is already running
                if (!(Test-PodeMacOsServiceIsActive -Name $nameService)) {
                    # Start the service
                    if ((Start-PodeMacOsService -Name $nameService)) {
                        # Check if the service is active
                        if ((Test-PodeMacOsServiceIsActive -Name $nameService)) {
                            Write-Verbose -Message "Service '$nameService' started successfully."
                            return $true
                        }
                    }
                    # Service command '{0}' failed on service '{1}'.
                    throw ($PodeLocale.serviceCommandFailedException -f 'sudo systemctl start', $nameService)
                }
                else {
                    # Log service is already running
                    Write-Verbose -Message "Service '$nameService' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService )
            }
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
    Stops a Pode-based service across different platforms (Windows, Linux, and macOS).

.DESCRIPTION
    The `Stop-PodeService` function stops a Pode-based service by checking if it is currently running.
    If the service is running, it will attempt to stop the service gracefully.
    The function works on Windows, Linux (systemd), and macOS (launchctl).

.PARAMETER Name
    The name of the service.

.EXAMPLE
    Stop-PodeService

    Stops the Pode-based service if it is currently running. If the service is not running, no action is taken.

.NOTES
    - The function retrieves the service name from the `srvsettings.json` file located in the script directory.
    - On Windows, it uses `Get-Service` and `Stop-Service`.
    - On Linux, it uses `systemctl` to stop the service.
    - On macOS, it uses `launchctl` to stop the service.
    - If the service is not registered, the function throws an error.
#>
function Stop-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    try {
        # Ensure the script is running with the necessary administrative/root privileges.
        # Exits the script if the current user lacks the required privileges.
        Confirm-PodeAdminPrivilege

        if ($IsWindows) {

            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is running
                if ($service.Status -eq 'Running' -or $service.Status -eq 'Paused') {
                    $null = Invoke-PodeWinElevatedCommand  -Command  'Stop-Service' -Arguments "-Name '$Name'"
                    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                    if ($service.Status -eq 'Stopped') {
                        Write-Verbose -Message "Service '$Name' stopped successfully."
                    }
                    else {
                        # Service command '{0}' failed on service '{1}'.
                        throw ($PodeLocale.serviceCommandFailedException -f 'Stop-Service', $Name)
                    }
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
            $nameService = "$Name.service".Replace(' ', '_')
            # Check if the service is already registered
            if ((Test-PodeLinuxServiceIsRegistered -Name $nameService)) {
                # Check if the service is active
                if ((Test-PodeLinuxServiceIsActive -Name  $nameService)) {
                    #Stop the service
                    if (( Stop-PodeLinuxService -Name $Name)) {
                        # Check if the service is active
                        if (!(Test-PodeLinuxServiceIsActive -Name  $nameService)) {
                            Write-Verbose -Message "Service '$Name' stopped successfully."
                            return $true
                        }
                    }

                    # Service command '{0}' failed on service '{1}'.
                    throw ($PodeLocale.serviceCommandFailedException -f 'sudo launchctl stop', $Name)
                }
                else {
                    Write-Verbose -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService)
            }

        }
        elseif ($IsMacOS) {
            $nameService = "pode.$Name.service".Replace(' ', '_')
            # Check if the service is already registered
            if ((Test-PodeMacOsServiceIsRegistered -Name $nameService)) {
                # Check if the service is active
                if ((Test-PodeMacOsServiceIsActive $nameService)) {
                    if ((Stop-PodeMacOsService $Name)) {
                        for($i=0;$i -lt 30; $i++){
                            if (!(Test-PodeMacOsServiceIsActive -Name  $nameService)) {
                                Write-Verbose -Message "Service '$Name' stopped successfully."
                                return $true
                            }
                            Start-Sleep 1
                        }
                    }
                    # Service command '{0}' failed on service '{1}'.
                    throw ($PodeLocale.serviceCommandFailedException -f 'launchctl stop', $Name)

                }
                else {
                    Write-Verbose -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService )
            }
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
    Suspends a specified service on Windows systems.

.DESCRIPTION
    This function attempts to suspend a service by name. It is supported only on Windows systems.
    On Linux and macOS, the suspend functionality for services is not available and an appropriate error message is returned.

.PARAMETER Name
    The name of the service to suspend.

.EXAMPLE
    Suspend-PodeService -Name 'MyService'

.NOTES
    - This function requires administrative/root privileges to execute. On non-Windows platforms, an error is logged indicating that this feature is not supported.
    - This function supports Windows only.
#>
function Suspend-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    try {
        # Ensure the script is running with the necessary administrative/root privileges.
        # Exits the script if the current user lacks the required privileges.
        Confirm-PodeAdminPrivilege

        if ($IsWindows) {
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is running
                if ($service.Status -eq 'Running') {
                    $null = Invoke-PodeWinElevatedCommand -Command 'Suspend-Service' -Arguments "-Name '$Name'"
                    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                    if ($service.Status -eq 'Paused') {
                        Write-Verbose -Message "Service '$Name' suspended successfully."
                    }
                    else {
                        # Service command '{0}' failed on service '{1}'.
                        throw ($PodeLocale.serviceCommandFailedException -f 'Suspend-Service', $Name)
                    }
                }
                else {
                    Write-Verbose -Message "Service '$Name' is not running."
                    return $false
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
            }
        }
        elseif ($IsLinux -or $IsMacOS) {
            return Send-PodeServiceSignal -Name $Name -Signal 'SIGTSTP'
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
    Resumes a specified service on Windows systems.

.DESCRIPTION
    This function attempts to resume a service by name. It is supported only on Windows systems.
    On Linux and macOS, the resume functionality for services is not available, and an appropriate error message is returned.

.PARAMETER Name
    The name of the service to resume.

.EXAMPLE
    Resume-PodeService -Name 'MyService'

.NOTES
    - This function requires administrative/root privileges to execute. On non-Windows platforms, an error is logged indicating that this feature is not supported.
    - This function supports Windows only.
#>
function Resume-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    try {
        # Ensure the script is running with the necessary administrative/root privileges.
        # Exits the script if the current user lacks the required privileges.
        Confirm-PodeAdminPrivilege
        if ($IsWindows) {

            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is running
                if ($service.Status -eq 'Paused') {
                    $null = Invoke-PodeWinElevatedCommand  -Command  'Resume-Service' -Arguments "-Name '$Name'"
                    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                    if ($service.Status -eq 'Running') {
                        Write-Verbose -Message "Service '$Name' Resumed successfully."
                    }
                    else {
                        # Service command '{0}' failed on service '{1}'.
                        throw ($PodeLocale.serviceCommandFailedException -f 'Resume-Service', $Name)
                    }
                }
                else {
                    Write-Verbose -Message "Service '$Name' is not suspended."
                    return $false
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
            }
        }
        elseif ($IsLinux -or $IsMacOS) {
           return Send-PodeServiceSignal -Name $Name -Signal 'SIGCONT'
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

    if ($IsWindows) {
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
                    throw ($Podelocale.serviceIsRunningException -f $nameService )
                }
            }

            # Remove the service
            $null = Invoke-PodeWinElevatedCommand -Command  'Remove-Service' -Arguments "-Name '$Name'"
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
            $nameService = "$Name.service".Replace(' ', '_')
            # Check if the service is already registered
            if ((Test-PodeLinuxServiceIsRegistered $nameService)) {
                # Check if the service is active
                if ((Test-PodeLinuxServiceIsActive -Name  $nameService)) {
                    if ($Force.IsPresent) {
                        #Stop the service
                        if (( Stop-PodeLinuxService -Name $Name)) {
                            # Check if the service is active
                            if (!(Test-PodeLinuxServiceIsActive -Name  $nameService)) {
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
                        throw ($Podelocale.serviceIsRunningException -f $nameService)
                    }
                }
                if ((Disable-PodeLinuxService -Name $nameService)) {
                    # Read the content of the service file
                    $serviceFilePath = "/etc/systemd/system/$nameService"
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
                throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService )
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
            $nameService = "pode.$Name.service".Replace(' ', '_')
            # Check if the service is already registered
            if (Test-PodeMacOsServiceIsRegistered $nameService) {
                # Check if the service is active
                if ((Test-PodeMacOsServiceIsActive -Name  $nameService)) {
                    if ($Force.IsPresent) {
                        #Stop the service
                        if (( Stop-PodeMacOsService -Name $Name)) {
                            # Check if the service is active
                            if (!(Test-PodeMacOsServiceIsActive -Name  $nameService)) {
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
                        throw ($Podelocale.serviceIsRunningException -f $nameService)
                    }
                }

                if ((Disable-PodeMacOsService -Name $nameService)) {
                    $plistFilePath = "$HOME/Library/LaunchAgents/$nameService.plist"
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
                throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService )
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
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )
    # Ensure the script is running with the necessary administrative/root privileges.
    # Exits the script if the current user lacks the required privileges.
    Confirm-PodeAdminPrivilege

    if ($IsWindows) {
        # Check if the service exists on Windows
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'"

        if ($service) {
            switch ($service.State) {
                'Running' { $status = 'Running' }
                'Stopped' { $status = 'Stopped' }
                'Paused' { $status = 'Paused' }
                'StartPending' { $status = 'Starting' }
                'StopPending' { $status = 'Stopping' }
                'PausePending' { $status = 'Pausing' }
                'ContinuePending' { $status = 'Resuming' }
                default { $status = 'Unknown' }
            }
            return @{
                Name   = $Name
                Status = $status
                Pid    = $service.ProcessId
                Sudo   = $true
            }
        }
        else {
            Write-Verbose -Message "Service '$Name' not found."
            return $null
        }
    }

    elseif ($IsLinux) {
        try {
            $nameService = "$Name.service".Replace(' ', '_')
            # Check if the service exists on Linux (systemd)
            if ((Test-PodeLinuxServiceIsRegistered -Name $nameService)) {
                $servicePid = 0
                $status = $(systemctl show -p ActiveState $nameService | awk -F'=' '{print $2}')

                switch ($status) {
                    'active' {
                        $servicePid = $(systemctl show -p MainPID $nameService | awk -F'=' '{print $2}')
                        $status = 'Running'
                    }
                    'reloading' {
                        $servicePid = $(systemctl show -p MainPID $nameService | awk -F'=' '{print $2}')
                        $status = 'Running'
                    }
                    'maintenance' {
                        $servicePid = $(systemctl show -p MainPID $nameService | awk -F'=' '{print $2}')
                        $status = 'Paused'
                    }
                    'inactive' {
                        $status = 'Stopped'
                    }
                    'failed' {
                        $status = 'Stopped'
                    }
                    'activating' {
                        $servicePid = $(systemctl show -p MainPID $nameService | awk -F'=' '{print $2}')
                        $status = 'Starting'
                    }
                    'deactivating' {
                        $status = 'Stopping'
                    }
                    default {
                        $status = 'Stopped'
                    }
                }
                return @{
                    Name   = $Name
                    Status = $status
                    Pid    = $servicePid
                    Sudo   = $true
                }
            }
            else {
                Write-Verbose -Message "Service '$nameService' not found."
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-Error -Exception $_.Exception
            return $null
        }
    }

    elseif ($IsMacOS) {
        try {
            $nameService = "pode.$Name.service".Replace(' ', '_')
            # Check if the service exists on macOS (launchctl)
            if ((Test-PodeMacOsServiceIsRegistered $nameService )) {
                $servicePid = Get-PodeMacOsServicePid -Name $nameService # Extract the PID from the match

                $sudo = !(Test-Path -Path "$($HOME)/Library/LaunchAgents/$($nameService).plist" -PathType Leaf)
                # Check if the service has a PID entry
                if ($servicePid -ne 0) {
                    return @{
                        Name   = $Name
                        Status = 'Running'
                        Pid    = $servicePid
                        Sudo   = $sudo
                    }
                }
                else {
                    return @{
                        Name   = $Name
                        Status = 'Stopped'
                        Pid    = 0
                        Sudo   = $sudo
                    }
                }
            }
            else {
                Write-Verbose -Message "Service '$Name' not found."
                return $null
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            Write-Error -Exception $_.Exception
            return $null
        }
    }
}

<#
.SYNOPSIS
    Restarts a Pode service on Windows, Linux, or macOS by sending the appropriate restart signal.

.DESCRIPTION
    This function handles the restart operation for a Pode service across multiple platforms:
    - On Windows: Sends a restart control signal (128) using `sc control`.
    - On Linux and macOS: Sends the `SIGHUP` signal to the service's process ID.

.PARAMETER Name
    The name of the Pode service to restart.

.NOTES
    Requires administrative/root privileges to execute service operations.

    This function leverages platform-specific methods:
    - Windows: Uses `sc control` for service control commands.
    - Linux/macOS: Uses `/bin/kill -SIGHUP` to signal the service's process.

    For services not running, a verbose message is displayed, and no restart signal is sent.

.EXAMPLE
    Restart-PodeService -Name "MyPodeService"

    Attempts to restart the Pode service named "MyPodeService" on the current platform.

.EXAMPLE
    Restart-PodeService -Name "AnotherService" -Verbose

    Restarts the Pode service named "AnotherService" with detailed verbose output.

#>
function Restart-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    try {
        # Ensure the script is running with the necessary administrative/root privileges.
        # Exits the script if the current user lacks the required privileges.
        Confirm-PodeAdminPrivilege

        Write-Verbose -Message "Attempting to restart service '$Name' on platform $([System.Environment]::OSVersion.Platform)..."

        if ($IsWindows) {
            # Handle Windows-specific restart logic
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.Status -eq 'Running' -or $service.Status -eq 'Paused') {
                    Write-Verbose -Message "Sending restart (128) signal to service '$Name'."
                    $null = Invoke-PodeWinElevatedCommand -Command 'sc control' -Arguments "'$Name' 128"
                    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                    Write-Verbose -Message "Service '$Name' restart signal sent successfully."
                }
                else {
                    Write-Verbose -Message "Service '$Name' is not running."
                    return $false
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
            }
        }
        elseif ($IsLinux -or $IsMacOS) {
            if ( !(Send-PodeServiceSignal -Name $Name -Signal 'SIGHUP')) {
                Write-Verbose -Message "Service '$Name' is not running."
                return $false
            }
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
