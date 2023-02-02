# Mutexes

Other than [Lockables](./Lockables), Pode also lets you create Mutexes. A Mutex lets you control thread synchronisation across different processes, whether they be child-processes; processes running on the current login session; or every process running on the system.

## Creating a Mutex

To create a Mutex in Pode you can use [`New-PodeMutex`](../../../Functions/Threading/New-PodeMutex), this will either create a Mutex or retrieve an existing Mutex if one already exists within the selected scope.

A Mutex will need a `-Name` but also a `-Scope`. The default scope is Self, but other options are Local or Global:

| Scope | Description |
| ----- | ----------- |
| Self | The current process, or child processes |
| Local | All processes for the current login session on Windows, or the the same as Self on Unix |
| Global | All processes on the system, across every session |

The following example will create a new global Mutex:

```powershell
Start-PodeServer {
    New-PodeMutex -Name 'ExampleMutex' -Scope Global
}
```

Once created, you can use the Mutex in [`Use-PodeMutex`](../../../Functions/Threading/Use-PodeMutex), [`Enter-PodeMutex`](../../../Functions/Threading/Enter-PodeMutex), and [`Exit-PodeMutex`](../../../Functions/Threading/Exit-PodeMutex).

## Using a Mutex

To use a Mutex after creating one you can use [`Use-PodeMutex`](../../../Functions/Threading/Use-PodeMutex) to enter a Mutex; invoke a scriptblock; and then exit a Mutex to free it up for another process.

Below are 2 scripts for creating 2 Pode servers. Both create the same global Mutex, and then use te Mutex to invoke a scriptblock. In 1 server the scriptblock sleeps for 10 seconds, and in the other for 2 seconds. If you run both servers and call the first server's Route, and then the second, the second will block until the first finishes - even though they're in different servers/threads.

* First server
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    New-PodeMutex -Name 'GlobalMutex' -Scope Global

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        Use-PodeMutex -Name 'GlobalMutex' -ScriptBlock {
            Start-Sleep -Seconds 10
        }
    }
}
```

* Second server
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    New-PodeMutex -Name 'GlobalMutex' -Scope Global

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        Use-PodeMutex -Name 'GlobalMutex' -ScriptBlock {
            Start-Sleep -Seconds 2
        }
    }
}
```

## Enter / Exit

You can have more advanced control over the using of Mutexes via [`Enter-PodeMutex`](../../../Functions/Threading/Enter-PodeMutex) and [`Exit-PodeMutex`](../../../Functions/Threading/Exit-PodeMutex). Using these functions you can enter a Mutex, run some logic, and then exit the Mutex - but you don't have to do it all in the same function or scriptblock.

[`Enter-PodeMutex`](../../../Functions/Threading/Enter-PodeMutex) can be used to initially place enter a Mutex, and then you must call [`Exit-PodeMutex`](../../../Functions/Threading/Exit-PodeMutex) later on to exit the Mutex:

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    New-PodeMutex -Name 'GlobalMutex' -Scope Global

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        try {
            Enter-PodeMutex -Name 'GlobalMutex'
            Start-Sleep -Seconds 10
        }
        finally {
            Exit-PodeMutex -Name 'GlobalMutex'
        }
    }
}
```

## Timeout

When using a Mutex by default Pode will wait indefinitely for the Mutex to be released before entering it. You can use the `-Timeout` parameter to specify a number of milliseconds to timeout after if a Mutex fails be released.

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    New-PodeMutex -Name 'GlobalMutex' -Scope Global

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        Use-PodeMutex -Name 'GlobalMutex' -Timeout 2000 -ScriptBlock {
            Start-Sleep -Seconds 2
        }
    }
}
```
