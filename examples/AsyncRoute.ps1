<#
.SYNOPSIS
    A script to either run a Pode server with various endpoints or to send multiple REST requests to the server.

.DESCRIPTION
    This script sets up a Pode server with multiple endpoints demonstrating asynchronous operations and authorization.
    It also includes examples of how to send REST requests to the server.

.PARAMETER Port
    The port on which the Pode server will listen. Default is 8080.

.PARAMETER Quiet
    Suppresses output when the server is running.

.PARAMETER DisableTermination
    Prevents the server from being terminated.

.EXAMPLE
    .\AsyncRoute.ps1 -Port 9090 -Quiet -DisableTermination

.EXAMPLE
    # Example of using the endpoints with Invoke-RestMethod
    $mortyCommonHeaders = @{
        'accept'        = 'application/json'
        'X-API-KEY'     = 'test-api-key'
        'Authorization' = 'Basic bW9ydHk6cGlja2xl'
    }

    $mindyCommonHeaders = @{
        'accept'        = 'application/json'
        'X-API-KEY'     = 'test2-api-key'
        'Authorization' = 'Basic bWluZHk6cGlja2xl'
    }

    $response_asyncUsingNotCancellable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancellable' -Method Put -Headers $mortyCommonHeaders
    $response_asyncUsingCancellable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingCancellable' -Method Put -Headers $mortyCommonHeaders

    $body = @{
        callbackUrl = 'http://localhost:8080/receive/callback'
    } | ConvertTo-Json

    $headersWithContentType = $mortyCommonHeaders.Clone()
    $headersWithContentType['Content-Type'] = 'application/json'

    $response_asyncUsing = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

    $response_asyncState = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $mortyCommonHeaders

    $response_asyncParam = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $mortyCommonHeaders

    $response_asyncWaitForeverTimeout = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncInfiniteLoopTimeout' -Method Put -Headers $mortyCommonHeaders

    $response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body '{}' -Headers $mortyCommonHeaders



$response_Mindy_asyncWaitForever = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncInfiniteLoop' -Method Put -Headers $mindyCommonHeaders

    $response_Mindy_asyncUsingNotCancellable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancellable' -Method Put -Headers $mindyCommonHeaders
    $response_Mindy_asyncUsingCancellable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingCancellable' -Method Put -Headers $mindyCommonHeaders
    $response_Mindy_asyncStateNoColumn = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncStateNoColumn' -Method Put -Headers $mindyCommonHeaders

    $headersWithContentType = $mindyCommonHeaders.Clone()
    $headersWithContentType['Content-Type'] = 'application/json'
    $response_Mindy_asyncUsing = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

    $response_Mindy_asyncState = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $mindyCommonHeaders

    $response_Mindy_asyncParam = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $mindyCommonHeaders

    $response_Mindy_asyncWaitForeverTimeout = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncInfiniteLoopTimeout' -Method Put -Headers $mindyCommonHeaders

$response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body '{}' -Headers $mindyCommonHeaders

$response_Mindy_asyncWaitForever = Invoke-RestMethod -Uri "http://localhost:8080/task?Id=$($response_Mindy_asyncWaitForever.Id)" -Method Delete -Headers $mindyCommonHeaders

.NOTES
    Author: Pode Team
    License: MIT License
#>
param(
    [Parameter()]
    [int]
    $Port = 8080,
    [switch]
    $Quiet,
    [switch]
    $DisableTermination
)

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

<#
# Demostrates Lockables, Mutexes, and Semaphores
#>

Start-PodeServer -Threads 1 -Quiet:$Quiet -DisableTermination:$DisableTermination {

    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http -DualMode
    New-PodeLoggingMethod -name 'async' -File  -Path "$ScriptPath/logs" | Enable-PodeErrorLogging

    # request logging
    # New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging


    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'    -EnableSchemaValidation:$($PSVersionTable.PSVersion -ge [version]'6.1.0') -DisableMinimalDefinitions -NoDefaultResponses
    Enable-PodeOpenApi -Path '/docs/openapi/v3.1' -OpenApiVersion '3.1.0' -EnableSchemaValidation:$($PSVersionTable.PSVersion -ge [version]'6.1.0') -DefinitionTag 'v3.1' -DisableMinimalDefinitions -NoDefaultResponses

    Add-PodeOAInfo -Title 'Async test - OpenAPI 3.0' -Version 0.0.2
    Add-PodeOAInfo -Title 'Async test - OpenAPI 3.1' -Version 0.0.2 -DefinitionTag 'v3.1'

    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'
    Enable-PodeOAViewer -Type Swagger -Path '/docs3.1/swagger' -DefinitionTag 'v3.1'

    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'
    Enable-PodeOAViewer -Bookmarks -Path '/docs3.1' -DefinitionTag 'v3.1'
    $uSleepTime = 4
    $uMessage = 'coming from using'

    #  $global:gMessage = 'coming from global'
    #   $global:gSleepTime = 3
    Set-PodeState -Name 'data' -Value @{
        sleepTime = 5
        Message   = 'coming from a PodeState'
    }


    # setup access
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'Rbac'
    New-PodeAccessScheme -Type Group | Add-PodeAccess -Name 'Gbac'

    # setup a merged access
    Merge-PodeAccess -Name 'MergedAccess' -Access 'Rbac', 'Gbac' -Valid All

    $testApiKeyUsers = @{
        'M0R7Y302' = @{
            Id     = 'M0R7Y302'
            Name   = 'Morty'
            Type   = 'Human'
            Roles  = @('Manager')
            Groups = @('Software')
        }
        'MINDY021' = @{
            Id     = 'MINDY021'
            Name   = 'Mindy'
            Type   = 'AI'
            Roles  = @('Developer')
            Groups = @('Support')
        }
    }


    $testBasicUsers = @{
        'M0R7Y302' = @{
            Id     = 'M0R7Y302'
            Name   = 'Morty'
            Type   = 'Human'
            Roles  = @('Developer')
            Groups = @('Platform')
        }
        'MINDY021' = @{
            Id     = 'MINDY021'
            Name   = 'Mindy'
            Type   = 'AI'
            Roles  = @('Developer')
            Groups = @('Software')
        }
    }



    # setup apikey auth
    New-PodeAuthScheme -ApiKey -Location Header | Add-PodeAuth -Name 'ApiKey' -Sessionless -ScriptBlock {
        param($key)

        # here you'd check a real user storage, this is just for example
        if ($key -ieq 'test-api-key') {
            return @{
                User = ($using:testApiKeyUsers).M0R7Y302
            }
        }
        if ($key -ieq 'test2-api-key') {
            return @{
                User = ($using:testApiKeyUsers).MINDY021
            }
        }

        return $null
    }

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Basic' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = ($using:testBasicUsers).M0R7Y302
            }
        }

        if ($username -eq 'mindy' -and $password -eq 'pickle') {
            return @{
                User = ($using:testBasicUsers).MINDY021
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    # merge the auths together
    Merge-PodeAuth -Name 'MergedAuth' -Authentication 'ApiKey', 'Basic' -Valid All -ScriptBlock {
        param($results)

        $apiUser = $results['ApiKey'].User
        $basicUser = $results['Basic'].User

        return @{
            User = @{
                Id     = $apiUser.Id
                Name   = $apiUser.Name
                Type   = $apiUser.Type
                Roles  = @($apiUser.Roles + $basicUser.Roles) | Sort-Object -Unique
                Groups = @($apiUser.Groups + $basicUser.Groups) | Sort-Object -Unique
            }
        }
    }

    Add-PodeRoute  -Method 'Post' -Path '/close' -ScriptBlock {
        Close-PodeServer
    } -PassThru | Set-PodeOARouteInfo -Summary 'Shutdown the server' -PassThru | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'

    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsing' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'   -ScriptBlock {
        Write-PodeHost '/auth/asyncUsing'
        Write-PodeHost "sleepTime=$($using:uSleepTime)"
        Write-PodeHost "Message=$($using:uMessage)"
        Start-Sleep $using:uSleepTime
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeOARouteInfo -Summary 'Async with callback with Using variable' -OperationId 'asyncUsingCallback' -DefinitionTag 'Default', 'v3.1'  -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'  -Timeout 300 -PassThru |
        Add-PodeAsyncRouteCallback -PassThru -CallbackSendResult | Set-PodeOARequest  -RequestBody (
            New-PodeOARequestBody -Content @{'application/json' = (New-PodeOAStringProperty -Name 'callbackUrl' -Format Uri -Object -Example 'http://localhost:8080/receive/callback') }
        )


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncState' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        Write-PodeHost '/auth/asyncState'
        Write-PodeHost "state:sleepTime=$($state:data.sleepTime)"
        Write-PodeHost "state:MessageTest=$($state:data.Message)"
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep $state:data.sleepTime
        }
        return @{ InnerValue = $state:data.Message }
    } | Set-PodeOARouteInfo -Summary 'Async with State variable' -OperationId 'asyncState' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300



    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncStateNoColumn'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Support' -ScriptBlock {
        Write-PodeHost '/auth/asyncStateNoColumn'
        $data = Get-PodeState -Name 'data'
        Write-PodeHost 'data:'
        Write-PodeHost $data -Explode -ShowType
        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep $data.sleepTime
        }
        return @{ InnerValue = $data.Message }
    } | Set-PodeOARouteInfo -Summary 'Async with State variable NoColumn' -OperationId 'asyncStateNoColumn' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300




    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncParam'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        param($sleepTime2, $Message)
        Write-PodeHost '/auth/asyncParam'
        Write-PodeHost "sleepTime2=$sleepTime2"
        Write-PodeHost "Message=$Message"

        for ($i = 0; $i -lt 10; $i++) {
            Start-Sleep $sleepTime2
        }
        return @{ InnerValue = $Message }
    } -ArgumentList @{sleepTime2 = 2; Message = 'comming as argument' } |
        Set-PodeOARouteInfo -Summary 'Async with Parameters' -OperationId 'asyncParameters' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsingNotCancellable' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        Write-PodeHost '/auth/asyncUsingNotCancellable'
        Write-PodeHost "sleepTime=$($using:uSleepTime * 5)"
        Write-PodeHost "Message=$($using:uMessage)"
        #write-podehost $WebEvent.auth.User -Explode
        Start-Sleep ($using:uSleepTime * 10)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeOARouteInfo -Summary 'Async with Using variable Not Cancellable' -OperationId 'asyncUsingNotCancellable' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -NotCancellable -Timeout 300

    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncUsingCancellable' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -ScriptBlock {
        Write-PodeHost '/auth/asyncUsingCancellable'
        Write-PodeHost "sleepTime=$($using:uSleepTime * 5)"
        Write-PodeHost "Message=$($using:uMessage)"
        #write-podehost $WebEvent.auth.User -Explode
        Start-Sleep ($using:uSleepTime * 10)
        return @{ InnerValue = $using:uMessage }
    } | Set-PodeOARouteInfo -Summary 'Async with Using variable Cancellable' -OperationId 'asyncUsingCancellable' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncInfiniteLoop' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        while ($true) {
            Start-Sleep 2
        }
    } | Set-PodeOARouteInfo -Summary 'Async infinite loop' -OperationId 'asyncInfiniteLoop' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300



    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncInfiniteLoopTimeout' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        while ($true) {
            Start-Sleep 2
        }
    } | Set-PodeOARouteInfo -Summary 'Async infinite loop with Timeout' -OperationId 'asyncInfiniteLoopTimeout' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 40 -NotCancellable


    Add-PodeRoute -PassThru -Method Put -Path '/auth/asyncProgressByTimer' -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -ScriptBlock {
        Set-PodeAsyncRouteProgress -DurationSeconds 30 -IntervalSeconds 1
        for ($i = 0 ; $i -lt 30 ; $i++) {
            Start-Sleep 1
        }
    } | Set-PodeOARouteInfo -Summary 'Async with Progress By Timer' -OperationId 'asyncProgressByTimer' -PassThru |
        Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -Timeout 300 -MaxRunspaces 10

    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquareRoot' -ScriptBlock {
        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "Start=$start End=$end"
        Set-PodeAsyncRouteProgress -Start $start -End $End -UseDecimalProgress -MaxProgress 80
        [double]$sum = 0.0
        for ($i = $Start; $i -le $End; $i++) {
            $sum += [math]::Sqrt($i )
            Set-PodeAsyncRouteProgress -Tick
        }
        Write-PodeHost  (Get-PodeAsyncRouteProgress)
        Set-PodeAsyncRouteProgress -Start $start -End $End -Steps 4
        for ($i = $Start; $i -le $End; $i += 4) {
            $sum += [math]::Sqrt($i )
            Set-PodeAsyncRouteProgress -Tick
        }

        Write-PodeHost  (Get-PodeAsyncRouteProgress)
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 10 -MinRunspaces 5 -PassThru | Set-PodeOARouteInfo -Summary 'Calculate sum of square roots'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
      (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
         (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }


    Add-PodeAsyncRouteGet -Path '/task' -ResponseContentType  'application/json', 'application/yaml'  -In Path -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -PassThru | Set-PodeOARouteInfo -Summary 'Get Async Route Task Info'

    Add-PodeAsyncRouteStop -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Query -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software' -OADefinitionTag 'Default', 'v3.1' -PassThru | Set-PodeOARouteInfo -Summary 'Stop Async Route Task'

    Add-PodeAsyncRouteQuery -path '/tasks'  -ResponseContentType 'application/json', 'application/yaml'   -Payload  Body -QueryContentType 'application/json', 'application/yaml'  -Authentication 'MergedAuth' -Access 'MergedAccess' -Group 'Software'  -PassThru | Set-PodeOARouteInfo -Summary 'Query Async Route Task Info'

    Add-PodeRoute -PassThru -Method Post -path '/receive/callback' -ScriptBlock {
        write-podehost 'Callback received'
        write-podehost $WebEvent.Data -Explode
    }


    Add-PodeRoute  -Method 'Get' -Path '/hello' -ScriptBlock {
        Write-PodeJsonResponse -Value @{'message' = 'Hello!' } -StatusCode 200
    } -PassThru | Set-PodeOARouteInfo -Summary 'Hello from the server' -PassThru | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation'


    Add-PodeRoute  -PassThru -Method Get -Path '/events' -ScriptBlock {
        # ConvertTo-PodeSseConnection -Name 'Events' -Scope Local -Group 'Test events'
        $msg = "Start - Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
        write-podehost $msg
        Send-PodeSseEvent   -Data $msg -FromEvent #-name 'Events' -Group 'Test events' #-FromEvent
        write-podehost 'PodeSseEvent sent'
        Start-Sleep -Seconds 10
        $msg = "End -Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
        write-podehost $msg
        Send-PodeSseEvent   -Data $msg  -FromEvent #-name 'Events' -Group 'Test events' #-FromEvent
        write-podehost 'PodeSseEvent sent'
        return @{'message' = 'Done' }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json'  -MaxRunspaces 2  -PassThru -EnableSse -SseGroup 'Test events' |
        Add-PodeAsyncRouteSse -SseGroup 'Test events'

    Add-PodeRoute -method Get -Path '/html/events' -ScriptBlock {
        Write-PodeHtmlResponse -StatusCode 200 -Value  @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EventSource Example</title>
</head>
<body>
    <h1>EventSource Demo</h1>
    <p>Listening for events...</p>
    <div id="output"></div> <!-- A div to display the event data -->

    <script>
        // Fetch the EventSource URL
        fetch('http://localhost:8080/events')
            .then(response => response.json())
            .then(data => {
                // Log the full data received from the RESTful call
                console.log('Received RESTful data:', data);

                // Retrieve the Name from the Sse hashtable
                const eventSourceName = data.Sse.Url;
                const eventSourceUrl = `${eventSourceName}`;

                // Log the constructed EventSource URL
                console.log('Constructed EventSource URL:', eventSourceUrl);

                // Initialize EventSource with the retrieved name
                const sse = new EventSource(eventSourceUrl);
                const outputDiv = document.getElementById('output');

                sse.addEventListener('pode.open', (e) => {
                    var data = JSON.parse(e.data);
                    let clientId = data.clientId;
                    let group = data.group;
                    let name = data.name;
                    let asyncRouteTaskId = data.asyncRouteTaskId;

                    // Display the data on the webpage
                    outputDiv.innerHTML += `
                        <p><strong>pode.open Event:</strong></p>
                        <p>Client ID: ${clientId}</p>
                        <p>Group: ${group}</p>
                        <p>Name: ${name}</p>
                        <p>AsyncRouteTaskId: ${asyncRouteTaskId}</p>
                        <hr>
                    `;

                    console.log(`Client ID: ${clientId}`);
                    console.log(`Group: ${group}`);
                    console.log(`Name: ${name}`);
                    console.log(`AsyncRouteTaskId: ${asyncRouteTaskId}`);
                });

                sse.addEventListener('pode.close', (e) => {
                    console.log('Closing SSE connection.');
                    outputDiv.innerHTML += `
                        <p><strong>pode.close Event:</strong></p>
                        <p>Connection is closing.</p>
                        <hr>
                    `;
                    sse.close();
                });
                sse.addEventListener('message', (e) => {
                    var data = JSON.parse(e.data);
                    let updateInfo = data.updateInfo;

                    // Handle the update event
                    outputDiv.innerHTML += `
                        <p><strong>message Event:</strong></p>
                        <p>Update Info: ${updateInfo}</p>
                        <hr>
                    `;

                    console.log(`Update Info: ${updateInfo}`);
                });
                sse.addEventListener('events', (e) => {
                    var data = JSON.parse(e.data);
                    let updateInfo = data.updateInfo;

                    // Handle the update event
                    outputDiv.innerHTML += `
                        <p><strong>pode.update Event:</strong></p>
                        <p>Update Info: ${updateInfo}</p>
                        <hr>
                    `;

                    console.log(`Update Info: ${updateInfo}`);
                });

                sse.onmessage = function(event) {
                    console.log("Received an event:", event);
                    outputDiv.innerHTML += `
                        <p><strong>General Message Event:</strong></p>
                        <p>Data: ${event.data}</p>
                        <hr>
                    `;
                };



                sse.addEventListener('pode.error', (e) => {
                    var data = JSON.parse(e.data);
                    let errorMessage = data.errorMessage;

                    // Handle the error event
                    outputDiv.innerHTML += `
                        <p><strong>pode.error Event:</strong></p>
                        <p>Error Message: ${errorMessage}</p>
                        <hr>
                    `;

                    console.error(`Error Message: ${errorMessage}`);
                });
            })
            .catch(error => {
                console.error('Error fetching the EventSource name:', error);
            });
    </script>
</body>
</html>

'@
    }
}