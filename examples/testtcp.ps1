try {
    # Create a TCP client for non-secure communication
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    Write-Output 'Attempting to connect to 127.0.0.1 on port 514...'
    $tcpClient.Connect('127.0.0.1', 514)
    $networkStream = $tcpClient.GetStream()

    Write-Output 'TCP connection established to 127.0.0.1 on port 514'

    # Test message
    $testMessage = '<13>Test message from PowerShell`n'
    $byteMessage = [Text.Encoding]::ASCII.GetBytes($testMessage)

    # Send the message
    $networkStream.Write($byteMessage, 0, $byteMessage.Length)
    $networkStream.Flush()

    Write-Output 'Test message sent to 127.0.0.1 on port 514'

    # Close the TCP client
    $networkStream.Close()
    $tcpClient.Close()
}
catch {
    Write-Output "Failed to send TCP message: $_.Exception.Message"
}
