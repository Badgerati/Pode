# Service

Rather than having to manually invoke your Pode server script each time, it's best if you can have it start automatically when your computer/server starts. Below you'll see how to set your script to run as either a Windows or a Linux service.

## Windows

To run your Pode server as a Windows service, we recommend using the [`NSSM`](https://nssm.cc) tool. To install on Windows you can use Chocolatey:

```powershell
choco install nssm -y
```

Once installed, you'll need to set the location of the `pwsh` or `powershell` executables as a variable:

```powershell
$exe = (Get-Command pwsh.exe).Source

# or

$exe = (Get-Command powershell.exe).Source
```

Next, define the name of the Windows service; as well as the full file path to your Pode server script, and the arguments to be supplied to PowerShell:

```powershell
$name = 'Pode Web Server'
$file = 'C:\Pode\Server.ps1'
$arg = "-ExecutionPolicy Bypass -NoProfile -Command `"$($file)`""
```

Finally, install and start the service:

```powershell
nssm install $name $exe $arg
nssm start $name
```

!!! info
    You can now navigate to your server, ie: `http://localhost:8080`.

To stop (or remove) the service afterwards, you can use the following:

```powershell
nssm stop $name
nssm remove $name confirm
```

## Linux

To run your Pode server as a Linux service you just need to create a `<name>.service` file at `/etc/systemd/system`. The following is example content for an example `pode-server.service` file, which run PowerShell Core (`pwsh`), as well as you script:

```bash
sudo vim /etc/systemd/system/pode-server.service
```

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

Finally, start the service:

```powershell
sudo systemctl start pode-server
```

!!! info
    You can now navigate to your server, ie: `http://localhost:8080`.

To stop the service afterwards, you can use the following:

```powershell
sudo systemctl stop pode-server
```
### Using Ports Below 1024

#### Introduction

Traditionally in Linux, binding to ports below 1024 requires root privileges. This is a security measure, as these low-numbered ports are considered privileged. However, running applications as the root user poses significant security risks. This article explores methods to use these privileged ports with PowerShell (`pwsh`) in Linux, without running it as the root user.
There are different methods to achieve the goals.
Reverse Proxy is the right approach for a production environment, primarily if the server is connected directly to the internet.
The other solutions are reasonable after an in-depth risk analysis.

#### Using a Reverse Proxy

A reverse proxy like Nginx can listen on the privileged port and forward requests to your application running on an unprivileged port.

**Configuration:**
* Configure Nginx to listen on port 443 and forward requests to the port where your PowerShell script is listening.

* This method is widely used in web applications for its additional benefits like load balancing and SSL termination.

#### iptables Redirection

Using iptables, you can redirect traffic from a privileged port to a higher, unprivileged port.

**Implementation:**
  * Set up an iptables rule to redirect traffic from, say, port 443 to a higher port where your PowerShell script is listening.
  
  * `sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8080`

**Benefits:**
  * This approach doesn't require changing the privileges of the PowerShell executable or script.

#### Using `setcap` Command

The `setcap` utility can grant specific capabilities to an executable, like `pwsh`, enabling it to bind to privileged ports.

**How it Works:**
  * Run `sudo setcap 'cap_net_bind_service=+ep' $(which pwsh)`. This command sets the `CAP_NET_BIND_SERVICE` capability on the PowerShell executable, allowing it to bind to any port below 1024.

**Security Consideration:**
  * This method enhances security by avoiding running PowerShell as root, but it still grants significant privileges to the PowerShell process.

#### Utilizing Authbind

Authbind is a tool that allows a non-root user to bind to privileged ports.

**Setup:**
  * Install Authbind, configure it to allow the desired port, and then start your PowerShell script using Authbind.
  * For instance, `authbind --deep pwsh yourscript.ps1` allows the script to bind to a privileged port.

**Advantages:**
  * It provides a finer-grained control over port access and doesn't require setting special capabilities on the PowerShell binary itself.


