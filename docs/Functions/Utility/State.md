# State

## Description

The `state` function allows you to set/get objects on a shared state that exists across all runspaces; this is because functions like `route` and `timer` all run within separate runspaces - meaning normally you can't create a variable in a `timer` and then access that variable in a `route`.

The `state` function overcomes this by letting you create a variable in a `timer` and set it against the shared state, then you can retrieve that variable from the state in a `route`.

!!! tip
    It's wise to use the `state` function in conjunction with the `lock` function, so as to ensure thread safety between runspaces. The `event` object supplied to a `route`, `timer`, `schedule` and `logger` each contain a `.Lockable` resource that can be supplied to the `lock` function.

!!! warning
    If you omit the use of `lock`, you will run into errors due to multi-threading. Only omit if you are *absolutely confident* you do not need locking. (ie: you set in state once and then only ever retrieve, never updating the variable).

## Examples

### Example 1

The following example uses a `timer` to create and update a `hashtable`, and then retrieve that variable in a `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    timer 'forever' 2 {
        param($event)
        $hash = $null

        # create a lock on a pode lockable resource for safety
        lock $event.Lockable {

            # first, attempt to get the hashtable from the state
            $hash = (state get 'hash')

            # if it doesn't exist yet, set it against the state
            if ($hash -eq $null) {
                $hash = (state set 'hash' @{})
                $hash['values'] = @()
            }

            # add a random number to the hash, that will be reflected in the state
            $hash['values'] += (Get-Random -Minimum 0 -Maximum 10)
        }
    }

    route get '/state' {
        param($event)

        # create another lock on the same lockable resource
        lock $event.Lockable {

            # get the hashtable defined in the timer above, and return it as json
            $hash = (state get 'hash')
            Write-PodeJsonResponse -Value $hash
        }
    }

}
```

### Example 2

The following example will restore the state from the file if it exists, and save back to the state every hour:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    # restore state from file
    state restore './state.json'

    # save state to file every hour
    schedule 'save-state' '@hourly' {
        lock $lockable {
            state save './state.json'
        }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Action | string | true | The action to perform on the shared state for the variable (Values: Get, Set, Remove, Save, Restore) | empty |
| Name | string | true | The name of the variable within the shared state | empty |
| Object | object | false | Should only be supplied for an action of `set`. This is the value for the variable in the shared state | null |
