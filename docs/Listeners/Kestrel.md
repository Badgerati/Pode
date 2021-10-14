# Kestrel

Starting from Pode 2.0, there is now support for Kestrel as a custom listener for Pode. This Kestrel listener can be found in the [Pode.Kestrel](https://github.com/Badgerati/Pode.Kestrel) module. The Kestrel listener, at present, only supports HTTP/HTTPS.

!!! important
    The Kestrel listener only works in PowerShell 6.0+

## Usage

To begin using the Kestrel listener, you'll first need to install the module:

```powershell
Install-Module -Name Pode.Kestrel
```

then, in your main server script, you'll need to import the module and set the `-ListenerType`:

```powershell
Import-Module -Name Pode.Kestrel

Start-PodeServer -ListenerType Kestrel {
    # endpoints, routes, etc
}
```

and that's it!
