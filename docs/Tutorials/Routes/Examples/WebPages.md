# Creating a Web Page

Serving up web pages via Pode is simple, you can either write your pages in HTML, Pode, another template engine; then place those files within the `/views` directory. You can also use CSS, JavaScript, Images, etc. and place those files within the `/public` directory.

## Basics

To serve up a web page you use the  [`Write-PodeViewResponse`](../../../../Functions/Responses/Write-PodeViewResponse) function, and if you're using a dynamic template (like [`.pode`](../../../Views/Pode) files) to render your views use the  [`Write-PodeViewResponse`](../../../../Functions/Responses/Write-PodeViewResponse) function.

When you use the  [`Write-PodeViewResponse`](../../../../Functions/Responses/Write-PodeViewResponse) function to serve a web page, the path to the view must be relative to the `/views` directory. For example, the following will display the `/views/index.html` page:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }
}
```

!!! info
    If your web page references any CSS, JavaScript, etc. files, then Pode will automatically find them within the `/public` directory - or any relative static routes you may have defined. For example, if you reference `<link rel="stylesheet" type="text/css" href="/styles/simple.css">` in your HTML file, then Pode will look for `/public/styles/simple.css`.

## Full Example

Here we'll have two simple HTML pages, with a CSS file and a simple server script. The directory structure is as follows:

```plain
server.ps1
/views
    index.html
    about.html
/public
    /stylyes
        main.css
```

*server.ps1*
```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address *:8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'index'
    }

    Add-PodeRoute -Method Get -Path '/about' -ScriptBlock {
        Write-PodeViewResponse -Path 'about'
    }
}
```

*index.html*
```html
<html>
    <head>
        <title>Home Page</title>
        <link rel="stylesheet" type="text/css" href="/styles/main.css">
    </head>
    <body>
        <h1>Hello, world!</h1>
        <p>Welcome to my very simple home page!</p>
        <p>To know more about me, <a href="/about">click here</a>!</p>
    </body>
</html>
```

*about.html*
```html
<html>
    <head>
        <title>About Me</title>
        <link rel="stylesheet" type="text/css" href="/styles/main.css">
    </head>
    <body>
        <h1>About Me</h1>
        <p>My name is Rick Sanchez</p>
        <p>Wubba lubba dub dub!!</p>
        <p>To go back home, <a href="/">click here</a>.</p>
    </body>
</html>
```

*styles/main.css*
```css
body {
    background-color: rebeccapurple;
}
```
