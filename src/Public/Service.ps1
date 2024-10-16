<#
.SYNOPSIS
    Registers a new Windows service to run a Pode-based PowerShell worker as a service.

.DESCRIPTION
    The `Register-PodeService` function configures and registers a Windows service for running a Pode-based PowerShell worker.
    It dynamically sets up the service with the specified parameters, including paths to the script and log files, PowerShell executable,
    and service settings. It also generates a `srvsettings.json` file containing the service's configuration.

.PARAMETER Name
    The name of the Windows service to be registered.

.PARAMETER Description
    A brief description of the service. Defaults to "This is a Pode service."

.PARAMETER DisplayName
    The display name of the service, as it will appear in the Windows Services Manager. Defaults to "Pode Service($Name)".

.PARAMETER StartupType
    The startup type of the service (e.g., Automatic, Manual, Disabled). Defaults to 'Automatic'.

.PARAMETER ParameterString
    Any additional parameters to pass to the script when it is run by the service. Defaults to an empty string.

.PARAMETER Quiet
    A boolean value indicating whether to run the service quietly, suppressing logs and output. Defaults to `$true`.

.PARAMETER DisableTermination
    A boolean value indicating whether to disable termination of the service from within the worker process. Defaults to `$true`.

.PARAMETER ShutdownWaitTimeMs
    The maximum amount of time, in milliseconds, to wait for the service to gracefully shut down before forcefully terminating it. Defaults to 30,000 milliseconds.

.EXAMPLE
    Register-PodeService -Name "PodeExampleService" -Description "Example Pode Service" -ParameterString "-Verbose"

    Registers a new Pode-based service called "PodeExampleService" with verbose logging enabled.

.NOTES
    - The function dynamically determines the PowerShell executable path.
    - A `srvsettings.json` file is generated in the same directory as the main script, containing the configuration for the Pode service.
    - The function checks if a service with the specified name already exists and throws an error if it does.
    - The service binary path is set to point to the Pode monitor executable (`PodeMonitor.exe`), which is located in the `Bin` directory relative to the script.
#>
function Register-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$Description = 'This is a Pode service.',
        [string]$DisplayName = "Pode Service($Name)",
        [Microsoft.PowerShell.Commands.ServiceStartupType] $StartupType = 'Automatic',

        [string]$ParameterString = '',
        [bool]$Quiet = $true,
        [bool]$DisableTermination = $true,
        [int]$ShutdownWaitTimeMs = 30000
    )

    if ($MyInvocation.ScriptName) {
        $MainScriptPath = Split-Path -Path $MyInvocation.ScriptName -Parent
        $MainScriptFileName = Split-Path -Path $MyInvocation.ScriptName -Leaf
    }
    else {
       return $null
    }

    # Define script and log file paths
    $ScriptPath = Join-Path -Path $MainScriptPath -ChildPath $MainScriptFileName # Example script path
    $LogFilePath = Join-Path -Path $MainScriptPath -ChildPath "/logs/$($Name)_svc.log"

    # Obtain the PowerShell path dynamically
    $PwshPath = (Get-Process -Id $PID).Path

    # Define the settings file path
    $settingsFile = "$MainScriptPath/srvsettings.json"

    $binPath =   "$(Split-Path -Parent -Path $PSScriptRoot)/Bin"

    # Check if service already exists
    if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
             throw "Windows Service '$Name' already exists."
    }

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
        }
    }

    # Convert hash table to JSON and save it to the settings file
    $jsonContent | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8

    # Parameters for New-Service
    $params = @{
        Name           = $Name
        BinaryPathName = "$binPath/PodeMonitor.exe $settingsFile"
        DisplayName    = $DisplayName
        StartupType    = $StartupType
        Description    = $Description
    }
    try {
        return New-Service @params
    }
    catch {
        $_ | Write-PodeErrorLog
    }
}

<#
.SYNOPSIS
    Unregisters and removes an existing Pode-based Windows service.

.DESCRIPTION
    The `Unregister-PodeService` function stops and removes an existing Windows service that was previously registered using `Register-PodeService`.
    It checks if the service exists and, if running, stops it before removing it from the system.

.PARAMETER Name
    The name of the Windows service to be unregistered and removed.

.EXAMPLE
    Unregister-PodeService -Name "PodeExampleService"

    Unregisters and removes the Pode-based service named "PodeExampleService".

.NOTES
    - This function checks if the service is running before attempting to stop it.
    - If the service is not found, it will throw an error.
    - You can customize this function to remove any associated files (like configuration files) by uncommenting the relevant section for deleting the settings file.
#>
function Unregister-PodeService {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    # Check if the service exists
    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        throw ("Service '$Name' does not exist.")
    }

    try {
        # Check if the service is running before attempting to stop it
        if ($service.Status -eq 'Running') {
            Stop-Service -Name $Name -Force -ErrorAction Stop
        }

        # Remove the service
        Remove-Service -Name $Name -ErrorAction Stop
    }
    catch {
        # Handle errors (if needed, you can implement error handling here)
        throw $_  # Re-throw the exception for the caller to handle
    }

    # Optionally, remove the settings file
   # $settingsFile = "$PWD/srvsettings.json"
#    if (Test-Path -Path $settingsFile) {
  #      Remove-Item -Path $settingsFile -Force
    #}
}
