# Using Pode as a Service

Pode provides built-in functions to easily manage services across platforms (Windows, Linux, macOS). These functions allow you to register, start, stop, suspend, resume, query, and unregister Pode services in a cross-platform way.

---

## Registering a Service

The `Register-PodeService` function creates the necessary service files and configurations for your system.

#### Example:

```powershell
Register-PodeService -Name "HelloService" -Description "Example Pode Service" -ParameterString "-Verbose" -Start
```

This registers a service named "HelloService" and starts it immediately after registration. The service runs your Pode script with the specified parameters.

### `Register-PodeService` Parameters

The `Register-PodeService` function offers several parameters to customize your service registration:

- **`-Name`** *(string)*:
  The name of the service to register.
  **Mandatory**.

- **`-Description`** *(string)*:
  A brief description of the service. Defaults to `"This is a Pode service."`.

- **`-DisplayName`** *(string)*:
  The display name for the service (Windows only). Defaults to `"Pode Service($Name)"`.

- **`-StartupType`** *(string)*:
  Specifies the startup type of the service (`'Automatic'` or `'Manual'`). Defaults to `'Automatic'`.

- **`-ParameterString`** *(string)*:
  Additional parameters to pass to the worker script when the service is run. Defaults to an empty string.

- **`-LogServicePodeHost`** *(switch)*:
  Enables logging for the Pode service host.

- **`-ShutdownWaitTimeMs`** *(int)*:
  Maximum time in milliseconds to wait for the service to shut down gracefully before forcing termination. Defaults to `30,000 ms`.

- **`-StartMaxRetryCount`** *(int)*:
  Maximum number of retries to start the PowerShell process before giving up. Defaults to `3`.

- **`-StartRetryDelayMs`** *(int)*:
  Delay in milliseconds between retry attempts to start the PowerShell process. Defaults to `5,000 ms`.

- **`-WindowsUser`** *(string)*:
  Specifies the username under which the service will run. Defaults to the current user (Windows only).

- **`-LinuxUser`** *(string)*:
  Specifies the username under which the service will run. Defaults to the current user (Linux Only).

- **`-Agent`** *(switch)*:
    Create an Agent instead of a Daemon in MacOS (MacOS Only).

- **`-Start`** *(switch)*:
  Starts the service immediately after registration.

- **`-Password`** *(securestring)*:
  A secure password for the service account (Windows only). If omitted, the service account will be `'NT AUTHORITY\SYSTEM'`.

- **`-SecurityDescriptorSddl`** *(string)*:
  A security descriptor in SDDL format specifying the permissions for the service (Windows only).

- **`-SettingsPath`** *(string)*:
  Directory to store the service configuration file (`<name>_svcsettings.json`). Defaults to a directory under the script path.

- **`-LogPath`** *(string)*:
  Path for the service log files. Defaults to a directory under the script path.

---

## Starting a Service

You can start a registered service using the `Start-PodeService` function.

#### Example:

```powershell
Start-PodeService -Name "HelloService"
```

This returns `$true` if the service starts successfully, `$false` otherwise.

---

## Stopping a Service

To stop a running service, use the `Stop-PodeService` function.

#### Example:

```powershell
Stop-PodeService -Name "HelloService"
```

This returns `$true` if the service stops successfully, `$false` otherwise.

---

## Suspending a Service

Suspend a running service (Windows only) with the `Suspend-PodeService` function.

#### Example:

```powershell
Suspend-PodeService -Name "HelloService"
```

This pauses the service, returning `$true` if successful.

---

## Resuming a Service

Resume a suspended service (Windows only) using the `Resume-PodeService` function.

#### Example:

```powershell
Resume-PodeService -Name "HelloService"
```

This resumes the service, returning `$true` if successful.

---

## Querying a Service

To check the status of a service, use the `Get-PodeService` function.

#### Example:

```powershell
Get-PodeService -Name "HelloService"
```

This returns a hashtable with the service details:

```powershell
Name                           Value
----                           -----
Status                         Running
Pid                            17576
Name                           HelloService
Sudo                           True
```

---

## Restarting a Service

Restart a running service using the `Restart-PodeService` function.

#### Example:

```powershell
Restart-PodeService -Name "HelloService"
```

This stops and starts the service, returning `$true` if successful.

---

## Unregistering a Service

When you no longer need a service, unregister it with the `Unregister-PodeService` function.

#### Example:

```powershell
Unregister-PodeService -Name "HelloService" -Force
```

This forcefully stops and removes the service, returning `$true` if successful.

---

## Alternative Methods for Windows and Linux

If the Pode functions are unavailable or you prefer manual management, you can use traditional methods to configure Pode as a service.

### Windows (NSSM)

To use NSSM for Pode as a Windows service:

1. Install NSSM using Chocolatey:

   ```powershell
   choco install nssm -y
   ```

2. Configure the service:

   ```powershell
   $exe = (Get-Command pwsh.exe).Source
   $name = 'Pode Web Server'
   $file = 'C:\Pode\Server.ps1'
   $arg = "-ExecutionPolicy Bypass -NoProfile -Command `"$($file)`""
   nssm install $name $exe $arg
   nssm start $name
   ```

3. Stop or remove the service:

   ```powershell
   nssm stop $name
   nssm remove $name confirm
   ```

---

### Linux (systemd)

To configure Pode as a Linux service:

1. Create a service file:

   ```bash
   sudo vim /etc/systemd/system/pode-server.service
   ```

2. Add the following configuration:

   ```bash
   [Unit]
   Description=Pode Web Server
   After=network.target

   [Service]
   ExecStart=/usr/bin/pwsh -c /usr/src/pode/server.ps1 -nop -ep Bypass
   Restart=always

   [Install]
   WantedBy=multi-user.target
   Alias=pode-server.service
   ```

3. Start and stop the service:

   ```bash
   sudo systemctl start pode-server
   sudo systemctl stop pode-server
   ```

---

## Using Ports Below 1024

For privileged ports, consider:

1. **Reverse Proxy:** Use Nginx to forward traffic from port 443 to an unprivileged port.

2. **iptables Redirection:** Redirect port 443 to an unprivileged port:

   ```bash
   sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080
   ```

3. **setcap Command:** Grant PowerShell permission to bind privileged ports:

   ```bash
   sudo setcap 'cap_net_bind_service=+ep' $(which pwsh)
   ```

4. **Authbind:** Configure Authbind to allow binding to privileged ports:

   ```bash
   authbind --deep pwsh yourscript.ps1
   ```
