# Custom

You can define Custom logging types in Pode by using the [`Add-PodeLogger`](../../../../Functions/Logging/Add-PodeLogger) function. Much like Requests and Errors, this function too accepts any logging method from [`New-PodeLoggingMethod`](../../../../Functions/Logging/New-PodeLoggingMethod).

When adding a Custom logger, you supply a `-ScriptBlock` plus an array of optional arguments in `-ArgumentList`. The function also requires a unique `-Name`, so that it can be referenced from the [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog) function.

The ScriptBlock will be supplied with the following arguments:

1. The item to log that was supplied via [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).
2. The arguments that were supplied from [`Add-PodeLogger`](../../../../Functions/Logging/Add-PodeLogger)'s `-ArgumentList` parameter.

## Examples

### Write to File

This example will create a Custom logging method that will take some custom hashtable, transform it into a string, and then return the string. That string will then be passed to the inbuilt File logging method:

```powershell
New-PodeLoggingMethod -File -Name 'Custom' | Add-PodeLogger -Name 'Main' -ScriptBlock {
    param($item, $arg1, $arg2)
    return "$($item.Key1), $($item.Key2), $($item.Key3)"
} -ArgumentList $arg1, $arg2

Write-PodeLog -Name 'Main' -InputObject @{
    Key1 = 'Value1'
    Key2 = 'Value2'
    Key3 = 'Value3'
}
```
