# Headers

In Pode you can add/retrieve headers for the Request/Response of the current web event. Using the header functions has to be done within the context of a web event, such as in Routes/Middleware/Authentication/Logging/Endware.

## Setting Headers

There are 2 ways of setting headers on a response: [`Add-PodeHeader`](../../Functions/Headers/Add-PodeHeader) and [`Set-PodeHeader`](../../Functions/Headers/Set-PodeHeader).

[`Add-PodeHeader`](../../Functions/Headers/Add-PodeHeader) will append multiple values for one header on the response - such as the `Set-Cookie` header of which there can be multiple of on a response. The following will add 2 of the same header on the response:

```powershell
Add-PodeMiddleware -Name Example -ScriptBlock {
    Add-PodeHeader -Name Name1 -Value Value1
    Add-PodeHeader -Name Name1 -Value Value2
}
```

[`Set-PodeHeader`](../../Functions/Headers/Set-PodeHeader) will clear all current values for a header on the response, and reset it to one value. The following will add 2 of the same header to the response, but then override that to 1 header:

```powershell
Add-PodeMiddleware -Name Example -ScriptBlock {
    Add-PodeHeader -Name Name1 -Value Value1
    Add-PodeHeader -Name Name1 -Value Value2

    Set-PodeHeader -Name Name1 -Value Value3
}
```

## Getting Headers

To retrieve the value of a header on the request, you can use [`Get-PodeHeader`](../../Functions/Headers/Get-PodeHeader):

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    Get-PodeHeader -Name 'X-Header-Name'
}
```

## Signing Headers

You can sign a header by supplying a `-Secret` to any of the header functions; supplying it to [`Get-PodeHeader`](../../Functions/Headers/Get-PodeHeader) will attempt to unsign the header for the raw value.
