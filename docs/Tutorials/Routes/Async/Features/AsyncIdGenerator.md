# IdGenerator

The `IdGenerator` parameter specifies the function used to generate unique IDs for asynchronous tasks. This allows you to customize the way IDs are generated for each async route task, ensuring they meet your application's requirements.

- **Default Value**: The default function used is `New-PodeGuid`, which generates a unique GUID for each task.

#### Customizing Async ID Generation

You can define your own custom function to generate IDs by specifying it in the `IdGenerator` parameter. This can be useful if you need to follow a specific format or include particular information in the IDs.

**Example Usage**

```powershell

Add-PodeRoute -PassThru -Method Post -Path '/customAsyncId' -ScriptBlock {
    return @{ Message = "Custom Async ID" }
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -IdGenerator  {return [guid]::NewGuid().ToString() + "-custom" }
```

In this example, the `New-CustomAsyncId` function generates a GUID with a custom suffix, ensuring each async route task has a unique and identifiable ID.

