# Body Parsing

Pode has inbuilt body/payload parsing on Requests, which by default can parse the following content types:

* `*/json`
* `*/xml`
* `*/csv`
* `*/x-www-form-urlencoded`
* `multipart/form-data`

This is useful however, there can be times when you might want to use a different JSON parsing library - or parse a completely different content type altogether! This is possible using the [`Add-PodeBodyParser`](../../../../Functions/Middleware/Add-PodeBodyParser) function.

## Adding a Parser

You can use the [`Add-PodeBodyParser`](../../../../Functions/Middleware/Add-PodeBodyParser) function to define a scriptblock that can parse the Request body for a specific content type. Any set parsers have a higher priority than the inbuilt ones, meaning if you define a parser for `application/json` then this will be used instead of the inbuilt one.

The scriptblock you supply will be supplied a single argument, which will be the Body of the Request.

For example, to set your own JSON parser that will simply return the body unmodified you could do the following:

```powershell
Add-PodeBodyParser -ContentType 'application/json' -ScriptBlock {
    param($body)
    return $body
}
```

This can then be accessed the normal way within a Route from the `.Data` object on the supplied event:

```powershell
Add-PodeRoute -Method Post -Path '/' -ScriptBlock {
    param($e)

    # if using the above parser, .Data here will just be a plain string
    Write-PodeTextResponse -Value $e.Data
}
```

This is great if you want to be able to parse other content types like YAML, HCL, or many others!

## Removing a Parser

To remove a defined parser you can use the [`Remove-PodeBodyParser`](../../../../Functions/Middleware/Remove-PodeBodyParser) function:

```powershell
Remove-PodeBodyParser -ContentType 'application/json'
```

!!! note
    This will only remove defined custom parsers, and will not affect the inbuilt parsers.
