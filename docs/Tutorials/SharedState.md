# Shared State

Most things in Pode all run in isolated runspaces, which means you can't create a variable in a timer and then access that variable in a route. To overcome this limitation you can use the State functions, which allows you to set/get variables on a state shared between all runspaces. This means you can create a variable in a timer and set it against the shared state; then you can retrieve the variable from the state in a route.

You also have the option of saving the current state to a file, and then restoring the state back on server start. This way you won't lose state between server restarts.

To do this, you use the State functions in combination with the [`lock`](../../Functions/Utility/Lock) function to ensure thread safety.

!!! tip
    It's wise to use the State functions in conjunction with the `lock` function, so as to ensure thread safety between runspaces. The argument supplied to the Routes, Handlers, Timers, Schedules, Middleware, Endware and Loggers each contain a `.Lockable` resource that can be supplied to the `lock` function.

!!! warning
    If you omit the use of `lock`, you will run into errors due to multi-threading. Only omit if you are *absolutely confident* you do not need locking. (ie: you set in state once and then only ever retrieve, never updating the variable).

## Usage

### Set

The `Set-PodeState` function will create/update a variable on the shared state. You need to supply a name and a value to set on the state.

An example of setting a shared hashtable variable is as follows:

```powershell
Start-PodeServer {
    timer 'do-something' 5 {
        param($e)

        Lock-PodeObject -Object $e.Lockable {
            Set-PodeState -Name 'data' -Value @{ 'Name' = 'Rick Sanchez' } | Out-Null
        }
    }
}
```

### Get

The `Get-PodeState` function will return the value currently stored on the shared state for a variable. If the variable doesn't exist then `$null` is returned.

An example of retrieving the value from the shared state is as follows:

```powershell
Start-PodeServer {
    timer 'do-something' 5 {
        param($e)
        $value = $null

        Lock-PodeObject -Object $e.Lockable {
            $value = (Get-PodeState -Name 'data')
        }

        # do something with $value
    }
}
```

### Remove

The `Remove-PodeState` function will remove a variable from the shared state. It will also return the value stored in the state before removing the variable.

An example of removing a variable from the shared state is as follows:

```powershell
Start-PodeServer {
    timer 'do-something' 5 {
        param($e)

        Lock-PodeObject -Object $e.Lockable {
            Remove-PodeState -Name 'data' | Out-Null
        }
    }
}
```

### Save

The `Save-PodeState` function will save the current state, as JSON, to the specified file. The file path can either be relative, or a literal path. When saving the state, it's recommended to wrap the function within a `lock`.

An example of saving the current state every hour is as follows:

```powershell
Start-PodeServer {
    schedule 'save-state' '@hourly' {
        Lock-PodeObject -Object $lockable {
            Save-PodeState -Path './state.json'
        }
    }
}
```

### Restore

The `Restore-PodeState` function will restore the current state from the specified file. The file path can either be relative, or a literal path. if you're restoring the state immediately on server start, you don't need to use `lock`.

An example of restore the current state on server start is as follows:

```powershell
Start-PodeServer {
    Restore-PodeState './state.json'
}
```

## Full Example

The following is a full example of using the State functions. It is a simple Timer that creates and updates a `hashtable` variable, and then a Route is used to retrieve that variable. There is also another route that will remove the variable from the state. The state is also saved on every iteration of the timer, and restored on server start:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    # create the shared variable
    Set-PodeState -Name 'hash' -Value @{ 'values' = @(); } | Out-Null

    # attempt to re-initialise the state (will do nothing if the file doesn't exist)
    Restore-PodeState -Path './state.json'

    # timer to add a random number to the shared state
    timer 'forever' 2 {
        param($e)

        # ensure we're thread safe
        Lock-PodeObject -Object $e.Lockable {

            # attempt to get the hashtable from the state
            $hash = (Get-PodeState -Name 'hash')

            # add a random number
            $hash['values'] += (Get-Random -Minimum 0 -Maximum 10)

            # save the state to file
            Save-PodeState -Path './state.json'
        }
    }

    # route to return the value of the hashtable from shared state
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($e)

        # again, ensure we're thread safe
        Lock-PodeObject -Object $e.Lockable {

            # get the hashtable from the state and return it
            $hash = (Get-PodeState -Name 'hash')
            Write-PodeJsonResponse -Value $hash
        }
    }

    # route to remove the hashtable from shared state
    Add-PodeRoute -Method Delete -Path '/' -ScriptBlock {
        param($e)

        # ensure we're thread safe
        Lock-PodeObject -Object $e.Lockable {

            # remove the hashtable from the state
            Remove-PodeState -Name 'hash' | Out-Null
        }
    }
}
```
