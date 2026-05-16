# Custom

You can define a Custom logging Type in Pode by using [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType). Much like Requests and Errors, this function too accepts any logging Method - such as the [Terminal](../../Methods/Terminal) Method.

When adding a Custom logging Type, you supply a `-ScriptBlock` plus an array of optional arguments in `-ArgumentList`. The function also requires a unique `-Name`, so that it can be referenced from [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

The ScriptBlock will be supplied with the following arguments:

1. A transformed, or raw, log item to log that was supplied via [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).
2. The arguments that were supplied from [`Add-PodeLogType`](../../../../Functions/Logging/Add-PodeLogType)'s `-ArgumentList` parameter.

## Examples

### Write to File

This example will create a Custom logging Type that will take some custom hashtable, transform it into a string, and then pass that to the inbuilt File logging Method:

```powershell
New-PodeLogFileMethod -Name 'Custom' | Add-PodeLogType -Name 'Main' -ScriptBlock {
    param($item, $arg1, $arg2)
    return "$($item.Key1), $($item.Key2), $($item.Key3)"
} -ArgumentList $arg1, $arg2

Write-PodeLog -Name 'Main' -InputObject @{
    Key1 = 'Value1'
    Key2 = 'Value2'
    Key3 = 'Value3'
}
```
