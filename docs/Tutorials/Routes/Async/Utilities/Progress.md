
## Progress

The Progress functions in Pode allow you to manage and retrieve the progress of asynchronous tasks within your routes. These functions provide real-time feedback on the status of your tasks, making it easier to track and monitor long-running operations.

**Note**: These functions can only be used inside an AsyncRoute scriptblock. Using them outside of that context will generate an exception.

### Set-PodeAsyncRouteProgress

The `Set-PodeAsyncRouteProgress` function manages the progress of an asynchronous task within Pode routes. It allows you to update the progress of a running asynchronous task in various ways, providing real-time feedback on the task's status.

#### Key Features

- **Start and End Progress with Ticks**: Define a starting and ending progress value, with optional steps to increment progress. Use ticks to advance the progress in this scenario.
- **Time-based Progress**: Automatically increment progress over a specified duration with interval-based ticks.
- **Set Specific Progress Value**: Directly set the progress to a specific value.
- **SSE Integration**: If `Server-Sent Events (Sse)` is configured for the route, a 'pode.progress' event is automatically sent to the web client, providing real-time updates on the task's progress.


#### Example Usage



##### Start and End Progress with Ticks

```powershell
Add-PodeRoute -PassThru -Method Post -Path '/process-data' -ScriptBlock {
    $data = Get-PodeBody
    Set-PodeAsyncRouteProgress -Start 0 -End 100 -Steps 5

    # Simulate long-running task
    for ($i = 0; $i -le 100; $i += 5) {
        Set-PodeAsyncRouteProgress -Tick
        Start-Sleep 1
    }

    return @{ message = "Processing completed" }
} | Set-PodeAsyncRoute
```

In this example:
- An async route processes data and sends progress updates using `Set-PodeAsyncRouteProgress`.

##### Multiple Start and End Progress with Ticks

```powershell
Add-PodeRoute -PassThru -Method Get -Path '/SumOfSquareRoot' -ScriptBlock {
    $start = [int](Get-PodeHeader -Name 'Start')
    $end = [int](Get-PodeHeader -Name 'End')
    Write-PodeHost "Start=$start End=$end"
    Set-PodeAsyncRouteProgress -Start $start -End $end -UseDecimalProgress -MaxProgress 80
    [double]$sum = 0.0
    for ($i = $start; $i -le $end; $i++) {
        $sum += [math]::Sqrt($i)
        Set-PodeAsyncRouteProgress -Tick
    }
    Write-PodeHost (Get-PodeAsyncRouteProgress)
    Set-PodeAsyncRouteProgress -Start $start -End $end -Steps 4
    for ($i = $start; $i -le $end; $i += 4) {
        $sum += [math]::Sqrt($i)
        Set-PodeAsyncRouteProgress -Tick
    }
    Write-PodeHost (Get-PodeAsyncRouteProgress)
    Write-PodeHost "Result of Start=$start End=$end is $sum"
    return $sum
} | Set-PodeAsyncRoute
```

In this example:
- The first progress runs from 0 to 80 with a default step of 1, representing progress as a decimal number.
- The second progress runs from 80 to 100 with a step of 4, also representing progress as a decimal number.



##### Time-based Progress

```powershell
Add-PodeRoute -PassThru -Method Put -Path 'asyncProgressByTimer' -ScriptBlock {
    Set-PodeAsyncRouteProgress -DurationSeconds 30 -IntervalSeconds 1
    for ($i = 0 ; $i -lt 30 ; $i++) {
        Start-Sleep 1
    }
} | Set-PodeAsyncRoute
```

In this example:
- The progress is automatically incremented over a duration of 30 seconds, with updates every second.

##### Set Specific Progress Value

```powershell
Set-PodeAsyncRouteProgress -Value 75
```

#### Parameters

- **Start**: The starting progress value.
- **End**: The ending progress value.
- **Steps**: The increments between the start and end values.
- **Tick**: Advance progress in a Start-End scenario.
- **DurationSeconds**: The total duration over which progress should be updated.
- **IntervalSeconds**: The interval at which progress should be incremented.
- **MaxProgress**: The maximum progress value.
- **UseDecimalProgress**: Use decimal values for progress.
- **Value**: Directly set the progress to a specific value.

---

### Get-PodeAsyncRouteProgress

The `Get-PodeAsyncRouteProgress` function retrieves the current progress of an asynchronous route in Pode. It allows you to check the progress of a running asynchronous task.

**Note**: This function can only be used inside an AsyncRoute scriptblock. Using it outside of that context will generate an exception.

#### Example Usage

```powershell
Add-PodeRoute -PassThru -Method Get '/process' {
    # Perform some work and update progress
    Set-PodeAsyncRouteProgress -Value 40
    # Retrieve the current progress
    $progress = Get-PodeAsyncRouteProgress
    Write-PodeHost "Current Progress: $progress"
} | Set-PodeAsyncRoute -ResponseContentType 'application/json'
```