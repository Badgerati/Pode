{
    $Id = $WebEvent.Parameters['id'] 
    Write-PodeJsonResponse -StatusCode 200 -Value @{'id' = $Id }
}