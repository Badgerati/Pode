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
