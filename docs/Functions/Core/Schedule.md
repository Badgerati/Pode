# Schedule

## Description

The `schedule` function lets you create long-running async tasks. Unlike a `timer` however, when a schedule is triggered it's logic is run in its own runspace - so they don't affect each other if they take a while to process.

Schedule triggers are defined using [`cron expressions`](../../Tutorials/CronExpressions), basic syntax is supported as well as some predefined expressions. They can start immediately, have a delayed start time, and also have a a defined end time.

## Examples

### Example 1

The following example will create a `schedule` that triggers every Tuesday at midnight:

```powershell
Server {
    schedule 'tuesdays' '0 0 * * TUE' {
        # logic
    }
}
```

### Example 2

The following example will create a `schedule` that triggers every 5 past the hour, starting in 2hrs:

```powershell
Server {
    schedule 'hourly-start' '5 * * * *' -start ([DateTime]::Now.AddHours(2)) {
        # logic
    }
}
```

### Example 3

The following example will create a `schedule` using a predefined cron to trigger every minute:

```powershell
Server {
    schedule 'minutely' '@minutely' {
        # logic
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Name | string | true | A unique name for the schedule | empty |
| Cron | string | true | A cron expression to define when the schedule should trigger | empty |
| ScriptBlock | scriptblock | true | The main logic that will be invoked on each trigger | null |
| StartTime | datetime | false | Defines when the schedule should start | now |
| EndTime | datetime | false | Defines when the schedule should end | never |
