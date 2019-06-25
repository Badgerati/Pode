# Shared State

Most things in Pode all run in isolated runspaces, which means you can't create a variable in a timer and then access that variable in a route. To overcome this limitation you can use the [`state`](../../Functions/Utility/State) function, which allows you to set/get variables on a state shared between all runspaces. This means you can create a variable in a timer and set it against the shared state; then you can retrieve that variable from the state in a route.

You also have the option of saving the current state to a file, and then restoring the state back on server start. This way you won't lose state between server restarts.

To do this, you use the [`state`](../../Functions/Utility/State) function with an action of `set`, `get`, `remove`, `save` or `restore`, in combination with the [`lock`](../../Functions/Utility/Lock) function to ensure thread safety

!!! tip
    It's wise to use the `state` function in conjunction with the `lock` function, so as to ensure thread safety between runspaces. The argument object supplied to the `route`, `handler`, `timer`, `schedule`, `middleware`, `endware` and `logger` functions each contain a `.Lockable` resource that can be supplied to the `lock` function.

!!! warning
    If you omit the use of `lock`, you will run into errors due to multi-threading. Only omit if you are *absolutely confident* you do not need locking. (ie: you set in state once and then only ever retrieve, never updating the variable).

## Actions

### Set

The `state set` action will create/update a variable on the shared state. You need to supply a name and an object to set on the state. The `set` action will also return the object you're settting.

The make-up of the `set` action is:

```powershell
state set <name> <object>
```

An example of using the `set` action to create a shared hashtable variable is as follows:

```powershell
server {
    state set 'data' @{ 'Name' = 'Rick Sanchez' } | Out-Null
}
```

As per the tip above, it's always worth wrapping `state` actions within a `lock`. The following example will set a shared variable in a `timer`, and lock the global `Lockable` object.

```powershell
server {
    timer 'do-something' 5 {
        param($e)

        lock $e.Lockable {
            state set 'data' @{ 'Name' = 'Rick Sanchez' } | Out-Null
        }
    }
}
```

### Get

The `state get` action will return the value currently stored on the shared state for a variable. You only need to supply the variable's name to get on the value from the state. If the variable doesn't exist then `$null` is returned.

The make-up of the `get` action is:

```powershell
state get <name>
```

An example of using the `get` action to retrieve the value from the shared state is as follows:

```powershell
server {
    $value = (state get 'data')
}
```

As per the tip above, it's always worth wrapping `state` actions within a `lock`. The following example will get a shared variable in a `timer`, and lock the global `Lockable` object.

```powershell
server {
    timer 'do-something' 5 {
        param($e)
        $value = $null

        lock $e.Lockable {
            $value = (state get 'data')
        }

        # do something with $value
    }
}
```

### Remove

The `state remove` action will remove a variable from the shared state. You only need to supply the variable's name for it to be removed from the state. The action will also return the value stored in the state before removing the variable.

The make-up of the `remove` action is:

```powershell
state remove <name>
```

An example of using the `remove` action to remove a variable from the shared state is as follows:

```powershell
server {
    state remove 'data' | Out-Null
}
```

As per the tip above, it's always worth wrapping `state` actions within a `lock`. The following example will remove a shared variable in a `timer`, and lock the global `Lockable` object.

```powershell
server {
    timer 'do-something' 5 {
        param($e)

        lock $e.Lockable {
            state remove 'data' | Out-Null
        }
    }
}
```

### Save

The `state save` action will save the current state, as JSON, to the specified file. The file can either be relative, or a literal path. When saving the state, it's recommended to wrap the action within a `lock`.

The make-up of the `save` action is:

```powershell
state save <file>
```

An example of saving the current state every hour is as follows:

```powershell
server {
    schedule 'save-state' '@hourly' {
        lock $lockable {
            state save './state.json'
        }
    }
}
```

### Restore

The `state restore` action will restore the current state from the specified file. The file can either be relative, or a literal path. if you're restoring the state immediately on server start, you don't need to use `lock`.

The make-up of the `restore` action is:

```powershell
state restore <file>
```

An example of restore the current state on server start is as follows:

```powershell
server {
    state restore './state.json'
}
```

## Full Example

The following is a full example of using the `state` function. It is a simple `timer` that creates and updates a `hashtable` variable, and then a `route` is used to retrieve that variable. There is also another route that will remove the variable from the state. The state is also saved on every iteration of the timer, and restored on server start:

```powershell
server {
    listen *:8080 http

    # create the shared variable
    state set 'hash' @{ 'values' = @(); } | Out-Null

    # attempt to re-initialise the state (will do nothing if the file doesn't exist)
    state restore './state.json'

    # timer to add a random number to the shared state
    timer 'forever' 2 {
        param($e)

        # ensure we're thread safe
        lock $e.Lockable {

            # attempt to get the hashtable from the state
            $hash = (state get 'hash')

            # add a random number
            $hash['values'] += (Get-Random -Minimum 0 -Maximum 10)

            # save the state to file
            state save './state.json'
        }
    }

    # route to return the value of the hashtable from shared state
    route get '/' {
        param($e)

        # again, ensure we're thread safe
        lock $e.Lockable {

            # get the hashtable from the state and return it
            $hash = (state get 'hash')
            json $hash
        }
    }

    # route to remove the hashtable from shared state
    route delete '/' {
        param($e)

        # ensure we're thread safe
        lock $e.Lockable {

            # remove the hashtable from the state
            state remove 'hash' | Out-Null
        }
    }
}
```
