# Start the Pode server
$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
if (Test-Path -Path "$($path)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
}
else {
    Import-Module -Name 'Pode'
}


Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8082 -Protocol Http
    # Define an endpoint to start a task
    Add-PodeRoute -Method Get -Path '/start-task' -ScriptBlock {
        # Define and start a simple task
        $taskId = (New-Guid).ToString()

        Add-PodeTask -name $taskId -ScriptBlock {
            Start-Sleep -Seconds 5  # Simulate task work
            return 'Task completed'
        }

        Invoke-PodeTask -Name $taskId | Out-Null
        Start-Sleep -Seconds 10
        $task2 = Get-PodeTask -Name $taskId
        # Attempt to check if the task is completed
        $isCompleted = Test-PodeTaskCompleted -Task $task2

        # Return the completion status
        Write-PodeJsonResponse -Value @{
            TaskId      = $taskId
            IsCompleted = $isCompleted
        }
    }
}