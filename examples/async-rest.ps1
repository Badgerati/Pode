$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
if (Test-Path -Path "$($path)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop
}
else {
    Import-Module -Name 'Pode'
}

# or just:
# Import-Module Pode

# create a basic server
Start-PodeServer -EnablePool Tasks {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3' -DisableMinimalDefinitions -NoDefaultResponses
    Add-PodeOAInfo -Title 'Async test' -Version 1.0.0
    Add-PodeOAServerEndpoint -url '/api' -Description 'default endpoint'


    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc' -DarkMode
    Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc' -DarkMode
    Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight' -DarkMode
    Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer' -DarkMode
    Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf' -DarkMode

    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'


    Add-PodeRoute -Method Post -Path '/api/task' -ScriptBlock {
        $sleepTime = $WebEvent.Query['sleepTime']

        $name = (New-Guid).ToString()
        $startTime = Get-Date
        Add-PodeTask -Name $name -ScriptBlock {
            param($sleepTime)
            Write-PodeHost "Start $sleepTime"
            for ($progress = 0; $progress -le 100; $progress++) {
                Start-Sleep -Milliseconds $sleepTime
                Write-PodeHost -NoNewLine '.'
            }
            Write-PodeHost
            Write-PodeHost 'End'
        } -ArgumentList @{sleepTime = $sleepTime } | Out-Null
        $task = Invoke-PodeTask -Name $name
        #   $task = Get-PodeTask -Name $name
        Write-PodeHost $task -Explode -ShowType
        Write-PodeJsonResponse -Value @{
            StartTime = $startTime
            taskId    = $name
            Done      = Test-PodeTaskCompleted -Task $task
        }
    } -PassThru | Set-PodeOARouteInfo -Summary 'Create Task' -Tags 'task' -OperationId 'newTask' -PassThru |
        Set-PodeOARequest -Parameters  (  New-PodeOAIntProperty -Name 'sleepTime' | ConvertTo-PodeOAParameter -In Query -Required ) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'

    Add-PodeRoute -Method Get -Path '/api/task/:taskId' -ScriptBlock {
        $taskId = $WebEvent.Parameters['taskId']
        $task = Get-PodeTask -Name $taskId
        write-podehost -Object $task -Explode -ShowType
        $done = Test-PodeTaskCompleted -Task $task
        if ($done) {
            Write-PodeJsonResponse -Value @{
                # StartTime = $startTime
                taskId = $taskId
                Done   = $true
                Result = $task.Result
            }
        }
        else {
            Write-PodeJsonResponse -Value @{
                taskId = $taskId
                Done   = $false
            }

        }
    }    -PassThru | Set-PodeOARouteInfo -Summary 'Check Task' -Tags 'task' -OperationId 'getTask' -PassThru |
        Set-PodeOARequest -Parameters  (  New-PodeOAStringProperty -Name 'taskId' -Format Uuid | ConvertTo-PodeOAParameter -In Path -Required) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' #-Content @{'application/json' = 'ApiResponse' }

}
