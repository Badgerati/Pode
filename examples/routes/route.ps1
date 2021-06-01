Add-PodeRoute -Method Get -Path '/route-file' -ScriptBlock {
    Write-PodeJsonResponse -Value @{ Message = "I'm from a route file!" }
}