# Uploading Files

Pode's inbuilt middleware supports parsing a request's body/payload and query string, and this also extends to uploading files via a `<form>`. Like how POST data can be accessed in a Route via the [web event](../../WebEvent) as `$WebEvent.Data[<name>]`, uploaded files can be accessed via `$WebEvent.Files[<filename>]`.

!!! important
    In order for uploaded files to work, your `<form>` must contain `enctype="multipart/form-data"`

## Web Form

The following HTML is an example of a `<form>` for a simple sign-up flow. Here the form will POST the username, password, and an avatar (our file to upload).

```html
<html>
    <head>
        <title>Sign Up</title>
    </head>
    <body>
        <form action="/signup" method="post" enctype="multipart/form-data">
            <div>
                <label>Username:</label>
                <input type="text" name="username" />
            </div>
            <div>
                <label>Password:</label>
                <input type="password" name="password" />
            </div>
            <div>
                <label>Avatar:</label>
                <input type="file" name="avatar" />
            </div>
            <div>
                <input type="submit" value="Submit" />
            </div>
        </form>
    </body>
</html>
```

> You can upload multiple files from one `<form>`

The inputs will be POSTed to the server, and accessible via the [web event](../../WebEvent)'s `.Data` and `.Files`.

For the `.Data`:
```powershell
$WebEvent.Data['username']     # the username entered
$WebEvent.Data['password']     # the password entered
$WebEvent.Data['avatar']       # the name of the file (assume image.png)
```

For the `.Files`:
```powershell
$WebEvent.Files['image.png']   # the bytes of the uploaded file
```

## Script

### Inbuilt Save

The following script is an example Pode server that will save the uploaded file, from the above `<form>`:

```powershell
Start-PodeServer {

    # listen on localhost:8085
    Add-PodeEndpoint -Address * -Port 8085 -Protocol Http
    Set-PodeViewEngine -Type HTML

    # GET request for web page on "localhost:8085/"
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'signup'
    }

    # POST request to save the avatar and create user
    Add-PodeRoute -Method Post -Path '/signup' -ScriptBlock {
        # do some logic here to create user
        New-User -Username $WebEvent.Data['username'] -Password $WebEvent.Data['password']

        # upload the avatar - this will retrieve the filename from $WebEvent.Data,
        # and the bytes from $WebEvent.Files, saving to the server's root path
        Save-PodeRequestFile -Key 'avatar'
    }

}
```

### Custom Save

If you need to save the uploaded file elsewhere, then you can retrieve the raw bytes of the avatar file as follows:

```powershell
Add-PodeRoute -Method Post -Path '/upload' -ScriptBlock {
    # using .Data will get you the file's name
    $filename = $WebEvent.Data['avatar']

    # with the filename, you can get the file's bytes from .File
    # as well as the Bytes, you can also get the ContentType
    $bytes = $WebEvent.Files[$filename].Bytes

    # with the bytes, you can upload the file where ever you want
}
```
