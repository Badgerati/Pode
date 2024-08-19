
# OpenAPI Integration with Async Routes

Async routes defined using the `Set-PodeAsyncRoute` function can seamlessly integrate with OpenAPI documentation. This feature automatically generates detailed documentation, including response types and callback information, enhancing the ease of sharing and maintaining your API specifications.

## Key Features

### Automatic Documentation Generation

When an async route is configured using `Set-PodeAsyncRoute`, the corresponding OpenAPI documentation is automatically generated. This documentation includes:
- **Route Details**: Information about the HTTP method, path, and operation summary.
- **Response Types**: Details of the possible response content types (`application/json`, `application/yaml`, etc.) and their associated schemas.
- **Callback Details**: If the route includes callbacks, these are also documented in the OpenAPI definition.

### Customization Options

You can tailor the generated OpenAPI documentation to fit your specific needs:
- **OpenApi Schemas**: Customize the schema name for the async route task using the `OATypeName` parameter, or other relevant parameters like `$TaskIdName`, `$QueryRequestName`, and `$QueryParameterName` using `Set-PodeAsyncRouteOASchemaName`.
- **Route Information**: Further customize the OpenAPI route definition using Pode’s OpenAPI functions, such as `Set-PodeOARouteInfo` and any othe OpenApi functions available for route definition.

### Piping for Documentation

To generate OpenAPI documentation for an async route, you must pipe the route definition through `Set-PodeOARouteInfo`, as shown in the example below. This requirement also applies to the following async routes:
- `Add-PodeAsyncRouteQuery`
- `Add-PodeAsyncRouteStop`
- `Add-PodeAsyncRouteGet`

## Example Usage

The following example demonstrates how to define an async route and customize its OpenAPI documentation:

```powershell
# Set a custom schema name for the async route task
Set-PodeAsyncRouteOASchemaName -OATypeName 'MyTask'

# Define an async route and customize its OpenAPI information
Add-PodeRoute -PassThru -Method Post -Path '/asyncExample' -ScriptBlock {
    return @{ Message = "Async Route" }
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -PassThru |
    Set-PodeOARouteInfo -Summary 'My Async Route Task' -Description 'This is a description'
```

### Resulting OpenAPI Documentation

The generated OpenAPI documentation might look as follows:

```yaml
/asyncExample:
  post:
    summary: My Async Route Task
    description: This is a description
    responses:
      200:
        description: Successful operation
        content:
          application/yaml:
            schema:
              $ref: '#/components/schemas/MyTask'
          application/json:
            schema:
              $ref: '#/components/schemas/MyTask'

components:
  schemas:
    MyTask:
      type: object
      properties:
        User:
          type: string
          description: The async operation owner.
        CompletedTime:
          type: string
          description: The async operation completion time.
          example: 2024-07-02T20:59:23.2174712Z
          format: date-time
        State:
          type: string
          description: The async operation status.
          example: Running
          enum:
            - NotStarted
            - Running
            - Failed
            - Completed
        Result:
          type: object
          description: The result of the async operation.
          properties:
            InnerValue:
              type: string
              description: The inner value returned by the operation.
```

**Note**: The `MyTask` schema definition provided above is a partial example. You can expand this definition with additional properties according to your specific use case.
