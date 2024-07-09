# Known Issues

Below is a list of reported issues when using Pode and, if possible, how to resolve them:

## Long URL Segments

Reported in issue [#45](https://github.com/Badgerati/Pode/issues/45).

On Windows systems, there is a limit on the maximum length of URL segments. It's usually about 260 characters and anything above this will cause Pode to throw a 400 Bad Request error.

To resolve this, you can set the `UrlSegmentMaxLength` registry setting to 0 (for unlimited), or any other value. The below PowerShell will set the value to unlimited:

```powershell
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\HTTP\Parameters' -Name 'UrlSegmentMaxLength' -Value 0 -PropertyType DWord -Force
```

> This is not an issue on Linux

## PowerShell Classes

Pode utilizes Runspaces for multithreading and other background tasks, which makes PowerShell classes behave unpredictably and renders them unsafe to use. This is primarily because an instance of a class created in one Runspace will always be marshaled back to the original Runspace whenever it is accessed again, potentially causing Routes and Middleware to become contaminated.

For more details on this issue, you can refer to the [PowerShell GitHub issue](https://github.com/PowerShell/PowerShell/issues/3651).

To avoid these problems, it is recommended to use Hashtables or PSObjects instead.

However, if you need to use classes, PowerShell 7.4 introduces the `[NoRunspaceAffinity()]` attribute that makes classes thread-safe by solving this issue.

Here's an example of a class definition with the `[NoRunspaceAffinity()]` attribute:

```powershell
# Class definition with NoRunspaceAffinity attribute
[NoRunspaceAffinity()]
class SafeClass {
    static [object] ShowRunspaceId($val) {
        return [PSCustomObject]@{
            ThreadId   = [Threading.Thread]::CurrentThread.ManagedThreadId
            RunspaceId = [runspace]::DefaultRunspace.Id
        }
    }
}
```

If you need to support versions prior to PowerShell 7.4, you can use the following approach:

* Create a module (CreateClassInstanceHelper.psm1) with the content:

```powershell
$Script:powershell = $null
$Script:body = @'
    function New-UnboundClassInstance ([Type]$type, [object[]]$arguments) {
        [activator]::CreateInstance($type, $arguments)
    }
'@

function Initialize
{
    # A runspace is created and NO powershell class is defined in it
    $Script:powershell = [powershell]::Create()

    # Define a function in that runspace to create an instance using the given type and arguments
    $Script:powershell.AddScript($Script:body).Invoke()
    $Script:powershell.Commands.Clear()
}

function New-UnboundClassInstance([Type]$type, [object[]]$arguments = $null)
{
    if ($null -eq $Script:powershell) {
        Initialize
    }

    try {
        # Pass in the powershell class type and ctor arguments and run the helper function in the other runspace
        if ($null -eq $arguments) {
            $arguments = @()
        }

        $result = $Script:powershell.AddCommand("New-UnboundClassInstance").
                                     AddParameter("type", $type).
                                     AddParameter("arguments", $arguments).
                                     Invoke()
        return $result[0]
    }
    finally {
        $Script:powershell.Commands.Clear()
    }
}
```

* Then when you need to create a PowerShell class instance, you can do the following from some Route or Middleware:

```powershell
Import-Module '<path>\CreateClassInstanceHelper.psm1'
New-UnboundClassInstance([Foo], $argsForCtor)
```

## Certificates

For HTTPS there are a few issues you may run into, and to resolve them you can use the below:

* On Windows, you may need to install the certificate into your Trusted Root on the Local Machine (mostly for self-signed certificates).
* You may be required to run the following, to force TLS1.2, before making web requests:

```powershell
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
```

* On *nix platforms, for self-signed certificates, you may need to use `-SkipCertificateCheck` on `Invoke-WebRequest` and `Invoke-RestMethod`.

## ActiveDirectory Module

If you're using commands from the ActiveDirectory module - such as `Get-ADUser` - and they're not working as expected, you'll need to import the module first so it's loaded into the runspaces appropriately:

```powershell
Import-Module ActiveDirectory

Start-PodeServer {
    # ...
}
```

## CIM Modules

Similar to the Active Directory module above, various other internal Windows modules have a dependency on WMI or CIM - such as SmbShare or NetAdapter. These modules also suffer issues when not imported before `Start-PodeServer`, such as missing properties or incorrect values.

To resolve this you just need to import the modules beforehand. For example, if using SmbShare functions:

```powershell
Import-Module SmbShare

Start-PodeServer {
    # ...
}
```

## Loader Errors / Pode Types

If on importing the module you receive Loader Exceptions, or when starting your server you get an error similar to `[PodeListener] not found`, then you will need to update to .NET 4.7.2.

## Slow Requests

If you are experiencing slow response times on Windows using either `Invoke-WebRequest` or `Invoke-RestMethod`, this could be due to a quirk in how these functions work - whereby they try to send the request using IPv6 first, then try IPv4. To potentially resolve the slowness, you can either:

1. Use the IPv4 address instead of the hostname. For example, using `http://127.0.0.1:8080` instead of `http://localhost:8080`.
2. Enable [Dual Mode](../../Tutorials/Endpoints/Basics#dual-mode) on your [`Add-PodeEndpoint`](../../Functions/Core/Add-PodeEndpoint) so that it listens on both IPv4 and IPv6.
