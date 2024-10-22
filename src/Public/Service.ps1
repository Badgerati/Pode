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
        Write-PodeServiceLog  -Message "Service '$Name' setting : $settingsFile."

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
                        Write-PodeServiceLog -Message "Service '$Name' started successfully."
                    }
                    else {
                        throw ($PodeLocale.serviceCommandFailedException -f 'Start-Service', $Name)
                    }
                }
                else {
                    # Log service is already running
                    Write-PodeServiceLog -Message "Service '$Name' is already running."
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
            systemctl status $nameService 2>&1
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3) {
                # Check if the service is already running
                $status = systemctl is-active $nameService
                if ($status -ne 'active') {
                    sudo systemctl start $nameService
                    $status = systemctl is-active $nameService
                    if ($status -ne 'active') {
                        throw ($PodeLocale.serviceCommandFailedException -f 'Start-Service', $nameService)
                    }
                    else {

                        Write-PodeServiceLog -Message "Service '$nameService' started successfully."
                    }
                }
                else {
                    # Log service is already running
                    Write-PodeServiceLog -Message "Service '$nameService' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService)
            }
        }

        elseif ($IsMacOS) {
            # Check if the service exists in launchctl
            if (launchctl list | Select-String "pode.$Name") {

                $serviceInfo = launchctl list "pode.$Name" -join "`n"

                # Check if the service has a PID entry
                if (!($serviceInfo -match '"PID" = (\d+);')) {
                    launchctl start "pode.$Name"

                    # Log service started successfully
                    Write-PodeServiceLog -Message "Service '$Name' started successfully."
                    return ($LASTEXITCODE -eq 0)
                }
                else {
                    # Log service is already running
                    Write-PodeServiceLog -Message "Service '$Name' is already running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f "pode.$Name")
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
        # Ensure the script is running with the necessary administrative/root privileges.
        # Exits the script if the current user lacks the required privileges.
        Confirm-PodeAdminPrivilege

        if ($IsWindows) {

            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($service) {
                # Check if the service is running
                if ($service.Status -eq 'Running') {
                    $null = Invoke-PodeWinElevatedCommand  -Command  'Stop-Service' -Arguments "-Name '$Name'"
                    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
                    if ($service.Status -eq 'Stopped') {
                        Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                    }
                    else {
                        throw ($PodeLocale.serviceCommandFailedException -f 'Stop-Service', $Name)
                    }
                }
                else {
                    Write-PodeServiceLog -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f $Name)
            }
        }
        elseif ($IsLinux) {
            $nameService = "$Name.service".Replace(' ', '_')
            systemctl status $nameService 2>&1
            # Check if the service is already registered
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3) {
                # Check if the service exists
                if (systemctl status $nameService -q) {
                    $status = systemctl is-active $nameService
                    if ($status -eq 'active') {
                        sudo systemctl stop $nameService
                        $status = systemctl is-active $nameService
                        if ($status -eq 'active') {
                            throw ($PodeLocale.serviceCommandFailedException -f 'Stop-Service', $Name)
                        }
                        else {
                            Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                        }
                    }
                }
                else {
                    # Service is not registered
                    throw ($PodeLocale.serviceIsNotRegisteredException -f $nameService)
                }
            }
        }
        elseif ($IsMacOS) {
            # Check if the service exists in launchctl
            if (launchctl list | Select-String "pode.$Name") {
                # Stop the service if running
                $serviceInfo = launchctl list "pode.$Name" -join "`n"

                # Check if the service has a PID entry
                if ($serviceInfo -match '"PID" = (\d+);') {
                    launchctl stop "pode.$Name"
                    Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                    return ($LASTEXITCODE -eq 0)
                }
                else {
                    Write-PodeServiceLog -Message "Service '$Name' is not running."
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f "pode.$Name")
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
                        Write-PodeServiceLog -Message "Service '$Name' stopped forcefully."
                    }
                    else {
                        throw ($PodeLocale.serviceCommandFailedException -f 'Stop-Service', $Name)
                    }
                }
                else {
                    # Service is running. Use the -Force parameter to forcefully stop."
                    throw ($Podelocale.serviceIsRunningException -f "pode.$Name")
                }
            }

            # Remove the service
            $null = Invoke-PodeWinElevatedCommand -Command  'Remove-Service' -Arguments "-Name '$Name'"
            $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
            if ($null -ne $service) {
                Write-PodeServiceLog -Message "Service '$Name' unregistered failed."
                throw ($PodeLocale.serviceUnRegistrationException -f $Name)
            }
            Write-PodeServiceLog -Message "Service '$Name' unregistered successfully."

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
            return $false
        }
    }

    elseif ($IsLinux) {
        try {
            $nameService = "$Name.service".Replace(' ', '_')
            systemctl status $nameService 2>&1
            # Check if the service is already registered
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3) {
                # Check if the service is running
                $status = systemctl is-active  $nameService 2>&1
                if ($status -eq 'active') {
                    # $status -eq 'active'
                    if ($Force.IsPresent) {
                        sudo systemctl stop $nameService
                        Write-PodeServiceLog -Message "Service '$Name' stopped forcefully."
                    }
                    else {
                        # Service is running. Use the -Force parameter to forcefully stop."
                        throw ($Podelocale.serviceIsRunningException -f $nameService)
                    }
                }
                sudo systemctl disable $nameService
                if ($LASTEXITCODE -eq 0 ) {
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

                        Write-PodeServiceLog -Message "Service '$Name' unregistered successfully."
                    }
                    sudo systemctl daemon-reload
                }
                else {
                    Write-PodeServiceLog -Message "Service '$Name' unregistered failed."
                    throw ($PodeLocale.serviceUnRegistrationException -f $Name)
                }
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f "pode.$Name")
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
                $serviceInfo = (launchctl list "pode.$Name") -join "`n"
                # Check if the service has a PID entry
                if ($serviceInfo -match '"PID" = (\d+);') {
                    launchctl stop "pode.$Name"
                    Write-PodeServiceLog -Message "Service '$Name' stopped successfully."
                    $serviceIsRunning = ($LASTEXITCODE -ne 0)
                }
                else {
                    $serviceIsRunning = $false
                    Write-PodeServiceLog -Message "Service '$Name' is not running."
                }

                # Check if the service is running
                if (  $serviceIsRunning) {
                    if ($Force.IsPresent) {
                        launchctl stop "pode.$Name"
                        Write-PodeServiceLog -Message "Service '$Name' stopped forcefully."
                    }
                    else {
                        # Service is running. Use the -Force parameter to forcefully stop."
                        throw ($Podelocale.serviceIsRunningException -f "$Name")
                    }
                }
                launchctl unload "$HOME/Library/LaunchAgents/pode.$Name.plist"
                if ($LASTEXITCODE -eq 0) {

                    $plistFilePath = "$HOME/Library/LaunchAgents/pode.$Name.plist"
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
                    }
                }
                else {
                    return $false
                }
                Write-PodeServiceLog -Message "Service '$Name' unregistered successfully."
            }
            else {
                # Service is not registered
                throw ($PodeLocale.serviceIsNotRegisteredException -f "pode.$Name")
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
            }
        }
        else {
            #Write-PodeErrorLog -Message "Service '$Name' not found on Windows."
            return $null
        }
    }

    elseif ($IsLinux) {
        try {
            $nameService = "$Name.service".Replace(' ', '_')
            # Check if the service exists on Linux (systemd)
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


<#
.SYNOPSIS
Enables logging for the Pode service using a specified logging method.

.DESCRIPTION
The `Enable-PodeServiceLogging` function configures and enables service logging for the Pode server using the provided logging method and specified log levels. It ensures that the logging method includes a valid script block and prevents duplicate logging methods from being enabled.

.PARAMETER Method
A hashtable that defines the logging method. This should contain a `ScriptBlock` key, which specifies the script to be executed for logging.

.PARAMETER Levels
An array of logging levels to capture. The available levels are 'Error', 'Warning', 'Informational', 'Verbose', 'Debug', or '*'. The default value is 'Error'. If '*' is specified, all levels are captured.

.PARAMETER Raw
Indicates whether to log raw data without formatting. If set, the output is logged as-is without additional processing.

.EXAMPLE
PS> Enable-PodeServiceLogging -Method @{ ScriptBlock = { Write-Host "Logging" } } -Levels 'Error', 'Warning'

Enables error and warning level logging using the provided method.

.EXAMPLE
PS> Enable-PodeServiceLogging -Method @{ ScriptBlock = { Write-Host "Raw Logging" } } -Raw

Enables raw logging for all error levels.

.NOTES
This function throws an error if the logging method has already been enabled or if the provided method does not include a valid script block.
#>
function Enable-PodeServiceLogging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]
        $Method,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug', '*')]
        [string[]]
        $Levels = @('Error'),

        [switch]
        $Raw
    )

    $name = Get-PodeServiceLoggingName

    # error if it's already enabled
    if ($PodeContext.Server.Logging.Types.Contains($name)) {
        # Error Logging has already been enabled
        throw ($PodeLocale.errorLoggingAlreadyEnabledExceptionMessage)
    }

    # ensure the Method contains a scriptblock
    if (Test-PodeIsEmpty $Method.ScriptBlock) {
        # The supplied output Method for Error Logging requires a valid ScriptBlock
        throw ($PodeLocale.loggingMethodRequiresValidScriptBlockExceptionMessage -f 'Error')
    }

    # all errors?
    if ($Levels -contains '*') {
        $Levels = @('Error', 'Warning', 'Informational', 'Verbose', 'Debug')
    }

    # add the error logger
    $PodeContext.Server.Logging.Types[$name] = @{
        Method      = $Method
        ScriptBlock = (Get-PodeLoggingInbuiltType -Type Errors)
        Arguments   = @{
            Raw    = $Raw
            Levels = $Levels
        }
    }
}

<#
.SYNOPSIS
Disables the logging for the Pode service.

.DESCRIPTION
The `Disable-PodeServiceLogging` function disables the currently enabled logging method for the Pode service. It removes the logger associated with the service by using the logger's name.

.EXAMPLE
PS> Disable-PodeServiceLogging

Disables the service logging for Pode.

.NOTES
This function uses the `Remove-PodeLogger` cmdlet to remove the logger by name.
#>
function Disable-PodeServiceLogging {
    [CmdletBinding()]
    param()

    Remove-PodeLogger -Name (Get-PodeServiceLoggingName)
}
