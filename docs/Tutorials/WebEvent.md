# Web Event

When a request is made to your server, a "web event" object is created that contains a lot of useful information about the request (and the response!).

This web event is a normal HashTable, and is always supplied as the first parameter to your Routes, Middleware, Endware, custom Authentication type ScriptBlocks:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    param($e)
    # that $e is the web event!
}
```

## Properties

!!! warning
    It is advised not to directly alter these values, other than the ones through the documentation that say you can - such as Session Data.

| Name | Type | Description |
| ---- | ---- | ----------- |
| Auth | hashtable | Contains the information on the currently authenticated user from the `Add-PodeAuth` methods - the user's details can be further accessed in the sub `.User` property |
| ContentType | string | The content type of the data in the Request's payload |
| Cookies | hashtable | Contains all cookies parsed from the Request's headers |
| Data | hashtable | Contains the parsed items from the Request's payload |
| Endpoint | string | The current endpoint being hit - such as "pode.example.com" or "127.0.0.2" |
| ErrorType | string | Set by the current Route being hit, this is the content type of the Error Page that will be used if an error occurs |
| Files | hashtable | Contains any file data from the Request's payload |
| Lockable | hashtable | A synchronized hashtable that can be used with `Lock-PodeObject` |
| Method | string | The current HTTP method of the Request |
| OnEnd | array | An array of extra Endware scriptblocks |
| Parameters | hashtable | Contains the parsed parameter values from the Route's path |
| Path | string | The current path of the Request, after the endpoint - such as "/about" |
| PendingCookies | hashtable | Contains cookies that will be written back on the Response |
| Protocol | string | The current protocol of the Request - HTTP or HTTPS |
| Query | hashtable | Contains the parsed items from the Request's query string |
| Request | object | The raw Request object |
| Response | object | The raw Response object |
| Session | hashtable | Contains details about, and any data stored in the current session - this data can be accessed in the sub `.Data` property |
| Streamed | bool | Specifies whether the current server type uses streams for the Request/Response, or raw strings |
| Timestamp | datetime | The current date and time of the Request |

## Customise

The web event itself is just a HashTable, which means you can add your own properties to it within Middleware for further use in other Middleware down the flow, or in the Route itself.
