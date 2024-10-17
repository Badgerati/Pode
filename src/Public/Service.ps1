<#
.SYNOPSIS
    Registers a new service to run a Pode-based PowerShell worker as a service on multiple platforms.

.DESCRIPTION
    The `Register-PodeService` function configures and registers a service for running a Pode-based PowerShell worker on Windows, Linux, or macOS.
    It dynamically sets up the service with the specified parameters, including paths to the script, log files, PowerShell executable,
    and service settings. It also generates a `srvsettings.json` file containing the service's configuration and registers the service
    using platform-specific methods.

.PARAMETER Name
    The name of the service to be registered.

.PARAMETER Description
    A brief description of the service. Defaults to "This is a Pode service."

.PARAMETER DisplayName
    The display name of the service, as it will appear in the Windows Services Manager (Windows only). Defaults to "Pode Service($Name)".

.PARAMETER StartupType
    The startup type of the service (e.g., Automatic, Manual). Defaults to 'Automatic'.

.PARAMETER SecurityDescriptorSddl
    The security descriptor in SDDL format for the service (Windows only).

.PARAMETER ParameterString
    Any additional parameters to pass to the script when it is run by the service. Defaults to an empty string.

.PARAMETER Quiet
    A boolean value indicating whether to run the service quietly, suppressing logs and output. Defaults to `$true`.

.PARAMETER DisableTermination
    A boolean value indicating whether to disable termination of the service from within the worker process. Defaults to `$true`.

.PARAMETER ShutdownWaitTimeMs
    The maximum amount of time, in milliseconds, to wait for the service to gracefully shut down before forcefully terminating it. Defaults to 30,000 milliseconds.

.PARAMETER User
    The user under which the service should run. Defaults to `podeuser`.

.PARAMETER Group
    The group under which the service should run (Linux only). Defaults to `podeuser`.

.PARAMETER Start
    A switch to start the service immediately after it is registered.

.PARAMETER SkipUserCreation
    A switch to skip the user creation process (Linux only).

.PARAMETER Credential
    A `PSCredential` object specifying the credentials for the account under which the Windows service will run.

.EXAMPLE
    Register-PodeService -Name "PodeExampleService" -Description "Example Pode Service" -ParameterString "-Verbose"

    Registers a new Pode-based service called "PodeExampleService" with verbose logging enabled.

.NOTES
    - This function is cross-platform and handles service registration on Windows, Linux, and macOS.
    - A `srvsettings.json` file is generated in the same directory as the main script, containing the configuration for the Pode service.
    - The function checks if a service with the specified name already exists on the respective platform and throws an error if it does.
    - For Windows, the service binary path points to the Pode monitor executable (`PodeMonitor.exe`), which is located in the `Bin` directory relative to the script.
    - This function dynamically determines the PowerShell executable path and system architecture.
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

        [bool]
        $Quiet = $true,

        [bool]
        $DisableTermination = $true,

        [int]
        $ShutdownWaitTimeMs = 30000,

        [string]
        $User = 'podeuser',

        [string]
        $Group = 'podeuser',

        [switch]
        $Start,

        [switch]
        $SkipUserCreation,

        [pscredential]
        $Credential
    )

    if ($MyInvocation.ScriptName) {
        $ScriptPath = $MyInvocation.ScriptName
        $MainScriptPath = Split-Path -Path $ScriptPath -Parent
        #    $MainScriptFileName = Split-Path -Path $ScriptPath -Leaf
    }
    else {
        return $null
    }

    # Define script and log file paths
    # $ScriptPath = Join-Path -Path $MainScriptPath -ChildPath $MainScriptFileName # Example script path
    $LogPath = Join-Path -Path $MainScriptPath -ChildPath '/logs'
    $LogFilePath = Join-Path -Path $LogPath -ChildPath "$($Name)_svc.log"

    # Ensure log directory exists
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force
    }

    # Obtain the PowerShell path dynamically
    $PwshPath = (Get-Process -Id $PID).Path

    # Define the settings file path
    $settingsFile = Join-Path -Path $MainScriptPath -ChildPath 'srvsettings.json'

    $binPath = Join-Path -path (Split-Path -Parent -Path $PSScriptRoot) -ChildPath 'Bin'

    # JSON content for the service settings
    $jsonContent = @{
        PodePwshWorker = @{
            ScriptPath         = $ScriptPath
            PwshPath           = $PwshPath
            ParameterString    = $ParameterString
            LogFilePath        = $LogFilePath
            Quiet              = $Quiet
            DisableTermination = $DisableTermination
            ShutdownWaitTimeMs = $ShutdownWaitTimeMs
            Name               = $Name
        }
    }

    # Convert hash table to JSON and save it to the settings file
    $jsonContent | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8

    $osArchitecture = ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture).ToString().ToLower()

    # Call the appropriate platform-specific function
    switch ([System.Environment]::OSVersion.Platform) {
        Win32NT {
            $param = @{
                Name                   = $Name
                Description            = $Description
                DisplayName            = $DisplayName
                StartupType            = $StartupType
                BinPath                = $binPath
                SettingsFile           = $settingsFile
                Credential             = $Credential
                SecurityDescriptorSddl = $SecurityDescriptorSddl
                Start                  = $Start
                OsArchitecture         = $osArchitecture
            }
            Register-PodeWindowsService  @param
        }

        Unix {
            $param = @{
                Name             = $Name
                Description      = $Description
                BinPath          = $binPath
                SettingsFile     = $settingsFile
                User             = $User
                Group            = $Group
                Start            = $Start
                SkipUserCreation = $SkipUserCreation
                OsArchitecture   = $osArchitecture
            }
            Register-PodeLinuxService @param
        }

        MacOSX {
            $param = @{
                Name           = $Name
                Description    = $Description
                BinPath        = $binPath
                SettingsFile   = $settingsFile
                User           = $User
                Start          = $Start
                OsArchitecture = $osArchitecture
            }


            Register-PodeMacService @param
        }
    }
}


<#
.SYNOPSIS
    Starts a Pode-based service across different platforms (Windows, Linux, and macOS).

.DESCRIPTION
    The `Start-PodeService` function checks if a Pode-based service is already running, and if not, it starts the service.
    It works on Windows, Linux (systemd), and macOS (launchctl), handling platform-specific service commands to start the service.
    If the service is not registered, it will throw an error.

.PARAMETER None
    No parameters are required for this function.

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
    try {
        # Get the service name from the settings file
        $name = Get-PodeServiceName -Path (Split-Path -Path $MyInvocation.ScriptName -Parent)

        switch ([System.Environment]::OSVersion.Platform) {
            Win32NT {

                # Get the Windows service
                $service = Get-Service -Name $name -ErrorAction SilentlyContinue
                if ($service) {
                    # Check if the service is already running
                    if ($service.Status -ne 'Running') {
                        Start-Service -Name $name -ErrorAction Stop
                        # Log service started successfully
                        # Write-PodeServiceLog -Message "Service '$name' started successfully."
                    }
                    else {
                        # Log service is already running
                        # Write-PodeServiceLog -Message "Service '$name' is already running."
                    }
                }
                else {
                    throw "Service '$name' is not registered."
                }
            }

            Unix {
                # Check if the service exists
                if (systemctl status "$name.service" -q) {
                    # Check if the service is already running
                    $status = systemctl is-active "$name.service"
                    if ($status -ne 'active') {
                        systemctl start "$name.service"
                        # Log service started successfully
                        # Write-PodeServiceLog -Message "Service '$name' started successfully."
                    }
                    else {
                        # Log service is already running
                        # Write-PodeServiceLog -Message "Service '$name' is already running."
                    }
                }
                else {
                    throw "Service '$name' is not registered."
                }
            }

            MacOSX {
                # Check if the service exists in launchctl
                if (launchctl list | Select-String "pode.$name") {
                    # Check if the service is already running
                    if (-not (launchctl list "pode.$name" | Select-String "pode.$name")) {
                        launchctl start "pode.$name"
                        # Log service started successfully
                        # Write-PodeServiceLog -Message "Service '$name' started successfully."
                    }
                    else {
                        # Log service is already running
                        # Write-PodeServiceLog -Message "Service '$name' is already running."
                    }
                }
                else {
                    throw "Service '$name' is not registered."
                }
            }
        }
    }
    catch {
        $_ | Write-PodeErrorLog
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

.PARAMETER None
    No parameters are required for this function.

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
    try {
        # Get the service name from the settings file
        $name = Get-PodeServiceName -Path (Split-Path -Path $MyInvocation.ScriptName -Parent)

        switch ([System.Environment]::OSVersion.Platform) {
            Win32NT {
                $service = Get-Service -Name $name -ErrorAction SilentlyContinue
                if ($service) {
                    # Check if the service is running
                    if ($service.Status -eq 'Running') {
                        Stop-Service -Name $name -ErrorAction Stop -WarningAction SilentlyContinue
                        # Write-PodeServiceLog -Message "Service '$name' stopped successfully."
                    }
                    else {
                        # Write-PodeServiceLog -Message "Service '$name' is not running."
                    }
                }
                else {
                    throw "Service '$name' is not registered."
                }
            }

            Unix {
                # Check if the service exists
                if (systemctl status "$name.service" -q) {
                    $status = systemctl is-active "$name.service"
                    if ($status -eq 'active') {
                        systemctl stop "$name.service"
                        # Write-PodeServiceLog -Message "Service '$name' stopped successfully."
                    }
                    else {
                        # Write-PodeServiceLog -Message "Service '$name' is not running."
                    }
                }
                else {
                    throw "Service '$name' is not registered."
                }
            }

            MacOSX {
                # Check if the service exists in launchctl
                if (launchctl list | Select-String "pode.$name") {
                    # Stop the service if running
                    if (launchctl list "pode.$name" | Select-String "pode.$name") {
                        launchctl stop "pode.$name"
                        # Write-PodeServiceLog -Message "Service '$name' stopped successfully."
                    }
                    else {
                        # Write-PodeServiceLog -Message "Service '$name' is not running."
                    }
                }
                else {
                    throw "Service '$name' is not registered."
                }
            }
        }
    }
    catch {
        $_ | Write-PodeErrorLog
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
        [switch]$Force
    )

    # Get the service name from the settings file
    $name = Get-PodeServiceName -Path (Split-Path -Path $MyInvocation.ScriptName -Parent)

    switch ([System.Environment]::OSVersion.Platform) {
        Win32NT {
            # Check if the service exists
            $service = Get-Service -Name $name -ErrorAction SilentlyContinue
            if (-not $service) {
                throw "Service '$name' is not registered."
            }

            try {
                # Check if the service is running before attempting to stop it
                if ($service.Status -eq 'Running') {
                    if ($Force.IsPresent) {
                        Stop-Service -Name $name -Force -ErrorAction Stop
                        # Write-PodeServiceLog -Message "Service '$name' stopped forcefully."
                    }
                    else {
                        throw "Service '$name' is running. Use the -Force parameter to forcefully stop."
                    }
                }

                # Remove the service
                Remove-Service -Name $name -ErrorAction Stop
                # Write-PodeServiceLog -Message "Service '$name' unregistered successfully."
                return $true
            }
            catch {
                $_ | Write-PodeErrorLog
                return $false
            }
        }

        Unix {
            try {
                # Check if the service exists
                if (systemctl status "$name.service" -q) {
                    # Check if the service is running
                    $status = systemctl is-active "$name.service"
                    if ($status -eq 'active') {
                        if ($Force.IsPresent) {
                            systemctl stop "$name.service"
                            # Write-PodeServiceLog -Message "Service '$name' stopped forcefully."
                        }
                        else {
                            throw "Service '$name' is running. Use the -Force parameter to forcefully stop."
                        }
                    }
                    systemctl disable "$name.service"
                    Remove-Item "/etc/systemd/system/$name.service"
                    # Write-PodeServiceLog -Message "Service '$name' unregistered successfully."
                }
                else {
                    throw "Service '$name' is not registered."
                }
                return $true
            }
            catch {
                $_ | Write-PodeErrorLog
                return $false
            }
        }

        MacOSX {
            try {
                # Check if the service exists
                if (launchctl list | Select-String "pode.$name") {
                    # Check if the service is running
                    if (launchctl list "pode.$name" | Select-String "pode.$name") {
                        if ($Force.IsPresent) {
                            launchctl stop "pode.$name"
                            # Write-PodeServiceLog -Message "Service '$name' stopped forcefully."
                        }
                        else {
                            throw "Service '$name' is running. Use the -Force parameter to forcefully stop."
                        }
                    }
                    launchctl unload "/Library/LaunchDaemons/pode.$name.plist"
                    Remove-Item "~/Library/LaunchAgents/pode.$name.plist"
                    # Write-PodeServiceLog -Message "Service '$name' unregistered successfully."
                }
                else {
                    throw "Service '$name' is not registered."
                }
                return $true
            }
            catch {
                $_ | Write-PodeErrorLog
                return $false
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

.PARAMETER None
    This function does not accept any parameters directly, but it relies on the service name from the configuration file
    (`srvsettings.json`) located in the script's directory.

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

    $name = Get-PodeServiceName -Path (Split-Path -Path $MyInvocation.ScriptName -Parent)

    switch ([System.Environment]::OSVersion.Platform) {
        Win32NT {
            # Check if the service exists on Windows
            $service = Get-Service -Name $name -ErrorAction SilentlyContinue
            if ($service) {
                switch ($service.Status) {
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
                    Name   = $name
                    Status = $status
                }
            }
            else {
                Write-PodeErrorLog -Message "Service '$name' not found on Windows."
                return $null
            }
        }

        Unix {
            try {
                # Check if the service exists on Linux (systemd)
                $output = systemctl is-active "$name.service" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    if ($output -match 'active') {
                        $status = 'Running'
                    }
                    elseif ($output -match 'inactive \(dead\)') {
                        $status = 'Stopped'
                    }
                    elseif ($output -match 'activating') {
                        $status = 'Starting'
                    }
                    elseif ($output -match 'deactivating') {
                        $status = 'Stopping'
                    }
                    else {
                        $status = 'Unknown'
                    }
                    return @{
                        Name   = $name
                        Status = $status
                    }
                }
                else {
                    return @{
                        Name   = $name
                        Status = 'Stopped'
                    }
                }
            }
            catch {
                $_ | Write-PodeErrorLog
                return $null
            }
        }

        MacOSX {
            try {
                # Check if the service exists on macOS (launchctl)
                $serviceList = launchctl list | Select-String "pode.$name"
                if ($serviceList) {
                    $status = launchctl list "pode.$name" 2>&1
                    if ($status -match 'PID = (\d+)') {
                        return @{
                            Name   = $name
                            Status = 'Running'
                        }
                    }
                    else {
                        return @{
                            Name   = $name
                            Status = 'Stopped'
                        }
                    }
                }
                else {
                    Write-PodeErrorLog -Message "Service 'pode.$name' not found on macOS."
                    return $null
                }
            }
            catch {
                $_ | Write-PodeErrorLog
                return $null
            }
        }
    }
}
