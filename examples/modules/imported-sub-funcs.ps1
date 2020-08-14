function Write-MySubGreeting {
    Write-PodeJsonResponse -Value @{ Message = "Mudkipz! [$(Get-Random -Maximum 100)]" }
}