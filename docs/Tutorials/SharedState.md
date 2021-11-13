# Shared State

Most things in Pode run in isolated runspaces: routes, middleware, schedules - to name a few. This means you can't create a variable in a timer, and then access that variable in a route. To overcome this limitation you can use the Shared State feature within Pode, which allows you to set/get variables on a state shared between all runspaces. This lets you can create a variable in a timer and store it within the shared state; then you can retrieve the variable from the state in a route.

You also have the option of saving the current state to a file, and then restoring the state back on server start. This way you won't lose state between server restarts.

You can also use the State in combination with [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject) to ensure thread safety - if needed.

!!! tip
    It's wise to use the State in conjunction with [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject), to ensure thread safety between runspaces.

!!! warning
    If you omit the use of [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject), you might run into errors due to multi-threading. Only omit if you are *absolutely confident* you do not need locking. (ie: you set in state once and then only ever retrieve, never updating the variable).

## Usage

Where possible use the same casing for the `-Name` of state keys. When using [`Restore-PodeState`](../../Functions/State/Restore-PodeState) the state will become case-sensitive due to the nature of how `ConvertFrom-Json` works.

### Set

The [`Set-PodeState`](../../Functions/State/Set-PodeState) function will create/update a variable in the state. You need to supply a name and a value to set on the state, there's also an optional scope that can be supplied - which lets you save specific state objects with a certain scope.

An example of setting a hashtable variable in the state is as follows:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Set-PodeState -Name 'data' -Value @{ 'Name' = 'Rick Sanchez' } | Out-Null
        }
    }
}
```

Alternatively you could use the `$state:` variable scope to set a variable in state. This variable will be scopeless, so if you need scope then use [`Set-PodeState`](../../Functions/State/Set-PodeState). `$state:` can be used anywhere, but keep in mind that like `$session:` Pode can only remap the this in scriptblocks it's aware of; so using it in a function of a custom module won't work. Similar to the example above:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            $state:data = @{ 'Name' = 'Rick Sanchez' }
        }
    }
}
```

### Get

The [`Get-PodeState`](../../Functions/State/Get-PodeState) function will return the value currently stored in the state for a variable. If the variable doesn't exist then `$null` is returned.

An example of retrieving a value from the state is as follows:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        $value = $null

        Lock-PodeObject -ScriptBlock {
            $value = (Get-PodeState -Name 'data')
        }

        # do something with $value
    }
}
```

Alternatively you could use the `$state:` variable scope to get a variable in state. `$state:` can be used anywhere, but keep in mind that like `$session:` Pode can only remap the this in scriptblocks it's aware of; so using it in a function of a custom module won't work. Similar to the example above:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        $value = $null

        Lock-PodeObject -ScriptBlock {
            $value = $state:data
        }

        # do something with $value
    }
}
```

### Remove

The [`Remove-PodeState`](../../Functions/State/Remove-PodeState) function will remove a variable from the state. It will also return the value stored in the state before removing the variable.

An example of removing a variable from the state is as follows:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Remove-PodeState -Name 'data' | Out-Null
        }
    }
}
```

### Save

The [`Save-PodeState`](../../Functions/State/Save-PodeState) function will save the current state, as JSON, to the specified file. The file path can either be relative, or literal. When saving the state, it's recommended to wrap the function within [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject).

An example of saving the current state every hour is as follows:

```powershell
Start-PodeServer {
    Add-PodeSchedule -Name 'save-state' -Cron '@hourly' -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Save-PodeState -Path './state.json'
        }
    }
}
```

When saving the state, you can also use the `-Exclude` or `-Include` parameters to exclude/include certain state objects from being saved. Saving also has a `-Scope` parameter, which allows you so save only state objects created with the specified scope(s).

You can use all the above 3 parameter in conjunction, with `-Exclude` having the highest precedence and `-Scope` having the lowest.

By default the JSON will be saved expanded, but you can saved the JSON as compressed by supplying the `-Compress` switch.

### Restore

The [`Restore-PodeState`](../../Functions/State/Restore-PodeState) function will restore the current state from the specified file. The file path can either be relative, or a literal path. if you're restoring the state immediately on server start, you don't need to use [`Lock-PodeObject`](../../Functions/Utilities/Lock-PodeObject).

An example of restore the current state on server start is as follows:

```powershell
Start-PodeServer {
    Restore-PodeState './state.json'
}
```

By default, restoring from a state file will overwrite the current state. You can change this so the restored state is merged instead by using the `-Merge` switch. (Note: if you restore a key that already exists in state, this will still overwrite that key).

## Full Example

The following is a full example of using the State functions. It is a simple Timer that creates and updates a `hashtable` variable, and then a Route is used to retrieve that variable. There is also another route that will remove the variable from the state. The state is also saved on every iteration of the timer, and restored on server start:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # create the shared variable
    Set-PodeState -Name 'hash' -Value @{ 'values' = @(); } | Out-Null

    # attempt to re-initialise the state (will do nothing if the file doesn't exist)
    Restore-PodeState -Path './state.json'

    # timer to add a random number to the shared state
    Add-PodeTimer -Name 'forever' -Interval 2 -ScriptBlock {
        # ensure we're thread safe
        Lock-PodeObject -ScriptBlock {
            # attempt to get the hashtable from the state
            $hash = (Get-PodeState -Name 'hash')

            # add a random number
            $hash.values += (Get-Random -Minimum 0 -Maximum 10)

            # save the state to file
            Save-PodeState -Path './state.json'
        }
    }

    # route to return the value of the hashtable from shared state
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        # again, ensure we're thread safe
        Lock-PodeObject -ScriptBlock {
            # get the hashtable from the state and return it
            $hash = (Get-PodeState -Name 'hash')
            Write-PodeJsonResponse -Value $hash
        }
    }

    # route to remove the hashtable from shared state
    Add-PodeRoute -Method Delete -Path '/' -ScriptBlock {
        # ensure we're thread safe
        Lock-PodeObject -ScriptBlock {
            # remove the hashtable from the state
            Remove-PodeState -Name 'hash' | Out-Null
        }
    }
}
```
