# Basics

All of your main server logic must be set using the  [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) block:

```powershell
Start-PodeServer {
    # attach to port 8080
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # logic for routes, timers, schedules, etc
}
```

!!! warning
    You can only start one server in your script

The above server will start a basic HTTP listener on port 8080. To start the server you can either:

* Directly run the `./server.ps1` script, or
* If you've created a `package.json` file, ensure the `./server.ps1` script is set as your `main` or `scripts/start`, then just run `pode start` (more [here](../../Getting-Started/CLI))

!!! tip
    Once Pode has started, you can exit out at any time using `Ctrl+C`. You can also restart the server by using `Ctrl+R`.
