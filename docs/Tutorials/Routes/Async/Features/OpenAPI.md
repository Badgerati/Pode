
# OpenAPI

Routes defined with `Set-PodeAsyncRoute` can automatically generate OpenAPI documentation. This includes response types and callback details, making it easier to document and share your API.

- **Automatic Documentation**: When an async route is defined, OpenAPI documentation is automatically generated. This includes the details of the route, the response types, and any callback functionality.
- **Customization**: You can customize the OpenAPI documentation details, such as the type name for the task, using the `OATypeName` parameter. The route OpenAPI definition can also be customized using the usual Pode OpenAPI functions.

```powershell
Add-PodeRoute -PassThru -Method Post -Path '/asyncExample' -ScriptBlock {
    return @{ Message = "Async Route" }
} | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -OATypeName 'ExampleTask'
```

**OpenAPI Result:**
```yaml
/asyncExample:
    post:
      responses:
        200:
          description: Successful operation
          content:
            application/yaml:
              schema:
                $ref: '#/components/schemas/ExampleTask'
            application/json:
              schema:
                $ref: '#/components/schemas/ExampleTask'

components:
  schemas:
    ExampleTask:
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
          description: The async operation status
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
**Note**: The `ExampleTask` definition above is partial. The full definition can include more properties as required by your specific use case.

