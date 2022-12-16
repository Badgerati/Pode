# Cookies

In Pode you can add/retrieve cookies for the Request/Response of the current web request. Using the cookie functions has to be done within the context of a web event, such as within Routes; Middleware; Authentication; Logging; and Endware.

## Adding Cookies

You can add a cookie to the response by using [`Set-PodeCookie`](../../Functions/Cookies/Set-PodeCookie), and passing the Name and Value of cookie:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    Set-PodeCookie -Name Cookie1 -Value Value1
}
```

You can set a duration for the cookie, in seconds, using `-Duration`, or as an explicit expiry date using `-ExpiryDate`. For example, to set a cookie to expire after 1 minute:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    Set-PodeCookie -Name Cookie1 -Value Value1 -Duration 60
}
```

## Getting Cookies

To retrieve a cookie on the request, you can use [`Get-PodeCookie`](../../Functions/Cookies/Get-PodeCookie):

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    Get-PodeCookie -Name 'CookieName'
}
```

This will return a cookie object with value, duration, etc. To retrieve just the value of a cookie use [`Get-PodeCookieValue`](../../Functions/Cookies/Get-PodeCookieValue)

## Removing Cookies

To flag a cookie for removal on the user's browser you can use [`Remove-PodeCookie`](../../Functions/Cookies/Remove-PodeCookie), which force the cookie to expire:

```powershell
Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
    Remove-PodeCookie -Name 'CookieName'
}
```

## Signing Cookies

You can sign a cookie by supplying a `-Secret` to any of the cookie functions; supplying it to [`Get-PodeCookie`](../../Functions/Cookies/Get-PodeCookie) will attempt to unsign the cookie for the raw value.

## Expiry Dates

To update the expiry of a cookie, you can set a duration, in seconds, or as an explicit expiry date using [`Update-PodeCookieExpiry`](../../Functions/Cookies/Update-PodeCookieExpiry).
