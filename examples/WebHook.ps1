<#
.SYNOPSIS
    A sample PowerShell script to set up a webhook server using Pode.

.DESCRIPTION
    This script sets up a webhook server using Pode. It includes endpoints for storing data,
    subscribing to webhook events, and unsubscribing from webhook events. It also defines
    an OpenAPI specification for the server and enables Swagger documentation.

.NOTES
    Author: Pode Team
    License: MIT License

#>

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# Define the server configuration
Start-PodeServer {
    # Listen on port 8080
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    # Initialize a hashtable to store subscriptions
    Set-PodeState -Name 'subscriptions' -Value @{} | Out-Null

    # Enable terminal logging for errors
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # Enable OpenAPI documentation
    Enable-PodeOpenApi -Path '/docs/openapi/v3.1' -OpenApiVersion '3.1.0' -DisableMinimalDefinitions -NoDefaultResponses -EnableSchemaValidation
    Add-PodeOAInfo -Title 'WebHook' -Version 1.0.0 -Description 'Webhook Sample' -LicenseName 'MIT License' -LicenseUrl 'https://github.com/Badgerati/Pode?tab=MIT-1-ov-file#readme'

    # Enable Swagger viewer for the OpenAPI documentation
    Enable-PodeOAViewer -Type Swagger -Path '/docs/v3.1/swagger'
    Enable-PodeOAViewer -Bookmarks -Path '/docs/v3.1'

    # Define OpenAPI components
    # Define WebhookPayload schema
    New-PodeOAStringProperty -Name 'key' -Description 'Index key' -Example 'cpu' -Required |
        New-PodeOAStringProperty -Name 'value' -Description 'Value' -Example 'arm' -Required |
        New-PodeOAObjectProperty -NoAdditionalProperties | Add-PodeOAComponentSchema -Name 'WebhookPayload'

    # Define WebhookUri schema
    New-PodeOAStringProperty -Name 'url' -Format Uri -Example 'http://example.com/webhook' | New-PodeOAObjectProperty | Add-PodeOAComponentSchema -Name 'WebhookUri'

    # Define responses
    Add-PodeOAComponentResponse -Name 'SucessfulResponse' -Description 'Successful operation' -ContentSchemas (@{'application/json' = (New-PodeOAStringProperty -Name 'message' -Example 'Operation completed successfully!' | New-PodeOAObjectProperty) })
    Add-PodeOAComponentResponse -Name 'FailureResponse' -Description 'Failed operation' -ContentSchemas (@{'application/json' = (New-PodeOAStringProperty -Name 'message' -Example 'Operation Failed!' | New-PodeOAObjectProperty) })

    # Route for subscribing to the webhook
    Add-PodeRoute -Method Post -Path '/subscribe' -ScriptBlock {
        $contentType = Get-PodeHeader -Name 'Content-Type'
        switch ($contentType) {
            'application/json' {
                $data = $WebEvent.data

                # Validate the incoming request against the WebhookUri schema
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $data -SchemaReference 'WebhookUri'
                if ($Validate.result) {
                    # Add the subscription (assuming 'url' is the endpoint to subscribe)
                    Lock-PodeObject -ScriptBlock {
                        if ($state:subscriptions.ContainsKey($data.url)) {
                            Write-PodeJsonResponse -Value @{ message = 'Subscription already exist.' } -StatusCode 400
                        }
                        else {
                            $state:subscriptions[$data.url] = $true
                            # Respond with a status message
                            Write-PodeJsonResponse -Value @{ message = 'Subscribed successfully!' }
                        }
                    }
                }
                else {
                    Write-PodeJsonResponse -StatusCode 400 -Value @{
                        message = $Validate.message -join ', '
                    }
                }
            }
            default {
                Write-PodeJsonResponse -Value @{ message = 'Invalid Content-Type' } -StatusCode 400
            }
        }
    } -PassThru | Set-PodeOARouteInfo -Summary 'Subscribe to webhook events' -OperationId 'subscribe' -Description 'Allows a client to subscribe to webhook events.' -PassThru |
        Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content @{ 'application/json' = 'WebhookUri' }) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'SucessfulResponse' -PassThru |
        Add-PodeOAResponse -StatusCode 400 -Reference 'FailureResponse'

    # Route for unsubscribing from the webhook
    Add-PodeRoute -Method Post -Path '/unsubscribe' -ScriptBlock {
        $contentType = Get-PodeHeader -Name 'Content-Type'
        switch ($contentType) {
            'application/json' {
                $data = $WebEvent.data

                # Validate the incoming request against the WebhookUri schema
                $Validate = Test-PodeOAJsonSchemaCompliance -Json $data -SchemaReference 'WebhookUri'
                if ($Validate.result) {
                    # Remove the subscription
                    Lock-PodeObject -ScriptBlock {
                        if ($state:subscriptions.ContainsKey($data.url)) {
                            $state:subscriptions.Remove($data.url)
                            # Respond with a status message
                            Write-PodeJsonResponse -Value @{ message = 'Unsubscribed successfully!' } -StatusCode 200
                        }
                        else {
                            Write-PodeJsonResponse -Value @{ message = "Subscription doesn't exist." } -StatusCode 400
                        }
                    }
                }
                else {
                    Write-PodeJsonResponse -StatusCode 400 -Value @{
                        message = $Validate.message -join ', '
                    }
                }
            }
            default {
                Write-PodeJsonResponse -Value @{ message = 'Invalid Content-Type' } -StatusCode 400
            }
        }
    } -PassThru | Set-PodeOARouteInfo -Summary 'Unsubscribe from webhook events' -OperationId 'unsubscribe' -Description 'Allows a client to unsubscribe from webhook events.' -PassThru |
        Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content @{ 'application/json' = 'WebhookUri' }) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'SucessfulResponse' -PassThru |
        Add-PodeOAResponse -StatusCode 400 -Reference 'FailureResponse'

    # Route for handling data storage via POST
    Add-PodeRoute -Method Post -Path '/store' -ScriptBlock {
        $data = $WebEvent.data
        # Log the received data to the console
        Write-PodeHost 'Received Store Data:' -NoNewLine
        Write-PodeHost $data -Explode

        # Validate the incoming request against the WebhookPayload schema
        $Validate = Test-PodeOAJsonSchemaCompliance -Json $data -SchemaReference 'WebhookPayload'
        if ($Validate.result) {
            Lock-PodeObject -ScriptBlock {
                # Notify all subscribed endpoints
                foreach ($url in $state:subscriptions.Keys) {
                    try {
                        Write-PodeHost "Notifying $url"
                        Invoke-RestMethod -Uri $url -Method Post -Body ($data | ConvertTo-Json) -ContentType 'application/json'
                    }
                    catch {
                        Write-PodeHost "Failed to notify $url"
                    }
                }
            }
            # Respond with a status message
            Write-PodeJsonResponse -Value @{ message = 'Webhook processed successfully!' }
        }
        else {
            Write-PodeJsonResponse -StatusCode 400 -Value @{
                message = $Validate.message -join ', '
            }
        }
    } -PassThru | Set-PodeOARouteInfo -Summary 'Store data' -OperationId 'storeData' -Description 'Endpoint for storing data.' -PassThru |
        Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content @{ 'application/json' = 'WebhookPayload' }) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'SucessfulResponse' -PassThru |
        Add-PodeOAResponse -StatusCode 400 -Reference 'FailureResponse'

    # Define the webhook event for OpenAPI documentation
    Add-PodeOAWebhook -Name 'webhookEvent' -Method Post -PassThru |
        Set-PodeOARouteInfo -Summary 'Handle webhook event' -Description 'Endpoint for receiving webhook events.' -OperationId 'handleWebhookEvent' -PassThru |
        Set-PodeOARequest -RequestBody (New-PodeOARequestBody -Required -Content @{ 'application/json' = 'WebhookPayload' }) -PassThru |
        Add-PodeOAResponse -StatusCode 200 -Reference 'SucessfulResponse' -PassThru |
        Add-PodeOAResponse -StatusCode 400 -Description 'Invalid input' -PassThru

}
