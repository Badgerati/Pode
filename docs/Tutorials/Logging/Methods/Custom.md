# Custom

Sometimes you don't want to log to a file, or the terminal; instead you want to log to something better, like LogStash, Splunk, Athena, or any other central logging platform. Although Pode doesn't have these inbuilt (yet!) it is possible to create a custom logging method, where you define a ScriptBlock with logic to send logs to these platforms.

These custom method can be used for any log type - Requests, Error, or Custom.

The ScriptBlock you create will be supplied two arguments:

1. The item to be logged. This could be a string (from Requests/Errors), or any custom type.
2. The options you supplied on [`New-PodeLoggingMethod`](../../../../../Functions/Logging/New-PodeLoggingMethod).

## Examples

### Send to S3 Bucket

This example will take whatever item is supplied to it, convert it to a string, and then send it off to some S3 bucket in AWS. In this case, it will be logging Requests:

```powershell
$s3_options = @{
    AccessKey = $AccessKey
    SecretKey = $SecretKey
}

$s3_logging = New-PodeLoggingType -Custom -Options $s3_options -ScriptBlock {
    param($item, $opts)

    Write-S3Object `
        -BucketName '<name>' `
        -Content $item.ToString() `
        -AccessKey $opts.AccessKey `
        -SecretKey $opts.SecretKey
}

$s3_logging | Enable-PodeRequestLogging
```
