# Debugging Pode

When using Pode there will often be times when you need to debug aspects of your scripts. Debugging in Pode can be achieved in a couple of ways:

1. Write messages to the console.
2. Use PowerShell's debugger.

## Messages

To output messages from your Routes, Timers, etc. you can either call PowerShell's `Out-Default`, or Pode's [`Out-PodeHost`](../../Functions/Utilities/Out-PodeHost). The latter is just a wrapper around `Out-Default` however, it respects the `-Quiet` switch if supplied to [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) - suppressing the messages when not needed.

For example, the following will output messages and variables from a Route:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        'Start of / Route' | Out-PodeHost
        $processes = Get-Process
        "Processes found: $($processes.Length)" | Out-PodeHost
        $processes[0] | Out-PodeHost
        Write-PodeJsonResponse -Value @{ Process = $processes[0] }
    }
}
```

This will output 3 messages to the host window where Pode is running when the Route is invoked, as follows:

```powershell
Invoke-RestMethod -Uri 'http://localhost:8080/'
```

```plain
Start of / Route
Processes found: 393

 NPM(K)    PM(M)      WS(M)     CPU(s)      Id  SI ProcessName
 ------    -----      -----     ------      --  -- -----------
      7     2.45       3.66       3.48    7044   0 AggregatorHost
```

!!! tip
    You can leave the `Out-PodeHost` lines in place, and suppress them by passing `-Quiet` to `Start-PodeServer`.

## Debugger

You can breakpoint directly into a running Pode server by using either PowerShell's `Wait-Debugger` or Pode's [`Wait-PodeDebugger`](../../Functions/Core/Wait-PodeDebugger). The latter is just a wrapper around `Wait-Debugger` however, it respects the `-EnableBreakpoints` switch if supplied to [`Start-PodeServer`](../../Functions/Core/Start-PodeServer) - allowing you to suppress the breakpoints when not needed. Regardless of the Wait command chosen, the process to attach to the Pode process is the same.

For example, the following will create a breakpoint for PowerShell's debugger when the Route is invoked:

```powershell
Start-PodeServer -EnableBreakpoints {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Wait-PodeDebugger
        $processes = Get-Process
        Write-PodeJsonResponse -Value @{ Process = $processes[0] }
    }
}
```

The steps to attach to the Pode process are as follows:

1. In a PowerShell console, start the above Pode server. You will see the following output, and you'll need the PID that is shown:
    ```plain
    Pode v2.10.0 (PID: 28324)
    Listening on the following 1 endpoint(s) [1 thread(s)]:
        - http://localhost:8080/
    ```

2. In a browser or a new PowerShell console, invoke the `[GET] http://localhost:8080` Route to hit the breakpoint.
    ```powershell
    Invoke-RestMethod -Uri 'http://localhost:8080/'
    ```

3. Open another new PowerShell console, and run the following command to enter the first PowerShell console running Pode - you'll need the PID as well:
    ```powershell
    Enter-PSHostProcess -Id '<PID_HERE>'
    ```

4. Once you have entered the PowerShell console running Pode, run the below command to attach to the breakpoint:
    ```powershell
    Get-Runspace |
        Where-Object { $_.Debugger.InBreakpoint } |
        Select-Object -First 1 |
        Debug-Runspace -Confirm:$false
    ```

    1. If you used `Wait-PodeDebugger` you'll need to hit the `s` key twice to get to the next actual line.

5. Hit the `h` key to see the debugger commands you can use. In general, you'll be after:
    1. `s`: step into the next line, function, script
    2. `v`: step over the next line
    3. `o`: step out of the current function
    4. `d`: detach from the debugger, and let the script complete

6. You'll also be able to query variables as well, such as `$WebEvent` and other variables you might have created.

7. When you are done debugging the current request, hit the `d` key.

8. When you're done with debugging altogether, you can exit the entered process as follows:
    ```powershell
    exit
    ```

### Toggle Breakpoints

If you're using [`Wait-PodeDebugger`](../../Functions/Core/Wait-PodeDebugger) then you can leave these breakpoint lines in place, and toggle them in non-developer environments by passing `-EnableBreakpoints` to [`Start-PodeServer`](../../Functions/Core/Start-PodeServer). If you don't supply `-EnableBreakpoints`, or you explicitly pass `-EnableBreakpoints:$false`, then this will disable the breakpoints from being set.

You can also toggle breakpoints via the `server.psd1` [configuration file](../../Tutorials/Configuration):
```powershell
@{
    Server = @{
        Debug = @{
            Breakpoints = @{
                Enable = $true
            }
        }
    }
}
```

!!! note
    The default state is disabled.

### Add-Debugger

You can also use the [Add-Debugger](https://www.powershellgallery.com/packages/Add-Debugger) script from the PowerShell Gallery, allowing you to debug your Pode server within the same console that started Pode - making the debug process smoother, and not requiring multiple PowerShell consoles.

To install `Add-Debugger`, you can do the following:

```powershell
Install-Script -Name Add-Debugger
```

Once installed, you'll be able to use the `Add-Debugger` command within your Routes/etc., alongside `Wait-Debugger`/`Wait-PodeDebugger`.

!!! note
    If you're using `-EnableBreakpoints`, then setting this to false will not suppress calls to `Add-Debugger`.

```powershell
Start-PodeServer -EnableBreakpoints {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Add-Debugger
        Wait-PodeDebugger
        $processes = Get-Process
        Write-PodeJsonResponse -Value @{ Process = $processes[0] }
    }
}
```

The steps to attach to the Pode process are as follows:

1. In a PowerShell console, start the above Pode server.

2. In a browser or a new PowerShell console, invoke the `[GET] http://localhost:8080` Route to hit the breakpoint.
    ```powershell
    Invoke-RestMethod -Uri 'http://localhost:8080/'
    ```

3. Back in the PowerShell console running Pode, you'll see that it is now attached to the breakpoint for debugging.
    1. If you used `Wait-PodeDebugger` you'll need to hit the `s` key twice to get to the next actual line.

4. Hit the `h` key to see the debugger commands you can use. In general, you'll be after:
    1. `s`: step into the next line, function, script
    2. `v`: step over the next line
    3. `o`: step out of the current function
    4. `d`: detach from the debugger, and let the script complete

5. You'll also be able to query variables as well, such as `$WebEvent` and other variables you might have created.

6. When you are done debugging the current request, hit the `d` key.
