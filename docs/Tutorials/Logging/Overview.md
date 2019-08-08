# Overview

There are two aspects to logging in Pode: Methods and Types.

* Methods define how log items should be recorded, such as to a file or terminal.
* Types define how items to log are transformed, and what should be supplied to the Method.

For example when you supply an Exception to  [`Write-PodeErrorLog`](../../../Functions/Logging/Write-PodeErrorLog), this Exception is first supplied to Pode's inbuilt Error type. This type transforms any Exception (or Error Record) into a string which can then be supplied to the File logging method.

In Pode you can use File, Terminal or a Custom method. As well as Request, Error, or a Custom type.

This means you could write a logging method to output to an S3 bucket, Splunk, or any other logging platform.
