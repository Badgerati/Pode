# Timer

## Description

The `timer` function allows you to setup short-running async tasks, that run periodically along side your main server logic; they have unique names, and iterate on a defined number of seconds.

!!! info
    All timers are created and run within the same runspace, one after another when their trigger time occurs. You should ensure that a timer's defined logic is not long-running (things like heavy database tasks or reporting), as this will delay other timers from being run. For timers that might take a much longer time to run, try using [`schedule`](/Functions/Schedule) instead

## Examples

### Example 1

The following example is a `timer` that runs for ever, every 5secs:

```powershell
Server {
    timer 'forever' 5 {
        # logic
    }
}
```

### Example 2

The following example is a `timer` that will skip the first 3 iterations, and after 15secs (3x5) will loop every 5secs:

```powershell
Server {
    timer 'skip-first-3' 5 -skip 3 {
        # logic
    }
}
```

### Example 3

The following example is a `timer` that runs once after waiting for 2mins:

```powershell
Server {
    timer 'run-once' 120 -skip 1 -limit 1 {
        # logic
    }
}
```

### Example 4

The following example will create a new `timer` every time the `route` is called - the route expects two query string parameters of `Name` an `Seconds`:

```powershell
Server {
    route 'get' '/api/timer' {
        param($session)
        $query = $session.Query

        timer $query['Name'] $query['Seconds'] {
            # logic
        }
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Name | string | true | The unique name of the timer | empty |
| Interval | int | true | The number of seconds between each iteration | 0 |
| ScriptBlock | scriptblock | true | The main logic that will be invoked on each timer iteration | null |
| Limit | int | false | The number of iterations that should be invoked before the timer is removed | 0 |
| Skip | int | false | The number of iterations to skip before invoking timer logic | 0 |
