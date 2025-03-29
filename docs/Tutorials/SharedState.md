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
- `PSCustomObject`

When using a thread-safe object, `Lock-PodeObject` is no longer required.

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

!!! warning
When using `.NET` concurrent collections, only certain generic types are supported for JSON serialization.

✅ **Supported forms:**

- `[System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)`
- `[System.Collections.Concurrent.ConcurrentStack[object]]`
- `[System.Collections.Concurrent.ConcurrentQueue[object]]`
- `[System.Collections.Concurrent.ConcurrentBag[object]]`

❌ **Unsupported forms (may cause JSON conversion errors):**

- `[System.Collections.Concurrent.ConcurrentDictionary[string, string]]::new(...)`
- `[System.Collections.Concurrent.ConcurrentBag[int]]`
- Any other strongly typed generic versions

To ensure compatibility with `ConvertFrom-PodeState`, `Save-PodeState`, or similar serialization functions, always use `object` as the generic type and apply a case-insensitive comparer where applicable.

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

The [`Save-PodeState`](../../Functions/State/Save-PodeState) function will save the current shared state, as JSON, to a specified file path. The file can be relative or absolute.

This function supports optional filtering by state scope, as well as inclusion or exclusion of specific state keys. It also supports setting the maximum object depth and compressing the output for smaller file sizes.

When saving non-thread-safe objects like `Hashtable`, `OrderedDictionary`, or `PSCustomObject`, it's recommended to wrap the function in [`Lock-PodeObject`](../../Functions/Threading/Lock-PodeObject) for thread safety.

```powershell
Start-PodeServer {
    Add-PodeSchedule -Name 'save-state' -Cron '@hourly' -ScriptBlock {
        Lock-PodeObject -ScriptBlock {
            Save-PodeState -Path './state.json' -Exclude 'SensitiveData' -Compress
        }
    }
}
```

**Parameters:**

- `-Path`: File path to save the state to
- `-Scope`: Only include state items with matching scope(s)
- `-Include`: Include only specified keys (lower precedence than `-Exclude`)
- `-Exclude`: Exclude specific keys (takes precedence over `-Include`)
- `-Depth`: Max object depth for serialization (default: 20)
- `-Compress`: If specified, produces compact/minified JSON output

---

### Restore

The [`Restore-PodeState`](../../Functions/State/Restore-PodeState) function will restore the shared state from a JSON file. The file path can be relative or absolute.

By default, the current state is fully replaced by the restored contents. To merge the loaded state with the existing one instead, use the `-Merge` switch.

If the file does not exist, the function will exit silently without making changes.

```powershell
Start-PodeServer {
    Restore-PodeState -Path './state.json' -Merge
}
```

**Parameters:**

- `-Path`: File path of the saved state JSON
- `-Merge`: If specified, merges with the existing state instead of replacing it

### Export to String

The [`ConvertFrom-PodeState`](../../Functions/State/ConvertFrom-PodeState) function will export the current shared state as a JSON string. This is useful when you want to persist the state outside of a file — such as storing in a database, sending over an API, or caching in memory.

You can filter which keys are included, control serialization depth, and choose between a compact or pretty-printed format.

```powershell
Start-PodeServer {
    Add-PodeSchedule -Name 'dump-state' -Cron '@hourly' -ScriptBlock {
        $json = ConvertFrom-PodeState -Exclude 'Sensitive' -Compress

        # send $json to remote service or log for recovery
    }
}
```

**Parameters:**

- `-Scope`: Only include state items with matching scope(s)
- `-Include`: Include only specific keys
- `-Exclude`: Exclude specific keys (takes precedence over `-Include` and `-Scope`)
- `-Depth`: Max object depth for serialization (default: 20)
- `-Compress`: If specified, outputs compact/minified JSON

---

### Import from String

The [`ConvertTo-PodeState`](../../Functions/State/ConvertTo-PodeState) function will import shared state from a JSON string. This allows restoring state from memory, a database, or API payloads — instead of reading from a file.

By default, it replaces the existing state. To **merge** with the existing state instead, use the `-Merge` switch.

```powershell
Start-PodeServer {
    Add-PodeRoute -Method Post -Path '/state/import' -ScriptBlock {
        $body = Read-PodeJsonBody
        ConvertTo-PodeState -Json $body.Json -Merge
    }
}
```

**Parameters:**

- `-Json`: A valid JSON string containing state data
- `-Merge`: If specified, merges with existing state instead of replacing it

!!! tip
If the JSON string is `$null` or empty, the function will silently do nothing.

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

