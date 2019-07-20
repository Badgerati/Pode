# Csv

## Description

The `csv` function converts an `array` of `hashtable` values, or reads in a file, and converts it to a CSV; the value is then written to the web response. You can also supply raw CSV data as the value to write.

## Examples

### Example 1

The following example will convert an `array` of `hashtable` values to a CSV and write it to a web response within a `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/info' -ScriptBlock {
        csv @( @{'Name' = 'Bob'; 'Age' = 29 }, @{ 'Name' = 'James'; 'Age' = 23 })
    }
}
```

### Example 2

The following example will write raw CSV data to a web response within a `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/info' -ScriptBlock {
        csv "Name, Age`nBob, 29`nJames, 23"
    }
}
```

### Example 3

The following example will read in a file, and write the contents as CSV to a web response within a `route`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/data' -ScriptBlock {
        csv -file './files/data.csv'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Value | hashtable[]/string | true | The value should either be an array of `hashtable` values or string - the string can be either a path or raw CSV. It will be converted to CSV, if not raw, and attached to the web response | null |
| File | switch | false | If passed, the value should be a string that's a path to a CSV file | false |
