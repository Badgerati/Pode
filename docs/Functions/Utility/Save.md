# Save

## Description

The `save` function allows you to save a file to a specified path. You can use the function in conjunction with uploaded files, meaning you can save them to the file-system (ie: users uploading profile pictures in a `<form>`)

The `Name` supplied is used to retrieve the file's contents from the current web event's `.Files` array. This `Name` should be the name of the `<form>` element.

!!! note
    If the path supplied to save the file is a directory, then the file is saved using the file's original upload name. If path supplied also contains a filename, such as `./image.png`, then this name is used instead.

## Examples

### Example 1

The following example saves an uploaded image from a `<form>`, called "`prof-pic`", to the server's root path:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route post '/signup' {
        save 'prof-pic'
    }
}
```

### Example 2

The following example saves an uploaded image from a `<form>`, called "`prof-pic`", to a custom path:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol HTTP

    route post '/signup' {
        save 'prof-pic' 'e:/profiles/pictures'
    }
}
```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Name | string | true | The name of the `<form>` element so the function can self-retrieve the file's contents | null |
| Path | string | false | The path to save the file | Server Root |
