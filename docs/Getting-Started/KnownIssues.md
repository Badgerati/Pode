# Known Issues

Below is a list of reported issues when using Pode, and the way to resolve them:

## Long URL Segements

Reported in issue [#45](https://github.com/Badgerati/Pode/issues/45).

On Windows systems there is a limit on the maximum length of URL segments. It's usually about 260 characters, and anything above this will cause Pode to throw a 400 Bad Request error.

To resolve, you can set the `UrlSegmentMaxLength` registry setting to 0 (for unlimited), or any other value. The below PowerShell will set the value to unlimited:

```powershell
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\HTTP\Parameters' -Name 'UrlSegmentMaxLength' -Value 0 -PropertyType DWord -Force
```