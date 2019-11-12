# Pode Files

Pode has an inbuilt dynamic file type of `.pode`, which allow you to write normal file but use PowerShell within them.

For `view` files the naming convention is just `index.pode` or `about.pode`. However for non-view files in the `/public` directory the convention is `style.css.pode` - which includes the files base file type.

## Views

Using Pode to render dynamic `view` files is mostly just using normal HTML, but with the insertion of PowerShell - in fact, you could write pure HTML in a `.pode` file and it will still work. The difference is that you're able to embed PowerShell logic into the file, which allows you to dynamically generate HTML.

To use `.pode` files for views, you will need to place them within the `/views` directory; then you'll need to set the View Engine to be Pode. Once set, you can just write view responses as per normal:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # set the engine to use and render Pode files
    Set-PodeViewEngine -Type Pode

    # render the index.pode in the /views directory
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }
}
```

!!! info
    Any PowerShell in a `.pode` files will need to be wrapped in `$(...)` and each line must end with a semi-colon.

Below is a basic example of a `.pode` view file, which just writes the current date to the browser:

```html
<!-- /views/index.pode -->
<html>
    <head>
        <title>Current Date</title>
    </head>
    <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>
```

Any data supplied to the `view` function when rendering `.pode` files will make them far more dynamic. The data supplied to `view` must be a `hashtable`, and can be referenced from within the file by using the `$data` argument.

For example, say you need to render a search page which is a list of accounts filtered by some query; then your basic server script could look like the following:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # set the engine to use and render .pode files
    Set-PodeViewEngine -Type Pode

    # render the search.pode view
    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        param($event)

        # some logic to get accounts
        $query = $event.Query['query']
        $accounts = Find-Account -Query $query

        # render the file
        Write-PodeViewResponse -Path 'search' -Data @{ 'query' = $query; 'accounts' = $accounts; }
    }
}
```

You can see that we're supplying the found accounts to the `view` function as a `hashtable`. Next, we see the `search.pode` view file which generates the HTML:

```html
<!-- /views/search.pode -->
<html>
    <head>
        <title>Search</title>
    </head>
    <body>
        <h1>Search</h1>
        Query: $($data.query;)

        <div>
            $(foreach ($account in $data.accounts) {
                "<div>Name: $($account.Name)</div><hr/>";
            })
        </div>
    </body>
</html>
```

> Remember, you can access supplied data by using `$data`

This next quick example allows you to include content from another view:

```html
<!-- /views/index.pode -->
<html>
    $(Use-PodePartialView -Path 'shared/head' -data @{ 'Title' = 'Include Example'})

    <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>

<!-- /views/shared/head.pode -->
<head>
    <title>$($data.Title)</title>
</head>
```

## Non-Views

The rules for using `.pode` files for other non-view file types, like css/js files, work exactly like the above view files but they're placed within the `/public` directory instead of the `/views` directory. You also need to specify the actual file type in the extension, for example:

```plain
/public/styles/main.css.pode
/public/scripts/main.js.pode
```

Here you'll see the main extension is `.pode`, but you need to specify a sub-extension of the main file type such as `.css` - this helps Pode work out the main content type when writing to the response.

Below is a `.css.pode` file that will render the page in purple on even seconds, or red on odd seconds:

```css
/* /public/styles/main.css.pode */
body {
    $(
        $date = [DateTime]::UtcNow;

        if ($date.Second % 2 -eq 0) {
            "background-color: rebeccapurple;";
        } else {
            "background-color: red;";
        }
    )
}
```

To load the above `.css.pode` file in a view file:

```html
<!-- /views/index.pode -->
<html>
   <head>
      <link rel="stylesheet" href="/styles/main.css.pode">
   </head>
   <body>
        <span>$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss');)</span>
    </body>
</html>
```
