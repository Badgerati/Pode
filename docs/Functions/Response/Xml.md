# Xml

## Description

The `xml` function converts a `hashtable`, or reads in a file, and converts it to XML; the XML value is then written to the web response. You can also supply raw XML data as the value to write.

## Examples

### Example 1

The following example will convert a `hashtable` to XML and write it to a web response within a `route`:

```powershell
Server {
    listen *:8080 http

    route get '/info' {
        xml @{ 'cpu' = 80; 'memory' = 15; }
    }
}
```

### Example 2

The following example will write raw XML data to a web response within a `route`:

```powershell
Server {
    listen *:8080 http

    route get '/info' {
        xml '<root><users><user>Rick</user><user>Morty</user></users></root>'
    }
}
```

### Example 3

The following example will read in a file, and write the contents as XML to a web response within a `route`:

```powershell
Server {
    listen *:8080 http

    route get '/data' {
        xml -file './files/data.xml'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Value | hashtable/string | true | The value should either be a `hashtable` or string - the string can be either a path or raw XML. It will be converted to XML, if not raw, and attached to the web response | null |
| File | switch | false | If passed, the above value should be a string that's a path to an XML file | false |
