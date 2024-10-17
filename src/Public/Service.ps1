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

        [string]
        [validateset('Manual', 'Automatic')]
        $StartupType = 'Automatic',

        [string]
        $SecurityDescriptorSddl,

        [string]$ParameterString = '',
        [bool]$Quiet = $true,
        [bool]$DisableTermination = $true,
        [int]$ShutdownWaitTimeMs = 30000,

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
        $MainScriptPath = Split-Path -Path $MyInvocation.ScriptName -Parent
        $MainScriptFileName = Split-Path -Path $MyInvocation.ScriptName -Leaf
    }
    else {
        return $null
    }

    # Define script and log file paths
    $ScriptPath = Join-Path -Path $MainScriptPath -ChildPath $MainScriptFileName # Example script path
    $LogPath = Join-Path -Path $MainScriptPath -ChildPath '/logs'
    $LogFilePath = Join-Path -Path $LogPath -ChildPath "$($Name)_svc.log"

    # Obtain the PowerShell path dynamically
    $PwshPath = (Get-Process -Id $PID).Path

    # Define the settings file path
    $settingsFile = "$MainScriptPath/srvsettings.json"

    $binPath = "$(Split-Path -Parent -Path $PSScriptRoot)/Bin"

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

    switch ( [System.Environment]::OSVersion.Platform) {

        [System.PlatformID]::Win32NT {

            # Check if service already exists
            if (Get-Service -Name $Name -ErrorAction SilentlyContinue) {
                throw "Windows Service '$Name' already exists."
            }

            # Parameters for New-Service
            $params = @{
                Name           = $Name
                BinaryPathName = "`"$binPath/PodeMonitor.exe`" `"$settingsFile`""
                DisplayName    = $DisplayName
                StartupType    = $StartupType
                Description    = $Description
                DependsOn      = 'NetLogon'
            }
            if ($Credential) {
                $params['Credential'] = $Credential
            }
            if ($SecurityDescriptorSddl) {
                $params['SecurityDescriptorSddl'] = $SecurityDescriptorSddl
            }

            try {
                $service = New-Service @params
                if ($Start.IsPresent) {
                    # Start the service
                    Start-Service -InputObject $service
                }
            }
            catch {
                $_ | Write-PodeErrorLog
            }
        }

        [System.PlatformID]::Unix {
            @"
[Unit]
Description=$Description
After=network.target

[Service]
ExecStart=$binPath/linux-x64/PodeMonitor $settingsFile
WorkingDirectory=$MainScriptPath
Restart=always
User=$User
Group=$Group
#  Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1
# Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
"@| Set-Content -Path "/etc/systemd/system/$($Name).service" -Encoding UTF8

            if (!$SkipUserCreation.IsPresent) {
                # Run the id command to check if the user exists
                $result = id $User 2>&1
                if ($result -match 'no such user') {
                    # Create the user
                    useradd -r -s /bin/false $User
                }
            }

            # Enable the service
            systemctl enable $($Name).service

            if ($Start.IsPresent) {
                # Start the service
                systemctl start $($Name).service
            }

        }
        [System.PlatformID]::MacOSX {
            $macOsArch = 'osx-arm64'
            if ($StartupType -eq 'Automatic') {
                $runAtLoad = 'true'
            }
            else {
                $runAtLoad = 'false'
            }
            @"
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>Label</key>
                <string>pode.$Name</string>

                <key>ProgramArguments</key>
                <array>
                    <string>$binPath/$macOsArch/PodeMonitor</string> <!-- Path to your published executable -->
                    <string>$settingsFile</string> <!-- Pass your configuration file -->
                </array>

                <key>WorkingDirectory</key>
                <string>$MainScriptPath</string>

                <key>RunAtLoad</key>
                <$runAtLoad/>

                <key>StandardOutPath</key>
                <string>$LogPath/stdout.log</string>

                <key>StandardErrorPath</key>
                <string>$LogPath/stderr.log</string>

                <key>KeepAlive</key>
                <true/>
            </dict>
            </plist>
"@| Set-Content -Path "~/Library/LaunchAgents/pode.$($Name).plist" -Encoding UTF8

            launchctl load /Library/LaunchDaemons/pode.$($Name).plist
            if ($Start.IsPresent) {
                # Start the service
                launchctl start pode.$($Name)
            }
        }

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
