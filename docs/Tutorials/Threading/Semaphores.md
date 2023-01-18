# Semaphores

Semaphores are similar to [Mutexes](./Mutexes), in that they let you control thread synchronisation across different processes, whether they be child-processes; processes running on the current login session; or every process running on the system. The difference being that a Semaphore allows you to control the number of processes that can enter the Semaphore at once, unlike a Mutex which is just one at a time.

!!! note
    When the `-Count` for a Semaphore is set to 1 they're basically the same as Mutexes.

## Creating a Semaphore

To create a Semaphore in Pode you can use [`New-PodeSemaphore`](../../../Functions/Threading/New-PodeSemaphore), this will either create a Semaphore or retrieve an existing Semaphore if one already exists within the selected scope.

A Semaphore will need a `-Name` and a `-Scope`. You can also optionally supply a `-Count` which is the number of processes allowed to enter the Semaphore at once - the default be 1. The default scope is Self, but other options are Local or Global:

| Scope | Description |
| ----- | ----------- |
| Self | The current process, or child processes |
| Local | All processes for the current login session on Windows, or the the same as Self on Unix |
| Global | All processes on the system, across every session |

The following example will create a new global Semaphore, which allows 2 processes to enter at once:

```powershell
Start-PodeServer {
    New-PodeSemaphore -Name 'ExampleSemaphore' -Scope Global -Count 2
}
```

Once created, you can use the Semaphore in [`Use-PodeSemaphore`](../../../Functions/Threading/Use-PodeSemaphore), [`Enter-PodeSemaphore`](../../../Functions/Threading/Enter-PodeSemaphore), and [`Exit-PodeSemaphore`](../../../Functions/Threading/Exit-PodeSemaphore).

## Using a Semaphore

To use a Semaphore after creating one you can use [`Use-PodeSemaphore`](../../../Functions/Threading/Use-PodeSemaphore) to enter a Semaphore; invoke a scriptblock; and then exit a Semaphore to free it up for another process - depending on how many processes can enter the Semaphore at once.

Below are 2 scripts for creating 2 Pode servers, similar to the example in [Mutexes](./Mutexes#using-a-mutex). Both create the same global Semaphore, and then use te Semaphore to invoke a scriptblock. In 1 server the scriptblock sleeps for 10 seconds, and in the other for 2 seconds. If you run both servers and call the first server's Route, and then the second, the second won't block while the first is still running. However, if you were to call the second server's Route twice in different terminals the first call would return after 2 seconds, but the second call would return after 4 seconds - as only 2 processes can enter the Semaphore at once.

* First server
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    New-PodeSemaphore -Name 'GlobalSemaphore' -Scope Global -Count 2

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        Use-PodeSemaphore -Name 'GlobalSemaphore' -ScriptBlock {
            Start-Sleep -Seconds 10
        }
    }
}
```

* Second server
```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    New-PodeSemaphore -Name 'GlobalSemaphore' -Scope Global -Count 2

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        Use-PodeSemaphore -Name 'GlobalSemaphore' -ScriptBlock {
            Start-Sleep -Seconds 2
        }
    }
}
```

## Enter / Exit

You can have more advanced control over the using of Semaphores via [`Enter-PodeSemaphore`](../../../Functions/Threading/Enter-PodeSemaphore) and [`Exit-PodeSemaphore`](../../../Functions/Threading/Exit-PodeSemaphore). Using these functions you can enter a Semaphore, run some logic, and then exit the Semaphore - but you don't have to do it all in the same function or scriptblock.

[`Enter-PodeSemaphore`](../../../Functions/Threading/Enter-PodeSemaphore) can be used to initially place enter a Semaphore, and then you must call [`Exit-PodeSemaphore`](../../../Functions/Threading/Exit-PodeSemaphore) later on to exit the Semaphore:

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    New-PodeSemaphore -Name 'GlobalSemaphore' -Scope Global -Count 2

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        try {
            Enter-PodeSemaphore -Name 'GlobalSemaphore'
            Start-Sleep -Seconds 10
        }
        finally {
            Exit-PodeSemaphore -Name 'GlobalSemaphore'
        }
    }
}
```

[`Exit-PodeSemaphore`](../../../Functions/Threading/Exit-PodeSemaphore) also allows you to exit the Semaphore X number of times via `-ReleaseCount`.

## Timeout

When using a Semaphore by default Pode will wait indefinitely for the Semaphore to be released before entering it. You can use the `-Timeout` parameter to specify a number of milliseconds to timeout after if a Semaphore fails be released.

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    New-PodeSemaphore -Name 'GlobalSemaphore' -Scope Global -Count 2

    Add-PodeRoute -Method Get -Path '/sleep' -ScriptBlock {
        Use-PodeSemaphore -Name 'GlobalSemaphore' -Timeout 2000 -ScriptBlock {
            Start-Sleep -Seconds 2
        }
    }
}
```
