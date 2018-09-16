# Status

## Description

The `status` function allows you to specify a specific status code, and optional a status description.

## Examples

1. The following example sets the status code of the response to be 404:

    ```powershell
    Server {
        listen *:8080 http

        route get '/missing' {
            status 404
        }
    }
    ```

2. The following example sets the status code and description of the response to be 500:

    ```powershell
    Server {
        listen *:8080 http

        route get '/error' {
            status 500 'Oh no! Something went wrong!'
        }
    }
    ```

## Parameters

| Name | Type | Required | Description | Default |
| ---- | ---- | -------- | ----------- | ------- |
| Code | int | true | The status code to set on the web response | 0 |
| Description | string | false | The status description to set on the response | empty |
