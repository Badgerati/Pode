# Web Event

When a request is made to your server, a "web event" object is created. This object contains a lot of useful information about the request, and the response.

This web event is a normal HashTable, and is always accessible from your Routes, Middleware, Endware, and Authentication ScriptBlocks as the `$WebEvent` variable:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    $WebEvent | Out-Default
}
```

## Properties

!!! warning
    It is advised not to directly alter these values, other than the ones through the documentation that say you can - such as Session Data.

| Name | Type | Description | Docs |
| ---- | ---- | ----------- | ---- |
| Auth | hashtable | Contains the information on the currently authenticated user from the `Add-PodeAuth` methods - the user's details can be further accessed in the sub `.User` property | [link](../Authentication/Overview/#users) |
| ContentType | string | The content type of the data in the Request's payload | n/a |
| Cookies | hashtable | Contains all cookies parsed from the Request's headers - it's best to use Pode's Cookie functions to access/change Cookies | [link](../Cookies) |
| Data | hashtable | Contains the parsed items from the Request's payload | [link](../Routes/Overview/#payloads) |
| Endpoint | hashtable | Contains the Address and Protocol of the endpoint being hit - such as "pode.example.com" or "127.0.0.2", or HTTP or HTTPS for the Protocol | [link](../Endpoints/Basics), [properties](#endpoints) |
| ErrorType | string | Set by the current Route being hit, this is the content type of the Error Page that will be used if an error occurs | [link](../Routes/Utilities/ErrorPages) |
| Files | hashtable | Contains any file data from the Request's payload | [link](../Misc/UploadFiles) |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` | n/a |
| Method | string | The current HTTP method of the Request | [link](../Routes/Overview) |
| OnEnd | array | An array of extra Endware scriptblocks | [link](../Endware) |
| Parameters | hashtable | Contains the parsed parameter values from the Route's path | [link](../Routes/Overview/#parameters) |
| Path | string | The current path of the Request, after the endpoint - such as "/about" | [link](../Routes/Overview) |
| PendingCookies | hashtable | Contains cookies that will be written back on the Response - it's best to use Pode's Cookies functions to access/change Cookies | [link](../Cookies) |
| Query | hashtable | Contains the parsed items from the Request's query string | [link](../Routes/Overview/#query-strings) |
| Request | object | The raw Request object | [properties](#request) |
| Response | object | The raw Response object | [properties](#response) |
| Route | hashtable | The current Route that is being invoked - the properties here are the same as called [`Get-PodeRoute`](../../Functions/Routes/Get-PodeRoute) | [link](../Routes/Overview) |
| Session | hashtable | Contains details about, and any data stored in the current session - this data can be accessed in the sub `.Data` property | [link](../Middleware/Types/Sessions) |
| StaticContent | hashtable | Contains details about the source path, if the route is a custom Static Route | [link](../Routes/Utilities/StaticContent), [properties](#static-content) |
| Streamed | bool | Specifies whether the current server type uses streams for the Request/Response, or raw strings | n/a |
| Timestamp | datetime | The current date and time of the Request | n/a |

### Endpoints

These are the properties available for `$WebEvent.Endpoint`

| Name | Type | Description | Docs |
| ---- | ---- | ----------- | ---- |
| Address | string | The ip/hostname being used for the Request. ie: 127.0.0.1 or example.com | n/a |
| Name | string | The name of the Pode Endpoint being used for the Request | [link](../Endpoints/Basics/#endpoint-names) |
| Protocol | string | The protocol being used for the Request. ie: HTTP, HTTPS, WS, WSS, etc. | n/a |

### Static Content

These are the properties available for `$WebEvent.StaticContent`

| Name | Type | Description | Docs |
| ---- | ---- | ----------- | ---- |
| IsCachable | bool | Whether or not the file should be cached on the client side | n/a |
| IsDownload | bool | Whether or not the file should be attached or rendered | n/a |
| Source | string | The local path, using PSDrives, to the file on the server | n/a |

### Request

These are the properties available for `$WebEvent.Request`

!!! warning
    This is an internal .NET Pode object. While you can use the properties on this object, try to refrain from relying on them heavily as they could change in future updates from refactoring. If there's a property you find yourself using a lot, and there's not a direct WebEvent property or function to access it, feel free to raise an Enhancement request!

!!! warning
    Changing properties on this object could cause errors, unwanted behaviour, or a full server crash. Only edit them if you know what you're doing. Same for calling any methods.

| Name | Type | Description | Example |
| ---- | ---- | ----------- | ------- |
| Address | string | The address being used by the Request. This will favour hostnames over IPs | - |
| AllowClientCertificate | bool | Whether Pode should expect, and process, and client certificates | - |
| AwaitingBody | bool | If the request is chunked, this flags if Pode is still awaiting for the whole body to be sent | - |
| Body | string | The textually encoded version of the RawBody | - |
| Certificate | X509Certificate | The certificate being used for SSL connections. Usually defined from [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) | - |
| ClientCertificate | X509Certificate2 | If being used, the client certificate supplied on the Request | - |
| ClientCertificateErrors | SslPolicyErrors | Contains any errors that might have occurred while validating the client certificate. Pode ignores these by default, so they will need checking the [Client Certificate Authenication](../Authentication/Methods/ClientCertificate) | - |
| CloseImmediately | bool | Whether this Request should be closed immediately. Used internally, you'll likely never see this set to true | - |
| ContentEncoding | Encoding | The encoding used for the content | UTF8 |
| ContentLength | int | The size of the content in the Request's payload | - |
| ContentType | string | The type of content being supplied in the Request's payload | application/json |
| Error | HttpRequestException | Contains any errors thrown internally, that will be bubbled back up to Pode for logging |  |
| Form | PodeForm | Contains information about any form elements sent in the Request | - |
| Headers | Hashtable | A collectio of every header sent in the Request | - |
| Host | string | The ip/hostname used for the Request | 127.0.0.1, example.com |
| HttpMethod | string | The HTTP method of the current Request | GET, POST, etc. |
| InputStream | Stream | The stream used to read the inbound connection's data | - |
| IsAborted | bool | Whether the Request should be aborted. Used internally, you'll likely never see this set to true | - |
| IsDisposed | bool | Whether the current Request is disposed | - |
| IsProcessable | bool | Whether this Request should be processed. Used internally, you'll likely never see this set to false | - |
| IsSsl | bool | Whether the connection is currently over SSL or not | - |
| KeepAlive | bool | Whether the connection should be kept alive, or terminated after use | - |
| LocalEndPoint | EndPoint | Details about the local connection | - |
| Protocol | string | The protocol type being used | HTTP/1.1 |
| Protocols | SslProtocols | The SSL protocols allowed to be used for connections | SSL3, TLS1.2 |
| ProtocolVersion | string | The protocol version of the protocol type | 1.1 |
| QueryString | NameValueCollection | A collection of the key/values supplied on the Request's query string | - |
| RawBody | byte[] | The raw bytes of the Request's payload | - |
| RemoteEndPoint | EndPoint | Details about the remote connection | - |
| Scheme | string | The connection scheme being used | HTTP, HTTPS, etc. |
| SslUpgraded | bool | Whether this connection has been upgraded to SSL. Used for implicit connections | - |
| TlsMode | PodeTlsMode | Whether the connection is using implicit or explicit TLS | - |
| TransferEncoding | string | The transfer encoding used for the content | gzip, chunked, identity |
| Url | Uri | The whole Request URL that was made | http://example.com?name=value |
| UrlReferrer | string | The referred of the Request | - |
| UserAgent | string | The user agent of where the Request originated | - |

### Response

These are the properties available for `$WebEvent.Response`

!!! warning
    This is an internal .NET Pode object. While you can use the properties on this object, try to refrain from relying on them heavily as they could change in future updates from refactoring. If there's a property you find yourself using a lot, and there's not a direct WebEvent property or function to access it, feel free to raise an Enhancement request!

!!! warning
    Changing properties on this object could cause errors, unwanted behaviour, or a full server crash. Only edit them if you know what you're doing. Same for calling any methods.

| Name | Type | Description | Example |
| ---- | ---- | ----------- | ------- |
| ContentLength64 | long | The length of the data that is being sent back | - |
| ContentType | string | The content type of the data that's being sent back | application/json |
| Headers | PodeResponseHeaders | A collection of headers that should be sent back to the client | -  |
| HttpResponseLine | string | Internal Only. This is just a prebuilt value, which represents the first line of a raw HTTP Response | - |
| IsDisposed | bool | Whether the current Response is disposed | - |
| OutputStream | MemoryStream | The stream that's used to write data back to the client | - |
| SendChunked | bool | Whether or not the response should be sent back in chunks | - |
| Sent | bool | Whether or not this Response has already been sent tot the client | - |
| StatusCode | int | The status code to send back to the client | 200, 401, 500, etc. |
| StatusDescription | string | The statuc description to send back, based on the status code | OK, Not Found, etc. |

## Customise

The web event itself is just a HashTable, which means you can add your own properties to it within Middleware for further use in other Middleware down the flow, or in the Route itself.

Make sure these custom properties have a unique name, so as to not clash with already existing properties.
