# Custom

If you want to log to different provider not yet supported by Pode, you can create a custom Log Method where you define a ScriptBlock with logic to send logs to these platforms.

!!! important
    The `New-PodeLoggingMethod` function is now deprecated, please use [`New-PodeLogCustomMethod`](../../../../Functions/Logging/New-PodeLogCustomMethod) instead.

## Creation

To create a custom Log Method you use [`New-PodeLogCustomMethod`](../../../../Functions/Logging/New-PodeLogCustomMethod). These custom Log Methods can be used with any Log Type - Requests, Error, or Custom Types.

The scriptblock you provide will be supplied with the following parameters, depending on the `-Version` supplied (default: 1)

**Version 1**

1. The transformed log item(s) to be logged. This could be a string (from Requests/Errors), or any custom type.
2. The arguments that were supplied from [`New-PodeLogCustomMethod`](../../../../Functions/Logging/New-PodeLogCustomMethod)'s `-ArgumentList` parameter.
3. The original raw log data from, for example, [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

**Version 2**

1. A list of [Log Items](../../Objects#log-item).
2. The arguments that were supplied from [`New-PodeLogCustomMethod`](../../../../Functions/Logging/New-PodeLogCustomMethod)'s `-ArgumentList` parameter.

## Override

You can use [`New-PodeLogCustomOverride`](../../../../Functions/Logging/New-PodeLogCustomOverride) to override certain properties of a Custom Log Method, when calling either [`Write-PodeErrorLog`](../../../../Functions/Logging/Write-PodeErrorLog) or [`Write-PodeLog`](../../../../Functions/Logging/Write-PodeLog).

You can specify a hashtable of custom properties via `-Data`, as well as specify `-Ignore`, which allows you to specify that certain log items will not be logged to Custom Log Method.

If you don't specify an `-Id` then the override will apply to all Custom Log Methods configured for a Log Type.

```powershell
# supply custom override properties for a Custom Log Method
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogCustomOverride -Data @{
        Key1 = 'Value1'
        Key2 = 'Value2'
    }
)

# if you have an error log method configured with custom and terminal logging,
# the below will only log the error to the terminal and ignore logging to custom
$_ | Write-PodeErrorLog -Override @(
    New-PodeLogCustomOverride -Ignore
)
```

Within your `-ScriptBlock` for your Custom Log Method, you can retrieve the override data for a Log Event using [`Get-PodeLogOverride`](../../../../Functions/Logging/Get-PodeLogOverride):

```powershell
# setup the method
$method - New-PodeLogCustomType -ArgumentList @{ Key1 = 'Value1' } -Version 2 -ScriptBlock {
    param($logItems, $opts)

    foreach ($logItem in $logItems) {
        # get override data
        $override = Get-PodeLogOverride -LogEvent $logItem.Event

        # check overrides
        $key1 = Protect-PodeValue -Value $override.Data.Key1 -Default $opts.Key1

        # log your item
        $item = @{
            Key1    = $key1
            Message = $logItem.ToString()
        }
        $item | Out-Default
    }
} | Enable-PodeLogErrorType

# log to it
try {
    # ...
}
catch {
    $_ | Write-PodeErrorLog -Override @(
        New-PodeLogCustomOverride -Data @{ Key1 = 'Value1000' }
    )
}
```

## Examples

### Send to S3 Bucket

This example, which uses `-Version 2` for the supplied parameters, will the supplied [Log Item](../../Objects#log-item), convert it to a string, and then send it off to some S3 bucket in AWS. In this case, it will be logging Requests:

```powershell
$s3_options = @{
    AccessKey = $AccessKey
    SecretKey = $SecretKey
}

$s3_logging = New-PodeLogCustomType -ArgumentList $s3_options -Version 2 -ScriptBlock {
    param($logItems, $s3_opts)

    foreach ($logItem in $logItems) {
        Write-S3Object `
            -BucketName '<name>' `
            -Content $logItem.ToString() `
            -AccessKey $s3_opts.AccessKey `
            -SecretKey $s3_opts.SecretKey
    }
}

$s3_logging | Enable-PodeLogRequestType
```
