# Content Types

Any payload supplied in a web request is normally parsed using the content type on the request's headers. However, it's possible to override - or *force* - a specific content type on routes when parsing the payload. This can be achieved by either using the `-ContentType` parameter on the [`route`](../../../Functions/Core/Route) function, or using the [`pode.json`](../../Configuration) configuration file.

When a specific content type is supplied then any payload will be parsed as that content type only - even if the content type is supplied on the web request's header. This way, you can force a route to only accept a certain content type.

## Routes

You can specify a content type to use per route by using the `-ContentType` parameter.

For example, if you have two routes you can force one to only parse JSON and the other XML as follows:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Endpoint *:8080 -Protocol HTTP

    route get '/api/json' -ctype 'application/json' {
        Write-PodeJsonResponse -Value @{}
    }

    route get '/api/xml' -ctype 'text/xml' {
        Write-PodeXmlResponse -Value @{}
    }
}
```

If the `/api/json` endpoint is supplied an XML payload then the parsing will fail.

## Configuration

Using the `pode.json` configuration file, you can define a default content type to use for every route, or you can define patterns to match multiple route paths to set content types on mass.

### Default

To define a default content type for everything, you can use the following configuration:

```json
{
    "web": {
        "contentType": {
            "default": "text/plain"
        }
    }
}
```

### Route Patterns

You can define patterns to match multiple route paths, and any route that matches (when created) will have the appropriate content type set.

For example, the following configuration in your `pode.json` would bind all `/api` routes to `application/json`, and then all `/status` routes to `text/xml`:

```json
{
    "web": {
        "contentType": {
            "routes": {
                "/api/*": "application/json",
                "/status/*": "text/xml"
            }
        }
    }
}
```

## Precedence

The content type that will be used is determined by the following order:

1. Being defined on the `route` function.
2. The route matches a pattern defined in the configuration file.
3. A default content type is defined in the configuration file.
4. The content type supplied on the web request.