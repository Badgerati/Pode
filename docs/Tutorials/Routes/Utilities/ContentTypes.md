# Content Types

Any payload supplied in a web request is normally parsed using the content type on the request's headers. However, it's possible to override - or *force* - a specific content type on routes when parsing the payload. This can be achieved by either using the `-ContentType` parameter on the [`Add-PodeRoute`](../../../../Functions/Routes/Add-PodeRoute) function, or using the [`server.psd1`](../../Configuration) configuration file.

When a specific content type is supplied then any payload will be parsed as that content type only - even if the content type is supplied on the web request's header. This way, you can force a route to only accept a certain content type.

## Routes

You can specify a content type to use per route by using the `-ContentType` parameter.

For example, if you have two routes you can force one to only parse JSON and the other XML as follows:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    Add-PodeRoute -Method Get -Path '/api/json' -ContentType 'application/json' -ScriptBlock {
        Write-PodeJsonResponse -Value @{}
    }

    Add-PodeRoute -Method Get -Path '/api/xml' -ContentType 'text/xml' -ScriptBlock {
        Write-PodeXmlResponse -Value @{}
    }
}
```

If the `/api/json` endpoint is supplied an XML payload then the parsing will fail.

## Configuration

Using the `server.psd1` configuration file, you can define a default content type to use for every route, or you can define patterns to match multiple route paths to set content types on mass.

### Default

To define a default content type for everything, you can use the following configuration:

```powershell
@{
    Web = @{
        ContentType = @{
            Default = "text/plain"
        }
    }
}
```

### Route Patterns

You can define patterns to match multiple route paths, and any route that matches (when created) will have the appropriate content type set.

For example, the following configuration in your `server.psd1` would bind all `/api` routes to `application/json`, and then all `/status` routes to `text/xml`:

```powershell
@{
    Web = @{
        ContentType = @{
            Routes = @{
                "/api/*" = "application/json"
                "/status/*" = "text/xml"
            }
        }
    }
}
```

## Precedence

The content type that will be used is determined by the following order:

1. Being defined on the Route.
2. The Route matches a pattern defined in the configuration file.
3. A default content type is defined in the configuration file.
4. The content type supplied on the web request.
