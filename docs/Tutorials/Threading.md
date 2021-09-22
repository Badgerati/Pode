# Threading

By default Pode deals with incoming requests synchronously in a single thread. You can increase the number of threads/runspaces that Pode uses to handle requests by using the `-Threads` parameter on [`Start-PodeServer`](../../Functions/Core/Start-PodeServer):

```powershell
Start-PodeServer -Threads 2 {
    # logic
}
```

The number of threads supplied only applies to Web, SMTP, and TCP servers. If `-Threads` is not supplied, or is <=0 then the number of threads is forced to the default of 1.

## Locking

When using multi-threading in Pode at times you'll want to ensure certain functions run thread-safe. To do this you can use [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject) which will lock an object cross-thread.

### Global

In event objects, like `$WebEvent`, there is a global `Lockable` object that you can use - this object is synchronized across every thread, so locking it on one will lock it on all:

```powershell
Add-PodeRoute -Method Get -Path '/save' -ScriptBlock {
    Lock-PodeObject -ScriptBlock {
        Save-PodeState -Path './state.json'
    }
}
```

### Custom

The global lockable is good, but at times you will have separate processes where they can use different lockables objects - rather than sharing a global one and locking each other out needlessly.

To create a custom lockable object you can use [`New-PodeLockable`](../../Functions/Utilities/New-PodeLockable), and this will create a synchronized object across all threads that you can use. You cna then use this object via [`Get-PodeLockable`](../../Functions/Utilities/Get-PodeLockable) and pipe it into [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject):

```powershell
New-PodeLockable -Name 'Lock1'

Add-PodeRoute -Method Get -Path '/save' -ScriptBlock {
    Get-PodeLockable -Name 'Lock1' | Lock-PodeObject -ScriptBlock {
        Save-PodeState -Path './state.json'
    }
}
```

On [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject) there's also a `-CheckGlobal` switch. This switch will check if the global lockable is locked, and wait for it to free up before locking the specified object and running the script. This is useful if you have a number of custom lockables, and then when saving the current state you lock the global. Every other process could lock their custom lockables, but then also check the global lockable and block until saving state is finished.

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
        Get-PodeLockable -Name 'TestLock' | Lock-PodeObject -CheckGlobal -ScriptBlock {}
        Write-PodeJsonResponse -Value @{ Route = 2; Thread = $ThreadId }
    }
}
```
