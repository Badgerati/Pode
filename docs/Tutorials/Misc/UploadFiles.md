# Uploading Files

Pode's inbuilt middleware supports parsing a request's body/payload and query string, and this also extends to uploading files via a `<form>`. Like how POST data can be accessed in a `route` via the passed web event as `$e.Data[<name>]`, uploaded files can be accessed via `$e.Files[<filename>]`.

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

The inputs will be POSTed to the server, and accessible via the web event's `.Data` and `.Files`.

For the `.Data`:
```powershell
$e.Data['username']     # the username entered
$e.Data['password']     # the password entered
$e.Data['avatar']       # the name of the file (assume image.png)
```

For the `.Files`:
```powershell
$e.Files['image.png']   # the bytes of the uploaded file
```

## Script

### Inbuilt Save

The following script is an example Pode server script that will save the uploaded file, from the above `<form>`:

```powershell
Server {

    # listen on localhost:8085
    listen *:8085 http
    engine html

    # GET request for web page on "localhost:8085/"
    route get '/' {
        view 'sign-up'
    }

    # POST request to save the avatar and create user
    route post '/sign-up' {
        param($e)

        # do some logic here to create user
        New-User -Username $e.Data['username'] -Password $e.Data['password']

        # upload the avatar - this will retrieve the filename from $e.Data,
        # and the bytes from $e.Files, saving to the server's root path
        save 'avatar'
    }

}
```

### Custom Save

If you need to save the uploaded file elsewhere, then you can retrieve the raw bytes of the avatar file as follows:

```powershell
route post '/upload' {
    param($e)

    # using .Data will get you the file's name
    $filename = $e.Data['avatar']

    # with the filename, you can get the file's bytes from .File
    # as well as the Bytes, you can also get the ContentType
    $bytes = $e.Files[$filename].Bytes

    # with the bytes, you can upload the file where ever you want
}
```
