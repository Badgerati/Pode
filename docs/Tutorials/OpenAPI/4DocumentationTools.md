
# Documentation Tools

If you're not using a custom OpenAPI viewer, then you can use one or more of the inbuilt which Pode supports: ones with Pode:

* Swagger
* ReDoc
* RapiDoc
* StopLight
* Explorer
* RapiPdf

For each you can customise the Route path to access the page on, but by default Swagger is at `/swagger`, ReDoc is at `/redoc`, etc. If you've written your own custom OpenAPI definition then you can also set a custom Route path to fetch the definition on.

To enable a viewer you can use the [`Enable-PodeOAViewer`](../../../Functions/OpenApi/Enable-PodeOAViewer) function:

```powershell
# for swagger at "/docs/swagger"
Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger' -DarkMode

# and ReDoc at the default "/redoc"
Enable-PodeOAViewer -Type ReDoc -Path '/docs/redoc'

# and RapiDoc at "/docs/rapidoc"
Enable-PodeOAViewer -Type RapiDoc -Path '/docs/rapidoc'

# and StopLight at "/docs/stoplight"
Enable-PodeOAViewer -Type StopLight -Path '/docs/stoplight'

# and Explorer at "/docs/explorer"
Enable-PodeOAViewer -Type Explorer -Path '/docs/explorer'

# and RapiPdf at "/docs/rapipdf"
Enable-PodeOAViewer -Type RapiPdf -Path '/docs/rapipdf'

# plus a bookmark page with the link to all documentation
Enable-PodeOAViewer -Bookmarks -Path '/docs'

# there is also an OpenAPI editor (only for v3.0.x)
Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
```
