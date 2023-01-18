# Lockables

When using multi-threading in Pode at times you'll want to ensure certain functions run thread-safe. To do this you can use [`Lock-PodeObject`](../../../Functions/Threading/Lock-PodeObject) which will lock an object across threads.

## Global

In event objects, like `$WebEvent`, there is a global `Lockable` object that you can use - this object is synchronized across every thread, so locking it on one thread will lock it on all threads:

```powershell
Add-PodeRoute -Method Get -Path '/save' -ScriptBlock {
    Lock-PodeObject -ScriptBlock {
        Save-PodeState -Path './state.json'
    }
}
```

## Custom

The global lockable is good, but at times you will have separate processes where they can use different lockable objects - rather than sharing a global one and locking each other out needlessly.

To create a custom lockable object you can use [`New-PodeLockable`](../../../Functions/Threading/New-PodeLockable), and this will create a synchronized object across all threads that you can use. You can then use this object via [`Get-PodeLockable`](../../../Functions/Threading/Get-PodeLockable) and pipe it into [`Lock-PodeObject`](../../../Functions/Threading/Lock-PodeObject):

```powershell
New-PodeLockable -Name 'Lock1'

Add-PodeRoute -Method Get -Path '/save' -ScriptBlock {
    Get-PodeLockable -Name 'Lock1' | Lock-PodeObject -ScriptBlock {
        Save-PodeState -Path './state.json'
    }
}
```

Similarly, you can reference the lockable directly by name:

```powershell
New-PodeLockable -Name 'Lock1'

Add-PodeRoute -Method Get -Path '/save' -ScriptBlock {
    Lock-PodeObject -Name 'Lock1' -ScriptBlock {
        Save-PodeState -Path './state.json'
    }
}
```

On [`Lock-PodeObject`](../../../Functions/Threading/Lock-PodeObject) there's also a `-CheckGlobal` switch. This switch will check if the global lockable is locked, and wait for it to free up before locking the specified object and running the script. This is useful if you have a number of custom lockables, and then when saving the current state you lock the global. Every other process could lock their custom lockables, but then also check the global lockable and block until saving state is finished.

For example, the following has two routes. The first route locks the global lockable and sleeps for 10 seconds, whereas the second route locks the custom object but checks the global for locking. Calling the first route then the second straight after, they will both return after 10 seconds:

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    New-PodeLockable -Name 'TestLock'

    # lock global, sleep for 10secs
    Add-PodeRoute -Method Get -Path '/route1' -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    # lock custom, but check global
    Add-PodeRoute -Method Get -Path '/route2' -ScriptBlock {
        Lock-PodeObject -Name 'TestLock' -CheckGlobal -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }
}
```

## Enter / Exit

You can have more advanced control over the locking of lockables, and other objects, by using [`Enter-PodeLockable`](../../../Functions/Threading/Enter-PodeLockable) and [`Exit-PodeLockable`](../../../Functions/Threading/Exit-PodeLockable). Using these functions you can place a lock on a lockable, run some logic, and then remove the lock - but you don't have to do it all in the same function or scriptblock.

[`Enter-PodeLockable`](../../../Functions/Threading/Enter-PodeLockable) can be used to initially place a lock on a lockable, and then you must call [`Exit-PodeLockable`](../../../Functions/Threading/Exit-PodeLockable) later on to remove the lock:

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    New-PodeLockable -Name 'TestLock'

    # lock object and sleep for 10secs
    Add-PodeRoute -Method Get -Path '/route1' -ScriptBlock {
        try {
            Enter-PodeLockable -Name 'TestLock'
            Start-Sleep -Seconds 10
        }
        finally {
            Exit-PodeLockable -Name 'TestLock'
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }
}
```

## Timeout

When locking a lockable, or another object, by default Pode will wait indefinitely for the object to be unlocked before locking it. You can use the `-Timeout` parameter to specify a number of milliseconds to timeout after if a lock cannot be acquired.

```powershell
Start-PodeServer -Threads 2 {
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    New-PodeLockable -Name 'TestLock'

    # lock object and sleep for 10secs
    Add-PodeRoute -Method Get -Path '/route1' -ScriptBlock {
        Lock-PodeObject -Name 'TestLock' -ScriptBlock {
            Start-Sleep -Seconds 10
        }

        Write-PodeJsonResponse -Value @{ Route = 1; Thread = $ThreadId }
    }

    # lock object, but timeout after 2s
    Add-PodeRoute -Method Get -Path '/route2' -ScriptBlock {
        Lock-PodeObject -Name 'TestLock' -Timeout 2000 -ScriptBlock {
            Start-Sleep -Seconds 2
        }

        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }
}
```
