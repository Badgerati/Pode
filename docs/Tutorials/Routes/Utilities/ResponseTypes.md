# Response Types

In a Route, you can write back various response types to the user, such as:

* JSON
* XML
* File Attachment
* Text
* etc.

The following sections detail what these response types are, and the functions you can use to send them.

!!! important
    You can only use **one** response function in a Route to send back data.

    You can have multiple, for example, `Write-PodeJsonResponse` lines in a Route, but they must be separated by `if/else`, `switch`, etc. statements. Only one of them can be invoked to send back a response.

## Attachment

You can use the [`Set-PodeResponseAttachment`](../../../../Functions/Responses/Set-PodeResponseAttachment) function to attach a file onto the response, this file can then be downloaded by the user.

The supplied path can be a path to a file in one of the following, and will be checked in the following order as well:

1. A static route folder, created via [`Add-PodeStaticRoute`](../../../../Functions/Routes/Add-PodeStaticRoute).
2. Your `/public` folder, at the root of your server.
3. A literal or relative path to a file on your file system.

A content-type for the file can optional be supplied, but if omitted Pode will auto-generate a content-type based on the file's extension.

```powershell
# The following will attach a file from the `/public` folder
Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
    Set-PodeResponseAttachment -Path 'Data.txt' -ContentType 'application/json'
}

# The following will attach a file from an `/assets` static route
Add-PodeStaticRoute -Path '/assets' -Source './assets'
Add-PodeRoute -Method Get -Path '/download' -ScriptBlock {
    Set-PodeResponseAttachment -Path '/assets/images/Fry.png'
}

# The following will attach a file via literal path
Set-PodeResponseAttachment -Path 'C:/Content/Accounts.xlsx'
```

## CSV

You can use the [`Write-PodeCsvResponse`](../../../../Functions/Responses/Write-PodeCsvResponse) function to write CSV data back to the user. Either a string or hashtable/psobject value can be supplied, or the literal path to a CSV file - the contents of the file will be written back, the file won't be attached.

```powershell
# convert a hashtable to CSV, and write back
Write-PodeCsvResponse -Value @{ Name = 'John' }

# write a raw CSV string
Write-PodeCsvResponse -Value "Name`nJohn"

# write the contents of a CSV file
Write-PodeCsvResponse -Path 'C:\Files\Names.csv'
```

## Directory

You can write a file explorer view, showing the contents of a directory, back to the user using [`Write-PodeDirectoryResponse`](../../../../Functions/Responses/Write-PodeDirectoryResponse).

```powershell
# render a file explore view of a directory
Write-PodeDirectoryResponse -Path 'C:/Some/Folder'
```

## File

You can write the contents of a static, or dynamic, file back to the user using [`Write-PodeFileResponse`](../../../../Functions/Responses/Write-PodeFileResponse). The path should be a literal path to a file on the file system, and you can optionally supply a content-type for the file - if not supplied, Pode will attempt to auto-generate the content-type based on the file's extension.

You can also optionally tell browsers to cache the contents locally.

```powershell
# write the contents of a file
Write-PodeFileResponse -Path 'C:/Files/Stuff.txt'

# write the contents of a file, and tell the browser to cache
Write-PodeFileResponse -Path 'C:/Files/Stuff.txt' -Cache -MaxAge 1800

# generate the contents of a dynamic file, and write the contents back
Write-PodeFileResponse -Path 'C:/Views/Index.pode' -Data @{ Counter = 2 }
```

## HTML

You can use the [`Write-PodeHtmlResponse`](../../../../Functions/Responses/Write-PodeHtmlResponse) function to write HTML data back to the user. Either a string or hashtable/psobject value can be supplied, or the literal path to an HTML file - the contents of the file will be written back, the file won't be attached.

```powershell
# convert a hashtable to HTML, and write back
Write-PodeHtmlResponse -Value @{ Message = 'Hello, world!' }

# write a raw HTML string
Write-PodeHtmlResponse -Value "<html><body><p>Hello, world!</p></body></html>"

# write the contents of a HTML file
Write-PodeHtmlResponse -Path 'C:\Website\index.html'
```

## JSON

You can use the [`Write-PodeJsonResponse`](../../../../Functions/Responses/Write-PodeJsonResponse) function to write JSON data back to the user. Either a string or hashtable/psobject value can be supplied, or the literal path to a JSON file - the contents of the file will be written back, the file won't be attached.

If you supply a hashtable/psobject value, you can also optionally supply a `-Depth` value to help the `ConvertTo-Json` function convert large objects.

```powershell
# convert a hashtable to JSON, and write back
Write-PodeJsonResponse -Value @{ Name = 'John' }

# write a raw JSON string
Write-PodeJsonResponse -Value '{"name": "John"}'

# write the contents of a JSON file
Write-PodeJsonResponse -Path 'C:\Files\Names.json'
```

## Markdown

You can use the [`Write-PodeMarkdownResponse`](../../../../Functions/Responses/Write-PodeMarkdownResponse) function to write Markdown data back to the user. Only a string value can be supplied, or the literal path to an Markdown file - the contents of the file will be written back, the file won't be attached.

You can optionally have the markdown contents converted to HTML, using the `-AsHtml` switch.

```powershell
# write a raw Markdown string
Write-PodeMarkdownResponse -Value '# Hello, world!'

# write the contents of a Markdown file, and convert to HTML
Write-PodeMarkdownResponse -Path 'C:\Website\index.md' -AsHtml
```

## Text

You can write any general string, or `byte[]`, back to the user using [`Write-PodeTextResponse`](../../../../Functions/Responses/Write-PodeTextResponse). A content-type for the data is needed, but if not supplied then `text/plain` will be used. You can also supply cache configuration for browsers.

```powershell
# write back a general string
Write-PodeTextResponse -Value 'Some random generic data'

# write back a JSON string
Write-PodeTextResponse -Value '{"name": "John"}' -ContentType 'application/json'

# write back some byte data of an image, from loading a file, and cache on the browser
Write-PodeTextResponse -Bytes (Get-Content -Path './some/image.png' -Raw -AsByteStream) -Cache -MaxAge 1800

# write back some data, and set the status code
Write-PodeTextResponse -Value "I'm a Teapot!" -StatusCode 418
```

## View

You can render a file from your `/views` folder using [`Write-PodeViewResponse`](../../../../Functions/Responses/Write-PodeViewResponse). You can render a static (.html), or dynamic (.pode) view file. The supplied `-Path` should be the name of the file, with extension omitted.

!!! note
    More on views can be [found here](../../../Views/Pode).

```powershell
# write an index view file
Write-PodeViewResponse -Path 'index'

# write a dynamic profile page, with passed data
Write-PodeViewResponse -Path 'accounts/profile' -Data @{ Username = 'John' }
```

## XML

You can use the [`Write-PodeXmlResponse`](../../../../Functions/Responses/Write-PodeXmlResponse) function to write XML data back to the user. Either a string or hashtable/psobject value can be supplied, or the literal path to a XML file - the contents of the file will be written back, the file won't be attached.

If you supply a hashtable/psobject value, you can also optionally supply a `-Depth` value to help the `ConvertTo-Xml` function convert large objects.

```powershell
# convert a hashtable to XML, and write back
Write-PodeXmlResponse -Value @{ Name = 'John' }

# write a raw XML string
Write-PodeXmlResponse -Value '<root><name>John</name></root>'

# write the contents of a XML file
Write-PodeXmlResponse -Path 'C:\Files\Names.xml'
```

## YAML

You can use the [`Write-PodeYamlResponse`](../../../../Functions/Responses/Write-PodeYamlResponse) function to write YAML data back to the user. Either a string or hashtable/psobject value can be supplied, or the literal path to a YAML file - the contents of the file will be written back, the file won't be attached.

If you supply a hashtable/psobject value, you can also optionally supply a `-Depth` value to help the `ConvertTo-PodeYaml` function convert large objects.

```powershell
# convert a hashtable to YAML, and write back
Write-PodeYamlResponse -Value @{ Name = 'John' }

# write a raw YAML string
Write-PodeYamlResponse -Value 'name: "Rick"'

# write the contents of a YAML file
Write-PodeYamlResponse -Path 'C:\Files\Names.yaml'
```
