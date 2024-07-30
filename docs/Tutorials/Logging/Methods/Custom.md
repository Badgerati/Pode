# Custom

Sometimes you may want to log to platforms other than a file or the terminal, such as LogStash, Splunk, Athena, or other central logging platforms. Although Pode doesn't have these integrations built-in (yet!), it is possible to create a custom logging method by defining a ScriptBlock with the logic to send logs to these platforms.

Custom methods can be used for any log type: Requests, Error, or Custom.

The ScriptBlock you create will receive two arguments:

1. The item to be logged. This could be a string (from Requests/Errors) or any custom type.

2. The options you supplied to [`New-PodeLoggingMethod`](../../../../Functions/Logging/New-PodeLoggingMethod).

Additionally, custom logging methods can be run in their own runspace by using the `-UseRunspace` parameter, ensuring isolation and efficiency.

## Examples

### Send to S3 Bucket

This example takes the supplied item, converts it to a string, and sends it to an S3 bucket in AWS. In this case, it will log Requests:

#### Legacy (No Runspace)
```powershell
$s3_options = @{
    AccessKey = $AccessKey
    SecretKey = $SecretKey
}

$s3_logging = New-PodeLoggingMethod -Custom -ArgumentList $s3_options -ScriptBlock {
    param($item, $s3_opts)

    Write-S3Object \`
        -BucketName '<name>' \`
        -Content $item.ToString() \`
        -AccessKey $s3_opts.AccessKey \`
        -SecretKey $s3_opts.SecretKey
}
$s3_logging | Enable-PodeRequestLogging
```


#### With Runspace

```powershell
$s3_options = @{
    AccessKey = $AccessKey
    SecretKey = $SecretKey
}

$s3_logging = New-PodeLoggingMethod -Custom -UseRunspace -CustomOptions $s3_options -ScriptBlock {

    Write-S3Object \`
        -BucketName '<name>' \`
        -Content $item.ToString() \`
        -AccessKey $options.AccessKey \`
        -SecretKey $options.SecretKey
}
$s3_logging | Enable-PodeRequestLogging
```


In this example, the `-UseRunspace` parameter ensures that the custom logging method runs in its own runspace, providing better isolation and performance.

By leveraging custom logging methods, you can extend Pode's logging capabilities to integrate with a wide range of external platforms, providing flexibility and control over your logging strategy.
