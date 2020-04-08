# Static Content

Static content in Pode can be used by either placing your static files within the `/public` directory, or by defining custom static routes. You can also specify default pages, such as `index.html`, for when users navigate to root folders.

Caching is supported on static content.

## Static Routes

The following is an example of using the [`Add-PodeStaticRoute`](../../../../Functions/Routes/Add-PodeStaticRoute) function to define a route to some static content directory; this tells Pode where to get static files from for certain routes. This example will define a static route for `/assets`, and will point the route at the internal directory path of `./content/assets`:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
    Add-PodeStaticRoute -Path '/assets' -Source './content/assets'
}
```

The following request will retrieve an image from the `./content/assets/images` directory:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/assets/images/icon.png' -Method Get
```

## Middleware

Anything placed within your server's `/public` directory will always be public static content. However, if you define custom static routes via [`Add-PodeStaticRoute`](../../../../Functions/Routes/Add-PodeStaticRoute), then you can also supply middleware - including authentication.

Custom static routes follow a similar flow to normal routes, and any query string; payloads; cookies; etc, will all be parsed - allowing you to run any route specific middleware before the static content is actually returned.

Middleware works the same as on normal Routes, so there's nothing extra you need to do. Any global middleware that you've defined will also work on static routes as well.

## Default Pages

For static content, Pode also supports returning default pages when a root static content directory is requested. The inbuilt default pages are:

```plain
index.html
index.htm
default.html
default.htm
```

These pages are checked in order, and if one is found then its content is returned. Using the above static route, if the `./content/assets/home` directory contained an `index.html` page, then the following request would return the content for the `index.html` page:

```powershell
Invoke-WebRequest -Uri 'http://localhost:8080/assets/images/home' -Method Get
```

The default pages can be configured in two ways; either by using the `-Defaults` parameter on the [`Add-PodeStaticRoute`](../../../../Functions/Routes/Add-PodeStaticRoute) function, or by setting them in the `server.psd1` [configuration file](../../../Configuration). To set the defaults to be only a `home.html` page, both ways would work as follows:

*Defaults Parameter*
```powershell
Add-PodeStaticRoute -Path '/assets' -Source './content/assets' -Defaults @('index.html')
```

*Configuration File*
```powershell
@{
    Web = @{
        Static = @{
            Defaults = @('home.html')
        }
    }
}
```

The only difference being, if you have multiple static routes, setting any default pages in the `server.psd1` file will apply to *all* static routes. Any default pages set using the `-Default` parameter will have a higher precedence than the `server.psd1` file.

## Caching

Having web pages send requests to your Pode server for all static content every time can be quite a strain on the server. To help the server, you can enable static content caching, which will inform users' browsers to cache files (ie `*.css` and `*.js`) for so many seconds - stopping the browser from re-requesting it from your server each time.

By default, caching is disabled and can be enabled and controlled using the `server.psd1` configuration file.

To enable caching, with a default cache time of 1hr, you do:

```powershell
@{
    Web = @{
        Static = @{
            Cache = @{
                Enable = $true
            }
        }
    }
}
```

If you wish to set a max cache time of 30mins, then you would use the `MaxAge` property - setting it to `1800secs`:

```powershell
@{
    Web = @{
        Static = @{
            Cache = @{
                Enable = $true
                MaxAge = 1800
            }
        }
    }
}
```

### Include/Exclude

Sometimes you don't want all static content to be cached, maybe you want `*.exe` files to always be re-requested? This is possible using the `Include` and `Exclude` properties in the `server.psd1`.

Let's say you do want to exclude all `*.exe` files from being cached:

```powershell
@{
    Web = @{
        Static = @{
            Cache = @{
                Enable = $true
                Exclude = @(
                    "*.exe"
                )
            }
        }
    }
}
```

Or, you could setup some static routes called `/assets` and `/images`, and you want everything on `/images` to be cached, but only `*.js` files to be cached on `/assets`:

```powershell
@{
    Web = @{
        Static = @{
            Cache = @{
                Enable = $true
                Include = @(
                    "/images/*",
                    "/assets/*.js"
                )
            }
        }
    }
}
```

## Downloadable

Normally content accessed on a static route is rendered on the browser, but you can set the route to flag the files for downloading instead. If you set the `-DownloadOnly` switch on the  [Add-PodeStaticRoute`](../../../../Functions/Routes/Add-PodeStaticRoute) function, then accessing files on this route in a browser will cause them to be downloaded instead of rendered:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http
    Add-PodeStaticRoute -Path '/assets' -Source './content/assets' -DownloadOnly
}
```

When a static route is set as downloadable, then `-Defaults` and caching are not used.
