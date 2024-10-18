<#
.SYNOPSIS
    Registers a new service to run a Pode-based PowerShell worker as a service on Windows, Linux, or macOS.

.DESCRIPTION
    The `Register-PodeService` function configures and registers a Pode-based service that runs a PowerShell worker across
    multiple platforms (Windows, Linux, macOS). It dynamically creates a service with the specified parameters, including
    paths to the worker script, log files, and service-specific settings. The function also generates a `srvsettings.json` file,
    containing the service configuration. The service can optionally be started immediately after registration, based on the platform.

.PARAMETER Name
    Specifies the name of the service to be registered.

.PARAMETER Description
    A brief description of the service. Defaults to "This is a Pode service."

.PARAMETER DisplayName
    Specifies the display name for the service in the Windows Services Manager. Defaults to "Pode Service($Name)".

.PARAMETER StartupType
    Specifies the startup type of the service (e.g., 'Automatic', 'Manual'). Defaults to 'Automatic'.

.PARAMETER SecurityDescriptorSddl
    A security descriptor in SDDL format, specifying the permissions for the service (Windows only).

.PARAMETER ParameterString
    Any additional parameters to pass to the worker script when run by the service. Defaults to an empty string.

.PARAMETER Quiet
    If set to `$true`, runs the service quietly, suppressing logs and output. Defaults to `$true`.

.PARAMETER DisableTermination
    If set to `$true`, disables termination of the service from within the worker process. Defaults to `$true`.

.PARAMETER ShutdownWaitTimeMs
    The maximum amount of time, in milliseconds, to wait for the service to shut down gracefully before forcefully terminating it.
    Defaults to 30,000 milliseconds (30 seconds).

.PARAMETER User
    Specifies the user under which the service will run (applies to Linux and macOS). Defaults to `podeuser`.

.PARAMETER Group
    Specifies the group under which the service will run (Linux only). Defaults to `podeuser`.

.PARAMETER Start
    A switch to immediately start the service after registration.

.PARAMETER SkipUserCreation
    A switch to skip the process of creating a new user (Linux only).

.PARAMETER Credential
    A `PSCredential` object specifying the credentials for the Windows service account under which the service will run.

.PARAMETER ConfigDirectory
    Specifies a custom directory to store the generated configuration (`srvsettings.json`) file.

.EXAMPLE
    Register-PodeService -Name "PodeExampleService" -Description "Example Pode Service" -ParameterString "-Verbose"

    This example registers a new Pode service called "PodeExampleService" with verbose logging enabled.

.NOTES
    - The function supports cross-platform service registration on Windows, Linux, and macOS.
    - A configuration file (`srvsettings.json`) is generated in the specified directory, or by default, in the same directory as the main script.
    - On Windows, the function checks for appropriate permissions (e.g., Administrator or service creation privileges).
    - The Pode service can be started automatically after registration using the `-Start` switch.
    - The PowerShell executable path is dynamically obtained to ensure compatibility across environments.
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
        $Credential,

        [string]
        $ConfigDirectory
    )
    try {
        # Check for administrative privileges on Windows
        if ($IsWindows) {
            if (! (Test-PodeIsAdmin) -and ! (Test-PodeUserServiceCreationPrivilege) ) {
                Write-PodeHost "This script needs to run as Administrator or with the 'SERVICE_CHANGE_CONFIG'(SeCreateServicePrivilege) privilege." -ForegroundColor Yellow
                exit
            }
        }

        # Obtain the script path and directory
        if ($MyInvocation.ScriptName) {
            $ScriptPath = $MyInvocation.ScriptName
            $MainScriptPath = Split-Path -Path $ScriptPath -Parent
        }
        else {
            return $null
        }

        # Define log paths and ensure the log directory exists
        $LogPath = Join-Path -Path $MainScriptPath -ChildPath 'logs'
        $LogFilePath = Join-Path -Path $LogPath -ChildPath "$($Name)_svc.log"

        if (-not (Test-Path $LogPath)) {
            $null = New-Item -Path $LogPath -ItemType Directory -Force
        }

        # Dynamically get the PowerShell executable path
        $PwshPath = (Get-Process -Id $PID).Path

        # Define configuration directory and settings file path
        if ($ConfigDirectory) {
            $settingsPath = Join-Path -Path $MainScriptPath -ChildPath $ConfigDirectory
            if (! (Test-Path -Path $settingsPath -PathType Container)) {
                $null = New-Item -Path $settingsPath -ItemType Directory
            }
        }
        else {
            $settingsPath = $MainScriptPath
        }
        $settingsFile = Join-Path -Path $settingsPath -ChildPath "$($Name)_srvsettings.json"

        # Generate the service settings JSON file
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
                Credential             = $Credential
                SecurityDescriptorSddl = $SecurityDescriptorSddl
                OsArchitecture         = "win-$osArchitecture"
            }
            $operation = Register-PodeWindowsService  @param
        }
        elseif ($IsLinux) {
            $param = @{
                Name             = $Name
                Description      = $Description
                BinPath          = $binPath
                SettingsFile     = $settingsFile
                User             = $User
                Group            = $Group
                Start            = $Start
                SkipUserCreation = $SkipUserCreation
                OsArchitecture   = "linux-$osArchitecture"
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
    try {

        if ($IsWindows) {

            # Check if the current script is running as Administrator
            if (! (Test-PodeIsAdmin) -and ! (Test-PodeUserServiceCreationPrivilege) ) {
                Write-PodeHost "This script needs to run as Administrator or with the 'SERVICE_CHANGE_CONFIG'(SeCreateServicePrivilege) privilege." -ForegroundColor Yellow
                exit
            }

            # Get the Windows service
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is already running
                if ($service.Status -ne 'Running') {
                    Start-Service -Name $Name -ErrorAction Stop
                    # Log service started successfully
                    # Write-PodeServiceLog -Message "Service '$Name' started successfully."
                }
                else {
                    # Log service is already running
                    # Write-PodeServiceLog -Message "Service '$Name' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
            }
        }

        elseif ($IsLinux) {
            # Check if the service exists
            if (systemctl status "$Name.service" -q) {
                # Check if the service is already running
                $status = systemctl is-active "$Name.service"
                if ($status -ne 'active') {
                    sudo systemctl start "$Name.service"
                    # Log service started successfully
                    # Write-PodeServiceLog -Message "Service '$Name' started successfully."
                }
                else {
                    # Log service is already running
                    # Write-PodeServiceLog -Message "Service '$Name' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
            }
        }

        elseif ($IsMacOS) {
            # Check if the service exists in launchctl
            if (launchctl list | Select-String "pode.$Name") {

                $serviceInfo = launchctl list "pode.$Name" -join "`n"

                # Check if the service has a PID entry
                if (!($serviceInfo -match '"PID" = (\d+);')) {
                    sudo launchctl start "pode.$Name"

                    # Log service started successfully
                    # Write-PodeServiceLog -Message "Service '$Name' started successfully."
                    return ($LASTEXITCODE -eq 0)
                }
                else {
                    # Log service is already running
                    # Write-PodeServiceLog -Message "Service '$Name' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
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

        if ($IsWindows) {
            if (! (Test-PodeIsAdmin) -and ! (Test-PodeUserServiceCreationPrivilege) ) {
                Write-PodeHost "This script needs to run as Administrator or with the 'SERVICE_CHANGE_CONFIG'(SeCreateServicePrivilege) privilege." -ForegroundColor Yellow
                exit
            }
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is running
                if ($service.Status -eq 'Running') {
                    Stop-Service -Name $Name -ErrorAction Stop -WarningAction SilentlyContinue
                    # Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                }
                else {
                    # Write-PodeServiceLog -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
            }
        }
        elseif ($IsLinux) {
            # Check if the service exists
            if (systemctl status "$Name.service" -q) {
                $status = systemctl is-active "$Name.service"
                if ($status -eq 'active') {
                    sudo systemctl stop "$Name.service"
                    # Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                }
                else {
                    # Write-PodeServiceLog -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
            }
        }

        elseif ($IsMacOS) {
            # Check if the service exists in launchctl
            if (launchctl list | Select-String "pode.$Name") {
                # Stop the service if running
                $serviceInfo = launchctl list "pode.$Name" -join "`n"

                # Check if the service has a PID entry
                if ($serviceInfo -match '"PID" = (\d+);') {
                    sudo launchctl stop "pode.$Name"
                    # Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                    return ($LASTEXITCODE -eq 0)
                }
                else {
                    # Write-PodeServiceLog -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
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

    if ($IsWindows) {
        if (! (Test-PodeIsAdmin) -and ! (Test-PodeUserServiceCreationPrivilege) ) {
            Write-PodeHost "This script needs to run as Administrator or with the 'SERVICE_CHANGE_CONFIG'(SeCreateServicePrivilege) privilege." -ForegroundColor Yellow
            exit
        }
        # Check if the service exists
        $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if (-not $service) {
            # Service is not registered
            throw ($PodeLocale.serviceNotRegisteredException -f "$Name")
        }

        try {
            # Check if the service is running before attempting to stop it
            if ($service.Status -eq 'Running') {
                if ($Force.IsPresent) {
                    Stop-Service -Name $Name -Force -ErrorAction Stop
                    # Write-PodeServiceLog -Message "Service '$Name' stopped forcefully."
                }
                else {
                    # Service is running. Use the -Force parameter to forcefully stop."
                    throw ($Podelocale.serviceIsRunningException -f "pode.$Name")
                }
            }

            # Remove the service
            Remove-Service -Name $Name -ErrorAction Stop
            # Write-PodeServiceLog -Message "Service '$Name' unregistered successfully."

            # Remove the service configuration
            if ($service.BinaryPathName) {
                $binaryPath = $service.BinaryPathName.trim('"').split('" "')
                if ((Test-Path -Path ($binaryPath[1]) -PathType Leaf)) {
                    Remove-Item -Path ($binaryPath[1]) -ErrorAction Break
                }
            }
            return $true
        }
        catch {
            $_ | Write-PodeErrorLog
            return $false
        }
    }

    elseif ($IsLinux) {
        try {
            # Check if the service exists
            if (systemctl status "$Name.service" -q) {
                # Check if the service is running
                $status = systemctl is-active "$Name.service"
                if ($status -eq 'active') {
                    if ($Force.IsPresent) {
                        sudo systemctl stop "$Name.service"
                        # Write-PodeServiceLog -Message "Service '$Name' stopped forcefully."
                    }
                    else {
                        # Service is running. Use the -Force parameter to forcefully stop."
                        throw ($Podelocale.serviceIsRunningException -f "$Name.service")
                    }
                }
                sudo systemctl disable "$Name.service"

                # Read the content of the service file
                $serviceFilePath = "/etc/systemd/system/$Name.service"
                $serviceFileContent = Get-Content -Path $serviceFilePath

                # Extract the SettingsFile from the ExecStart line using regex
                $settingsFile = $serviceFileContent | Select-String -Pattern 'ExecStart=.*\s+(.*)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
                if ((Test-Path -Path $settingsFile -PathType Leaf)) {
                    Remove-Item -Path $settingsFile
                }

                Remove-Item -Path $serviceFilePath -ErrorAction Break
                # Write-PodeServiceLog -Message "Service '$Name' unregistered successfully."
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
            }
            return $true
        }
        catch {
            $_ | Write-PodeErrorLog
            return $false
        }
    }

    elseif ($IsMacOS) {
        try {
            # Check if the service exists

            if (launchctl list | Select-String "pode.$Name") {
                $serviceInfo = launchctl list "pode.$Name" -join "`n"
                # Check if the service has a PID entry
                if ($serviceInfo -match '"PID" = (\d+);') {
                    sudo launchctl stop "pode.$Name"
                    # Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                    $serviceIsRunning = ($LASTEXITCODE -ne 0)
                }
                else {
                    $serviceIsRunning = $false
                    # Write-PodeServiceLog -Message "Service '$Name' is not running."
                }

                # Check if the service is running
                if (  $serviceIsRunning) {
                    if ($Force.IsPresent) {
                        sudo launchctl stop "pode.$Name"
                        # Write-PodeServiceLog -Message "Service '$Name' stopped forcefully."
                    }
                    else {
                        # Service is running. Use the -Force parameter to forcefully stop."
                        throw ($Podelocale.serviceIsRunningException -f "$Name")
                    }
                }
                sudo launchctl unload ~/Library/LaunchAgents/pode.$Name.plist
                if ($LASTEXITCODE -eq 0) {

                    $plistFilePath = "~/Library/LaunchAgents/pode.$Name.plist"

                    # Read the content of the plist file
                    $plistFileContent = Get-Content -Path $plistFilePath

                    # Extract the SettingsFile from the ProgramArguments array using regex
                    $settingsFile = $plistFileContent | Select-String -Pattern '<string>(.*)</string>' | ForEach-Object {
                        if ($_.Line -match 'PodeMonitor.*<string>(.*)</string>') {
                            $matches[1]
                        }
                    }

                    if ((Test-Path -Path $settingsFile -PathType Leaf)) {
                        Remove-Item -Path $settingsFile
                    }

                    Remove-Item -Path $plistFilePath -ErrorAction Break
                }
                else {
                    return $false
                }
                # Write-PodeServiceLog -Message "Service '$Name' unregistered successfully."
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceNotRegisteredException -f "pode.$Name")
            }
            return $true
        }
        catch {
            $_ | Write-PodeErrorLog
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

    if ($IsWindows) {
        if (! (Test-PodeIsAdmin) -and ! (Test-PodeUserServiceCreationPrivilege) ) {
            Write-PodeHost "This script needs to run as Administrator or with the 'SERVICE_CHANGE_CONFIG'(SeCreateServicePrivilege) privilege." -ForegroundColor Yellow
            exit
        }
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
            }
        }
        else {
            #Write-PodeErrorLog -Message "Service '$Name' not found on Windows."
            return $null
        }
    }

    elseif ($IsLinux) {
        try {
            # Check if the service exists on Linux (systemd)
            $output = systemctl is-active "$Name.service" 2>&1
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
                    Name   = $Name
                    Status = $status
                }
            }
            else {
                return @{
                    Name   = $Name
                    Status = 'Stopped'
                }
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            return $null
        }
    }

    elseif ($IsMacOS) {
        try {
            # Check if the service exists on macOS (launchctl)
            $serviceList = launchctl list | Select-String "pode.$Name"
            if ($serviceList) {
                $serviceInfo = launchctl list "pode.$Name" -join "`n"
                $running = $serviceInfo -match '"PID" = (\d+);'
                # Check if the service has a PID entry
                if ($running) {
                    $servicePid = ($running[0].split('= '))[1].trim(';')  # Extract the PID from the match

                    return @{
                        Name   = $Name
                        Status = 'Running'
                        Pid    = $servicePid
                    }
                }
                else {
                    return @{
                        Name   = $Name
                        Status = 'Stopped'
                        Pid    = 0
                    }
                }
            }
            else {
                Write-PodeErrorLog -Message "Service 'pode.$Name' not found on macOS."
                return $null
            }
        }
        catch {
            $_ | Write-PodeErrorLog
            return $null
        }
    }
}
