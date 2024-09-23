<#
.SYNOPSIS
    A script that either runs a Pode server with asynchronous SSE endpoints or sends multiple REST requests to the server.

.DESCRIPTION
    This script demonstrates how to set up a Pode server with endpoints that include asynchronous operations and
    Server-Sent Events (SSE). It provides examples of handling asynchronous requests and sending REST calls to
    interact with the server's SSE-based routes.

.EXAMPLE
    .\Web-AsyncRouteSse.ps1

    Starts the Pode server with asynchronous routes and SSE events enabled.

.EXAMPLE
    Open a web browser that supports the SSE protocol (e.g., Google Chrome) and navigate to
    http://localhost:8081/test/sse to see the SSE demo in action.

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Web-AsyncRouteSse.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

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


Start-PodeServer -Threads 1 {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -DualMode
    New-PodeLoggingMethod -name 'asyncSse' -File  -Path "$ScriptPath/logs" | Enable-PodeErrorLogging

    Add-PodeRoute  -PassThru -Method Get -Path '/sse' -ScriptBlock {

        $msg = "Start - Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"
        Send-PodeSseEvent   -Data $msg -FromEvent

        Start-Sleep -Seconds 10
        $msg = "End -Hello there! The datetime is: $([datetime]::Now.TimeOfDay)"

        Send-PodeSseEvent   -Data $msg  -FromEvent

        Start-Sleep -Seconds 2
        return @{'message' = 'Done' }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json'  -MaxRunspaces 2  -PassThru |
        Add-PodeAsyncRouteSse -SseGroup 'Test events'

    Add-PodeRoute -method Get -Path '/test/sse' -ScriptBlock {
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
        fetch('http://localhost:8081/sse')
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
                    let state = data.State;
                    let result= data.Result;

                    // Handle the update event
                    outputDiv.innerHTML += `
                        <p><strong>message Event:</strong></p>
                        <p>State Info: ${state}</p>
                        <p>Result    : ${result}</p>
                        <hr>
                    `;

                    console.log(`State Info: ${state}`);
                    console.log(`Result    : ${result}`);
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