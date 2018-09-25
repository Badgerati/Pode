# Shared State

Most things in Pode all run in isolated runspaces, which means you can't create a variable in a timer and then access that variable in a route. To overcome this limitation you can use the [`state`](../../Functions/Utility/State) function, which allows you to set/get variables on a state shared between all runspaces. This means you can create a variable in a timer and set it against the shared state; then you can retrieve that variable from the state in a route.

To do this, you use the [`state`](../../Functions/Utility/State) function with an action of `set`, `get` or `remove`, in combination with the [`lock`](../../Functions/Utility/Lock) function to ensure thread safety

!!! tip
    It's wise to use the `state` function in conjunction with the `lock` function, so as to ensure thread safety between runspaces. The session object supplied to a `route`, `timer`, `schedule` and `logger` each contain a `.Lockable` resource that can be supplied to the `lock` function.

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
Server {
    state set 'data' @{ 'Name' = 'Rick Sanchez' } | Out-Null
}
```

As per the tip above, it's always worth wrapping `state` actions within a `lock`. The following example will set a shared variable in a `timer`, and lock the global `Lockable` object.

```powershell
Server {
    timer 'do-something' 5 {
        param($s)

        lock $s.Lockable {
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
Server {
    $value = (state get 'data')
}
```

As per the tip above, it's always worth wrapping `state` actions within a `lock`. The following example will get a shared variable in a `timer`, and lock the global `Lockable` object.

```powershell
Server {
    timer 'do-something' 5 {
        param($s)
        $value = $null

        lock $s.Lockable {
            $value = (state get 'data')
        }

        # do something with $value
    }
}
```

### Remove

The `state remove` action will remove a variable from the shared state. You only need to supply the variable's name from it to be removed from the state. The action will also return the value stored in the state before removing the variable.

The make-up of the `remove` action is:

```powershell
state remove <name>
```

An example of using the `remove` action to remove a variable from the shared state is as follows:

```powershell
Server {
    state remove 'data' | Out-Null
}
```

As per the tip above, it's always worth wrapping `state` actions within a `lock`. The following example will remove a shared variable in a `timer`, and lock the global `Lockable` object.

```powershell
Server {
    timer 'do-something' 5 {
        param($s)

        lock $s.Lockable {
            state remove 'data' | Out-Null
        }
    }
}
```

## Full Example





The following is a full example of using the `state` function. It is a simple `timer` that creates and updates a `hashtable` variable, and then a `route` is used to retrieve that variable. There is also another route that will remove the variable from the state:


```powershell
Server {
    listen *:8080 http

    # create the shared variable
    state set 'hash' @{ 'values' = @(); } | Out-Null

    # timer to add a random number to the shared state
    timer 'forever' 2 {
        param($s)

        # ensure we're thread safe
        lock $s.Lockable {

            # attempt to get the hashtable from the state
            $hash = (state get 'hash')

            # add a random number
            $hash['values'] += (Get-Random -Minimum 0 -Maximum 10)
        }
    }

    # route to return the value of the hashtable from shared state
    route get '/' {
        param($s)

        # again, ensure we're thread safe
        lock $s.Lockable {

            # get the hashtable from the state and return it
            $hash = (state get 'hash')
            json $hash
        }
    }

    # route to remove the hashable from shared state
    route delete '/' {
        param($s)

        # ensure we're thread safe
        lock $s.Lockable {

            # remove the hashtable from the state
            state remove 'hash' | Out-Null
        }
    }
}
```