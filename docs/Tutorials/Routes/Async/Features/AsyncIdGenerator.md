# AsyncIdGenerator

The `AsyncIdGenerator` parameter specifies the function used to generate unique IDs for asynchronous tasks. This allows you to customize the way IDs are generated for each async task, ensuring they meet your application's requirements.

- **Default Value**: The default function used is `New-PodeGuid`, which generates a unique GUID for each task.

#### Customizing Async ID Generation

You can define your own custom function to generate IDs by specifying it in the `AsyncIdGenerator` parameter. This can be useful if you need to follow a specific format or include particular information in the IDs.

**Example Usage**

```powershell
function New-CustomAsyncId {
    return [guid]::NewGuid().ToString() + "-custom"
}

Add-PodeRoute -PassThru -Method Post -Path '/customAsyncId' -ScriptBlock {
    return @{ Message = "Custom Async ID" }
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -AsyncIdGenerator New-CustomAsyncId
```

In this example, the `New-CustomAsyncId` function generates a GUID with a custom suffix, ensuring each async task has a unique and identifiable ID.

