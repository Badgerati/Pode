# Basics

!!! warning
    You can only start one server in your script


Although not required, it is recommended to import the Pode module using a maximum version, to avoid any breaking changes from new major versions:

```powershell
Import-Module -Name Pode -MaximumVersion 2.99.99
```

The script for your server should be set in the [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) function, via the `-ScriptBlock` parameter. The following example will listen over HTTP on port 8080, and expose a simple HTML page of running processes at `http://localhost:8080/processes`:

```powershell
Start-PodeServer {
    # attach to port 8080 for http
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # a simple page for displaying services
    Add-PodePage -Name 'processes' -ScriptBlock { Get-Process }
}
```

To start the server you can either:

* Directly run the `./server.ps1` script, or
* If you've created a `package.json` file, ensure the `./server.ps1` script is set as your `main` or `scripts/start`, then just run `pode start` (more [here](../../Getting-Started/CLI))

## Terminating

Once your Pode server has started, you can terminate it at any time using `Ctrl+C`. If you want to disable your server from being terminated then use the `-DisableTermination` switch on the [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) function.

## Restarting

You can restart your Pode server by using `Ctrl+R`, or on Unix you can also use `Shift+C` and `Shift+R` as well. When the server restarts it will only re-invoke the initial `-ScriptBlock`, so any changes made to this main scriptblock will *not* be reflected - you'll need to terminate and start your server again.

## Script from File

You can also define your server's scriptblock in a separate file, and use it via the `-FilePath` parameter on the [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) function.

Using this approach there are 2 ways to start you server:

1. You can put your scriptblock into a separate file, and put your [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) call into another script. This other script is then what you call on the CLI.
2. You can directly call [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) on the CLI.

When you call [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) directly on the CLI, then your server's root path will be set to directory of that file. You can override this behaviour by either defining a path via `-RootPath`, or by telling the server to use the current working path as root via `-CurrentPath`.

For example, the following is a file that contains the same scriptblock for the server at the top of this page. Following that are the two ways to run the server - the first is via another script, and the second is directly from the CLI:

* File.ps1
```powershell
{
    # attach to port 8080 for http
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # a simple page for displaying services
    Add-PodePage -Name 'processes' -ScriptBlock { Get-Process }
}
```

* Server.ps1 (start via script)
```powershell
Start-PodeServer -FilePath './File.ps1'
```
then use `./Server.ps1` on the CLI.

* CLI (start from CLI)
```powershell
PS> Start-PodeServer -FilePath './File.ps1'
```

!!! tip
    Normally when you restart your Pode server any changes to the main scriptblock don't reflect. However, if you reference a file instead, then restarting the server will reload the scriptblock from that file - so any changes will reflect.
