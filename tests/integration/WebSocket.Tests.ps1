[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

Describe 'WebSocket' {

    BeforeAll {
        $Port = 8080
        $Endpoint = "http://localhost:$($Port)"

        Start-Job -Name 'Pode' -ErrorAction Stop -ScriptBlock {
            Import-Module -Name "$($using:PSScriptRoot)\..\..\src\Pode.psm1"

            Start-PodeServer -RootPath $using:PSScriptRoot -Quiet -ScriptBlock {
                # listen
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Http
                Add-PodeEndpoint -Address localhost -Port $using:Port -Protocol Ws

                New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
                Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
                    Close-PodeServer
                }

                # set view engine to pode renderer
                Set-PodeViewEngine -Type Html

                # GET request for web page
                Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
                    Write-PodeViewResponse -Path 'websockets'
                }

                # SIGNAL route, to return current date
                Add-PodeSignalRoute -Path '/' -ScriptBlock {
                    $msg = $SignalEvent.Data.Message

                    if ($msg -ieq '[date]') {
                        $msg = [datetime]::Now.ToString()
                    }

                    Send-PodeSignal -Value @{ message = $msg }
                }
            }
        }

        Start-Sleep -Seconds 10
    }

    AfterAll {
        Receive-Job -Name 'Pode' | Out-Default
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Get | Out-Null
        Get-Job -Name 'Pode' | Remove-Job -Force
    }


    It 'sends and receives a WebSocket signal with current date' {
        # Create a new WebSocket client
        $client = [System.Net.WebSockets.ClientWebSocket]::new()
        $wsUri = "ws://localhost:$Port/"

        # Connect to the WebSocket endpoint
        $client.ConnectAsync([uri]$wsUri, [Threading.CancellationToken]::None).Wait()
        $client.State | Should -Be 'Open'

        # Prepare a JSON message that the server will interpret to return the current date/time
        $jsonMessage = '{"message": "[date]"}'
        $sendBuffer = [System.Text.Encoding]::UTF8.GetBytes($jsonMessage)
        $sendSegment = [System.ArraySegment[byte]]::new($sendBuffer)

        # Send the JSON message
        $client.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()

        # Wait briefly to allow the response to be processed
        Start-Sleep -Seconds 1

        # Prepare a buffer to receive the response
        $receiveBuffer = [byte[]]::new(1024)
        $receiveSegment = [System.ArraySegment[byte]]::new($receiveBuffer, 0, $receiveBuffer.Length)

        # Receive a message from the server
        $receiveResult = $client.ReceiveAsync($receiveSegment, [Threading.CancellationToken]::None).Result
        $receivedText = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receiveResult.Count)

        # Convert the JSON response to a PowerShell object
        $response = $receivedText | ConvertFrom-Json

        # Cleanly close the WebSocket connection
        $client.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Closing', [Threading.CancellationToken]::None).Wait()

        # Verify that the returned message appears to be a date (for example, by matching a date pattern).
        # Adjust the regex as needed based on your date format.
        $response.message | Should -Match '\d{1,2}\/\d{1,2}\/\d{4}'
    }

    It 'handles sending and receiving Max default size (32KB)' {
        $client = [System.Net.WebSockets.ClientWebSocket]::new()
        $wsUri = "ws://localhost:$Port/"

        $client.ConnectAsync([uri]$wsUri, [Threading.CancellationToken]::None).Wait()
        $client.State | Should -Be 'Open'

        # Generate a large message (~3MB)
        $largeMessage = ('a' * ((32KB) - 16))
        $jsonMessage = ('{"message": "' + $largeMessage + '"}')
        $sendBuffer = [System.Text.Encoding]::UTF8.GetBytes($jsonMessage)
        $sendSegment = [System.ArraySegment[byte]]::new($sendBuffer)

        $client.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()

        Start-Sleep -Seconds 2

        $receiveBuffer = [byte[]]::new(4MB)
        $receiveSegment = [System.ArraySegment[byte]]::new($receiveBuffer, 0, $receiveBuffer.Length)

        $receiveResult = $client.ReceiveAsync($receiveSegment, [Threading.CancellationToken]::None).Result
        $receivedText = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receiveResult.Count)

        $response = $receivedText | ConvertFrom-Json

        $client.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Closing', [Threading.CancellationToken]::None).Wait()

        $response.message.Length | Should -Be $largeMessage.Length
        $response.message | Should -BeExactly $largeMessage
    }

    <# This test fails because the default max message size is 32KB.
   It 'handles sending and receiving large messages (>3MB)' {
        $client = [System.Net.WebSockets.ClientWebSocket]::new()
        $wsUri = "ws://localhost:$Port/"

        $client.ConnectAsync([uri]$wsUri, [Threading.CancellationToken]::None).Wait()
        $client.State | Should -Be 'Open'

        # Generate a large message (~3MB)
        $largeMessage = ('a' * ((3MB)-16))
        $jsonMessage = ('{"message": "' + $largeMessage + '"}')
        $sendBuffer = [System.Text.Encoding]::UTF8.GetBytes($jsonMessage)
        $sendSegment = [System.ArraySegment[byte]]::new($sendBuffer)

        $client.SendAsync($sendSegment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).Wait()

        Start-Sleep -Seconds 2

        $receiveBuffer = [byte[]]::new(4MB)
        $receiveSegment = [System.ArraySegment[byte]]::new($receiveBuffer, 0, $receiveBuffer.Length)

        $receiveResult = $client.ReceiveAsync($receiveSegment, [Threading.CancellationToken]::None).Result
        $receivedText = [System.Text.Encoding]::UTF8.GetString($receiveBuffer, 0, $receiveResult.Count)

        $response = $receivedText | ConvertFrom-Json

        $client.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, 'Closing', [Threading.CancellationToken]::None).Wait()

        $response.message.Length | Should -Be $largeMessage.Length
        $response.message | Should -BeExactly $largeMessage
    }
        #>
}