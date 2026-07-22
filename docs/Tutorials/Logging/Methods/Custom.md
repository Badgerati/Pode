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

## Examples

### Send to S3 Bucket

This example, which uses `-Version 2` for the supplied parameters, will the supplied [Log Item](../../Objects#log-item), convert it to a string, and then send it off to some S3 bucket in AWS. In this case, it will be logging Requests:

```powershell
$s3_options = @{
    AccessKey = $AccessKey
    SecretKey = $SecretKey
}

$s3_logging = New-PodeLogCustomType -ArgumentList $s3_options -Version 2 -ScriptBlock {
    param($logItem, $s3_opts)

    Write-S3Object `
        -BucketName '<name>' `
        -Content $logItem.ToString() `
        -AccessKey $s3_opts.AccessKey `
        -SecretKey $s3_opts.SecretKey
}

$s3_logging | Enable-PodeLogRequestType
```
