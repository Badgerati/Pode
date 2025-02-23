# Shared State

Most things in Pode run in isolated runspaces: routes, middleware, schedules - to name a few. This means you can't create a variable in a timer, and then access that variable in a route. To overcome this limitation you can use the Shared State feature within Pode, which allows you to set/get variables on a state shared between all runspaces. This lets you create a variable in a timer and store it within the shared state; then you can retrieve the variable from the state in a route.

You also have the option of saving the current state to a file, and then restoring the state back on server start. This way you won't lose state between server restarts.

Pode supports various structures for shared state, some of which are thread-safe:

**Thread-Safe Structures:**

- `ConcurrentDictionary`
- `ConcurrentBag`
- `ConcurrentQueue`
- `ConcurrentStack`

**Non-Thread-Safe Structures (Require Locking):**

- `OrderedDictionary`
- `Hashtable`
- `PSCustomObject`When using a thread-safe object, `Lock-PodeObject` is no longer required.

!!! tip
It's wise to use the State in conjunction with [`Lock-PodeObject`](../../Functions/Threading/Lock-PodeObject) when dealing with non-thread-safe objects to ensure thread safety between runspaces.

!!! warning
If you are using a non-thread-safe object, such as `Hashtable`, `OrderedDictionary`, or `PSCustomObject`, you should use [`Lock-PodeObject`](../../Functions/Threading/Lock-PodeObject) to ensure thread safety between runspaces. Omitting this may lead to concurrency issues and unpredictable behavior.

## Usage

Where possible, use the same casing for the `-Name` of state keys. When using [`Restore-PodeState`](../../Functions/State/Restore-PodeState), the state will become case-sensitive due to the nature of how `ConvertFrom-Json` works.

### Set

#### **NewCollectionType Parameter**

The `-NewCollectionType` parameter allows users to specify the type of collection to initialize within the shared state. This eliminates the need to manually instantiate collections before setting them in the state.

**Supported Collection Types:**

- `Hashtable`
- `ConcurrentDictionary`
- `OrderedDictionary`
- `ConcurrentBag`
- `ConcurrentQueue`
- `ConcurrentStack`

If `-NewCollectionType` is used, the specified collection type will be created and stored in the state. The `-Value` parameter is ignored when this option is used.

**Examples:**

```powershell
# Set a simple hashtable in shared state
Set-PodeState -Name 'Data' -Value @{ 'Name' = 'Rick Sanchez' }

# Initialize a ConcurrentDictionary instead of providing a value
Set-PodeState -Name 'Cache' -NewCollectionType 'ConcurrentDictionary'

# Create a ConcurrentQueue for shared state management
Set-PodeState -Name 'Tasks' -NewCollectionType 'ConcurrentQueue'
```

The [`Set-PodeState`](../../Functions/State/Set-PodeState) function will create/update a variable in the state. You need to supply a name and a value to set on the state, and there's also an optional scope that can be supplied - which lets you save specific state objects with a certain scope.

!!! tip
The .NET collections `ConcurrentDictionary` and `OrderedDictionary` are case-sensitive by default. To make them case-insensitive, initialize them as follows:

```powershell
# Case-insensitive ConcurrentDictionary
Set-PodeState -Name 'Cache' -Value ([System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase))

# Case-insensitive OrderedDictionary
Set-PodeState -Name 'Config' -Value ([System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase))

# Case-insensitive OrderedDictionary
Set-PodeState -Name 'Running' -Value ([ordered]@{})
```

Alternatively, you can use:

```powershell
Set-PodeState -Name 'Cache' -NewCollectionType 'ConcurrentDictionary'
Set-PodeState -Name 'Config' -NewCollectionType 'OrderedDictionary'
Set-PodeState -Name 'Running' -NewCollectionType 'OrderedDictionary'
```

#### Example: Non-Thread-Safe Objects

If using a non-thread-safe object, such as `Hashtable`, `OrderedDictionary`, or `PSCustomObject`, wrap access to the state in `Lock-PodeObject` to prevent concurrency issues.

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Set-PodeState -Name 'data' -Value @{ 'Name' = 'Rick Sanchez' } | Out-Null
        }
    }
}
```

The [`Set-PodeState`](../../Functions/State/Set-PodeState) function will create/update a variable in the state. You need to supply a name and a value to set on the state, and there's also an optional scope that can be supplied - which lets you save specific state objects with a certain scope.

An example of setting a `ConcurrentDictionary` variable in the state is as follows:

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        Set-PodeState -Name 'data' -Value ([System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new()) | Out-Null
    }
}
```

### Get

The [`Get-PodeState`](../../Functions/State/Get-PodeState) function will return the value currently stored in the state for a variable. If the variable doesn't exist, `$null` is returned.

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        $value = (Get-PodeState -Name 'data')

        # do something with $value
    }
}
```

### Remove

The [`Remove-PodeState`](../../Functions/State/Remove-PodeState) function will remove a variable from the state. It will also return the value stored in the state before removing the variable.

```powershell
Start-PodeServer {
    Add-PodeTimer -Name 'do-something' -Interval 5 -ScriptBlock {
        Remove-PodeState -Name 'data' | Out-Null
    }
}
```

### Save

The [`Save-PodeState`](../../Functions/State/Save-PodeState) function will save the current state, as JSON, to the specified file. The file path can either be relative or literal. When saving the state, it's recommended to wrap the function within [`Lock-PodeObject`](../../Functions/Threading/Lock-PodeObject) if dealing with non-thread-safe objects.

```powershell
Start-PodeServer {
    Add-PodeSchedule -Name 'save-state' -Cron '@hourly' -ScriptBlock {
        Save-PodeState -Path './state.json'
    }
}
```

### Restore

The [`Restore-PodeState`](../../Functions/State/Restore-PodeState) function will restore the current state from the specified file. The file path can either be relative or a literal path. If you're restoring the state immediately on server start, you don't need to use [`Lock-PodeObject`](../../Functions/Threading/Lock-PodeObject).

```powershell
Start-PodeServer {
    Restore-PodeState './state.json'
}
```

## Full Example

The following is a full example of using the State functions. It is a simple Timer that creates and updates a `ConcurrentDictionary` variable, and then a Route is used to retrieve that variable. There is also another route that will remove the variable from the state. The state is also saved on every iteration of the timer and restored on server start:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # create the shared variable
    Set-PodeState -Name 'dict' -Value ([System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()) | Out-Null

    # attempt to re-initialize the state (will do nothing if the file doesn't exist)
    Restore-PodeState -Path './state.json'

    # timer to add a random number to the shared state
    Add-PodeTimer -Name 'forever' -Interval 2 -ScriptBlock {
        $dict = (Get-PodeState -Name 'dict')
        $dict["random"] = (Get-Random -Minimum 0 -Maximum 10)
        Save-PodeState -Path './state.json'
    }

    # route to return the value of the dictionary from shared state
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        $dict = (Get-PodeState -Name 'dict')
        Write-PodeJsonResponse -Value $dict
    }

    # route to remove the dictionary from shared state
    Add-PodeRoute -Method Delete -Path '/' -ScriptBlock {
        Remove-PodeState -Name 'dict' | Out-Null
    }
}
```

