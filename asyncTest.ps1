$asyncRequest = @()
# PUT request 1
$asyncRequest += Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNotCancelable' -Method Put -Headers @{
    'accept'        = 'application/yaml'
    'X-API-KEY'     = 'test2-api-key'
    'Authorization' = 'Basic bWluZHk6cGlja2xl'
}

# PUT request 2
$asyncRequest += Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingNCancelable' -Method Put -Headers @{
    'accept'        = 'application/yaml'
    'X-API-KEY'     = 'test2-api-key'
    'Authorization' = 'Basic bWluZHk6cGlja2xl'
}

# PUT request 3 with JSON body
$body = @{
    callbackUrl = 'http://localhost:8080/receive/callback'
} | ConvertTo-Json

$asyncRequest += Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers @{
    'accept'        = 'application/yaml'
    'X-API-KEY'     = 'test2-api-key'
    'Authorization' = 'Basic bWluZHk6cGlja2xl'
    'Content-Type'  = 'application/json'
} -Body $body

# PUT request 4
$asyncRequest += Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncStateNoColumn' -Method Put -Headers @{
    'accept'        = 'application/yaml'
    'X-API-KEY'     = 'test2-api-key'
    'Authorization' = 'Basic bWluZHk6cGlja2xl'
}

# PUT request 5
$asyncRequest += Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers @{
    'accept'        = 'application/yaml'
    'X-API-KEY'     = 'test2-api-key'
    'Authorization' = 'Basic bWluZHk6cGlja2xl'
}

# PUT request 6
$asyncRequest += Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers @{
    'accept'        = 'application/yaml'
    'X-API-KEY'     = 'test2-api-key'
    'Authorization' = 'Basic bWluZHk6cGlja2xl'
}

$requestState = @{}
foreach ($req in $asyncRequest) {
    # GET request
    $requestState[$req.Id] = Invoke-RestMethod -Uri "http://localhost:8080/task/$($req.Id)" -Method Get -Headers @{
        'accept'        = 'application/yaml'
        'X-API-KEY'     = 'test2-api-key'
        'Authorization' = 'Basic bWluZHk6cGlja2xl'
    }
}

# DELETE request
Invoke-RestMethod -Uri 'http://localhost:8080/task?taskId=ec414e71-1aeb-4231-a0d8-12800e0d3d74' -Method Delete -Headers @{
    'accept'        = 'application/yaml'
    'X-API-KEY'     = 'test2-api-key'
    'Authorization' = 'Basic bWluZHk6cGlja2xl'
}
