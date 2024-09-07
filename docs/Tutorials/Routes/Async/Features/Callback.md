
# Callback

The `Set-PodeAsyncRoute` function supports including callback functionality for routes. This allows you to define a URL that will be called when the asynchronous task is completed. You can specify the callback URL, content type, HTTP method, and header fields.

#### Callback Parameters

- **Callback URL**: Specifies the URL field for the callback. Default is `'$request.body#/callbackUrl'`.
  - Can accept the following meta values:
    - `$request.query.param-name`: query-param-value
    - `$request.header.header-name`: application/json
    - `$request.body#/field-name`: callbackUrl
    - Can accept runtime expressions based on the [OpenAPI specification](https://swagger.io/docs/specification/callbacks/).
  - Acceptable static values (examples):
    - 'http://example.com/callback'
    - 'https://api.example.com/callback'

- **Callback Content Type**: Specifies the content type for the callback. The default is `'application/json'`.
  - Can accept the following meta values:
    - `$request.query.param-name`: query-param-value
    - `$request.header.header-name`: application/json
    - `$request.body#/field-name`: callbackUrl
    - Can accept runtime expressions based on the [OpenAPI specification](https://swagger.io/docs/specification/callbacks/).
  - Acceptable static values (examples):
    - 'application/json'
    - 'application/xml'
    - 'text/plain'

- **Callback Method**: Specifies the HTTP method for the callback. The default is `'Post'`.
  - Can accept the following meta values:
    - `$request.query.param-name`: query-param-value
    - `$request.header.header-name`: application/json
    - `$request.body#/field-name`: callbackUrl
    - Can accept runtime expressions based on the [OpenAPI specification](https://swagger.io/docs/specification/callbacks/).
  - Acceptable static values (examples):
    - `GET`
    - `POST`
    - `PUT`
    - `DELETE`

- **Callback Header Fields**: Specifies the header fields for the callback as a hashtable. The key can be a string representing the header key or one of the meta values. The value is the header value if it's a standard key or the default value if the meta value is not resolvable.
  - Can accept the following meta values as keys:
    - `$request.query.param-name`: query-param-value
    - `$request.header.header-name`: application/json
    - `$request.body#/field-name`: callbackUrl
    - Can accept runtime expressions based on the [OpenAPI specification](https://swagger.io/docs/specification/callbacks/).
  - Acceptable static values (examples):
    - `@{ 'Content-Type' = 'application/json' }`
    - `@{ 'Authorization' = 'Bearer token' }`
    - `@{ 'Custom-Header' = 'value' }`

- **Send Result**: If specified, sends the result of the callback.
  - Type Boolean.

- **Event Name**: Specifies the event name for the callback.
  - Type String.


#### Example Usage

```powershell
Add-PodeRoute -PassThru -Method Post -Path '/asyncWithCallback' -ScriptBlock {
    return @{ Message = "Async Route with Callback" }
} | Set-PodeAsyncRoute `
    -ResponseContentType 'application/json', 'application/yaml' `
    -Callback `
    -CallbackUrl 'http://example.com/callbacks/{$request.body#/callbackPath}' `
    -CallbackContentType 'application/json' `
    -CallbackMethod '$request.body#/callbackMethod' `
    -CallbackHeaderFields @{ 'Custom-Header' = '$request.header.CustomHeader' } `
    -CallbackSendResult `
    -EventName 'AsyncCompleted'
```

#### Explanation

1. **Route Definition**: The `Add-PodeRoute` defines a route at `/asyncWithCallback` that processes a request and returns a message indicating it's an async route with a callback.

2. **Setting Async Route with Callback**: The `Set-PodeAsyncRoute` processes the route to make it asynchronous and sets up the callback.
    - `-ResponseContentType` specifies the response formats as JSON and YAML.
    - `-Callback` enables the callback functionality.
    - `-CallbackUrl` sets the URL that will be called when the async route task is completed, using a runtime expression based on the request body.
    - `-CallbackContentType` specifies the content type for the callback request.
    - `-CallbackMethod` sets the HTTP method for the callback request, using a runtime expression based on the request body.
    - `-CallbackHeaderFields` includes custom header fields in the callback request, using a runtime expression based on the request headers.
    - `-CallbackSendResult` ensures that the result of the async route task is sent in the callback request.
    - `-EventName` specifies the event name for the callback.

This setup ensures that when the asynchronous task completes, a request will be made to the specified callback URL with the defined settings, including the result of the async route task, using runtime expressions to dynamically set the callback parameters.