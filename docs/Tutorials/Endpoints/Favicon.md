# Favicons

Pode allows you to customize favicons served from HTTP/HTTPS endpoints using a set of dedicated commands. By default, Pode does not serve any favicon until one is explicitly configured using the provided favicon commands.

## Overview

Favicons are the small icons displayed in browser tabs, bookmarks, and other UI elements. Pode supports using favicons in the standard ICO format, as well as other common web image formats such as PNG or SVG (depending on browser support).

---

## Managing Favicons

Pode provides the following functions to manage favicons:

- `Add-PodeFavicon`: Adds a favicon to one or more endpoints.
- `Remove-PodeFavicon`: Removes the favicon from one or more endpoints.
- `Get-PodeFavicon`: Retrieves the current favicons assigned to endpoints.
- `Test-PodeFavicon`: Checks whether a favicon is configured on one or more endpoints.

These functions support targeting specific endpoints by name, or applying changes globally to all endpoints. You can also limit operations to only endpoints marked as default using the `-DefaultEndpoint` switch.

---

## Supported Formats

Favicons are typically stored in `.ico` format but Pode also supports:

- `.ico`: Multi-resolution raster format. Preferred for compatibility.
- `.png`: Lossless compressed raster format. Supported in modern browsers.
- `.svg`: Vector-based, resolution-independent. Supported in modern browsers with limitations.

Other formats like `.jpg` or `.gif` may work but are not recommended due to lack of transparency or limited quality.

For further details on favicon formats and specifications, refer to the [Favicon specification]([https://en.wikipedia.org/wiki/Favicon](https://en.wikipedia.org/wiki/Favicon)) and [RFC 5988]([https://datatracker.ietf.org/doc/html/rfc5988](https://datatracker.ietf.org/doc/html/rfc5988)).

---

## Recommended Sizes

Favicons should include multiple resolutions for optimal display across different devices. Recommended sizes include:

- **16x16** : Used in browser tabs, bookmarks, and address bars.

- **32x32** : Used in browser tabs on higher-resolution displays.

- **48x48** : Used by some older browsers and web applications.

- **64x64** : Generally not used by browsers but can be helpful for scalability in web apps.

- **256x256** : Mainly for **Windows app icons** (not typically used as a favicon in browsers).

---

## Usage Examples

### Add default Pode favicon to all HTTP/S endpoints

```powershell
Add-PodeFavicon -Default
```

### Add a custom favicon from file to all endpoints

```powershell
Add-PodeFavicon -Path './assets/favicon.ico'
```

### Add a favicon to a specific endpoint using binary data

```powershell
$icon = [System.IO.File]::ReadAllBytes('C:\icons\custom.ico')
Add-PodeFavicon -Binary $icon -EndpointName 'api'
```

### Add a favicon only to endpoints marked as default

```powershell
Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http
$iconBytes = [System.IO.File]::ReadAllBytes("C:\path\to\custom.ico")
Add-PodeFavicon -Binary $iconBytes -DefaultEndpoint
```

### Remove all favicons from all endpoints

```powershell
Remove-PodeFavicon
```

### Remove favicon from a specific endpoint

```powershell
Remove-PodeFavicon -EndpointName 'admin'
```

### Get all currently assigned favicons

```powershell
Get-PodeFavicon
```

### Test if a favicon exists on all default endpoints

```powershell
Test-PodeFavicon -DefaultEndpoint
```

---

## Notes

- Only HTTP and HTTPS endpoints support favicons.
- You can assign favicons only after endpoints are created.
- Favicons are stored in-memory as part of the endpoint object.
- Use `-DefaultEndpoint` with any command to target only default endpoints.
