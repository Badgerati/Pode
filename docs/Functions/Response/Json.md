# Json

## Description

The `json` function converts a `hashtable`, or reads in a file, and converts it to JSON; the JSON value is then written to the web response. You can also supply raw JSON data as the value to write.

## Examples

### Example 1

The following example will convert a `hashtable` to JSON and write it to a web response within a `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/info' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'cpu' = 80; 'memory' = 15; }
    }
}
```

### Example 2

The following example will write raw JSON data to a web response within a `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/info' -ScriptBlock {
        json '{ "cpu": 80, "memory": 15 }'
    }
}
```

### Example 3

The following example will read in a file, and write the contents as JSON to a web response within a `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/data' -ScriptBlock {
        json -file './files/data.json'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Value | hashtable/string | false | The value should either be a `hashtable` or string - the string can be either a path or raw JSON. It will be converted to JSON, if not raw, and attached to the web response | null |
| File | switch | false | If passed, the value should be a string that's a path to a JSON file | false |
