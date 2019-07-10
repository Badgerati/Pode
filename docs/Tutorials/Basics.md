# Basics

Pode at its heart is a PowerShell module, in order to use Pode you'll need to start off by importing it into your scripts:

```powershell
Import-Module Pode
```

After that, all of your main server logic must be wrapped in a [`Server`](../../Functions/Core/Server) block:

```powershell
Import-Module Pode

Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    # logic for routes, timers, schedules, etc
}
```

!!! warning
    You can only have one `Server` declared in your script

The above `Server` will start a basic HTTP listener on port 8080. To start the server you can either:

* Directly run the `./server.ps1` script, or
* If you've created a `package.json` file, ensure the `./server.ps1` script is set as your `main` or `scripts/start`, then just run `pode start` (more [here](../../Getting-Started/CLI))

!!! tip
    Once Pode has started, you can exit out at any time using `Ctrl+C`. You can also restart the server by using `Ctrl+R`.
