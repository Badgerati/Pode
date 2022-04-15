# TCP

Pode has a generic TCP server type inbuilt. Unlike the other server types, the TCP server lets you build pretty much anything over TCP. The TCP server supports non-TLS, as well as implicit and explicit TLS endpoints.

Where a web server using Routes, a TCP server uses Verbs - think of them like "commands" or "phrases". Requests sent will be matched to a Verb, and that Verb's logic invoked (more info below).

## Usage

To create a TCP server you need to create an appropriate [Endpoint](../../Tutorials/Endpoints/Basics) with the TCP protocol, plus some [Verbs](#verbs).

The following example will create a TCP endpoint listening on `localhost:9000`, and creates a simple Verb to respond back to a connected client:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Tcp -CRLFMessageEnd

    Add-PodeVerb -Verb 'HELLO' -ScriptBlock {
        Write-PodeTcpClient -Message 'HI'
    }
}
```

!!! note
    If you use telnet to test/send data to a TCP server, ensure that the Endpoint has the `-CRLFMessageEnd` switch. If missed, the server will receive data in single characters.

Start the above server, and then in a different terminal start telnet and send "HELLO" - pressing Enter to send:

```powershell
$> telnet localhost 9000
C> HELLO
S> HI
```

When you send "HELLO", the server will respond with "HI". If you can't use telnet, then there's a quick [test script](#test-send) below to use.

### Acknowledge

If you'd like to send an initial message to clients as soon as they connect, you can set an `-Acknowledge` message on the Endpoint:

```powershell
Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Tcp -CRLFMessageEnd -Acknowledge 'Welcome!'
```

If you connect via telnet now:

```powershell
$> telnet localhost 9000
S> Welcome!
```

## Verbs

Verbs work like Routes, whereby you can setup many of them and Pode will invoke the Verb's logic that best matches the data sent. Data sent usually should be in a structured format, such as `<COMMAND> <PARAMETERS>` - akin to SMTP and FTP. However, data can be unstructured, and this is where the wildcard Verb comes in handy.

To create a Verb you use [`Add-PodeVerb`](../../Functions/Verbs/Add-PodeVerb):

```powershell
Add-PodeVerb -Verb 'HELLO' -ScriptBlock {
    Write-PodeTcpClient -Message 'HI'
}
```

### Parameters

Also similar to Routes, Verbs support parameters in the format `:<name>`. These parameters will be available in `$TcpEvent.Parameters`:

```powershell
Add-PodeVerb -Verb 'HELLO :username' -ScriptBlock {
    Write-PodeTcpClient -Message "HI, $($TcpEvent.Parameters.username)"
}
```

### Wildcard

The wildcard Verb, denoted via `-Verb *`, is a catch-all for any data that doesn't match other defined Verbs. You could use this Verb to write back to the client that they sent invalid data:

```powershell
Add-PodeVerb -Verb * -ScriptBlock {
    Write-PodeTcpClient -Message 'Unrecognised verb sent'
}
```

Or, you can access the data sent by the client via either `$TcpEvent.Request.RawBody` or `$TcpEvent.Request.Body`. RawBody is a byte array of the data, where as Body is a UTF8 decoded string of the RawBody. This should allow you to then parse any freestyle data as you see fit, such as a simple web server:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address localhost -Port 9000 -Protocol Tcp

    Add-PodeVerb -Verb * -Close -ScriptBlock {
        $TcpEvent.Request.Body | Out-Default
        Write-PodeTcpClient -Message "HTTP/1.1 200 `r`nConnection: close`r`n`r`n<b>Hello, there</b>"
    }
}
```

Running the above server and navigating to http://localhost:9000 will greet you with a message. The raw data sent by the browser will be display on the terminal; this could be parsed to do different things.

### SSL Upgrade

If you're using explicit TLS on your TCP server, then at some point you'll want to upgrade the connection to using SSL.
There are two ways of achieving this; one is to use a simple command verb, and the `-UpgradeToSsl` switch:

```powershell
Add-PodeVerb -Verb 'STARTTLS' -UpgradeToSsl
```

The second way is to call the upgrade method directly:

```powershell
Add-PodeVerb -Verb 'STARTTLS' -ScriptBlock {
    Write-PodeTcpClient -Message 'TLS GO AHEAD'
    $TcpEvent.Request.UpgradeToSSL()
}
```

### Close

At some point you'll likely need to close the connection from the server side. There are two ways of achieving this; one is to use a simple command verb, and the `-Close` switch:

```powershell
Add-PodeVerb -Verb 'QUIT' -Close
```

The second way is to call [`Close-PodeTcpClient`](../../Functions/Responses/Close-PodeTcpClient) directly:

```powershell
Add-PodeVerb -Verb 'QUIT' -ScriptBlock {
    Write-PodeTcpClient -Message 'Bye!'
    Close-PodeTcpClient
}
```

## Read Data

In the above examples you've seen [`Write-PodeTcpClient`](../../Functions/Responses/Write-PodeTcpClient) being used. This function simply sends data back to a connected client, but what if we want to read data? Sometimes, instead of ending a Verb's logic and letting Pode wait for the next data, you might want to receive this data yourself in a Verb. For this there is [`Read-PodeTcpClient`](../../Functions/Responses/Read-PodeTcpClient):

```powershell
Add-PodeVerb -Verb 'HELLO' -ScriptBlock {
    Write-PodeTcpClient -Message "Hi! What's your name?"
    $name = Read-PodeTcpClient
    Write-PodeTcpClient -Message "Hi, $($name)!"
}
```

## TLS

You can enable TLS for your endpoints by supplying the normal relevant certificates parameters on [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint), and setting the `-Protocol` to `Tcps`. You can also toggle between implicit and explicit TLS by using the `-TlsMode` parameter.

By default the TLS mode is implicit, and the default port for implicit TLS is 9002; for explicit TLS it's 9003. These can of course be customised using `-Port`.

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Protocol Tcps -SelfSigned -TlsMode Explicit
    Add-PodeEndpoint -Address * -Protocol Tcps -SelfSigned -TlsMode Implicit

    Add-PodeVerb -Verb 'HELLO' -ScriptBlock {
        Write-PodeTcpClient -Message 'HI'
    }
}
```

## Objects

### TcpEvent

Verbs will be passed the `$TcpEvent` object, that contains the Request, Response, and other properties:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Request | object | The raw Request object |
| Response | object | The raw Response object |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` |
| Endpoint | hashtable | Contains the Address and Protocol of the endpoint being hit - such as "pode.example.com" or "127.0.0.2", or HTTP or HTTPS for the Protocol |
| Parameters | hashtable | Contains the parsed parameter values from the Verb's path |
| Timestamp | datetime | The current date and time of the Request |

## Test Send

The following function can be used to test sending messages to a TCP server. This is a modified version of the function [found here](https://riptutorial.com/powershell/example/18118/tcp-sender).

```powershell
function Send-TCPMessage($Endpoint, $Port, $Message) {
    # Setup connection
    $Address = [System.Net.IPAddress]::Parse([System.Net.Dns]::GetHostAddresses($EndPoint))
    $Socket = New-Object System.Net.Sockets.TCPClient($Address,$Port)

    # Setup stream wrtier
    $Stream = $Socket.GetStream()
    $Writer = New-Object System.IO.StreamWriter($Stream)

    # Write message to stream
    $Writer.WriteLine($Message)
    $Writer.Flush()

    # Close connection and stream
    Start-Sleep -Seconds 1
    $Stream.Close()
    $Socket.Close()
}
```

ie:

```powershell
Send-TCPMessage -Port 9000 -EndPoint 127.0.0.1 -Message "HELLO"
```

!!! note
    If you have the `-CRLFMessageEnd` switch specified, you'll need to add ``` `r`n``` to the end of the `-Message`
