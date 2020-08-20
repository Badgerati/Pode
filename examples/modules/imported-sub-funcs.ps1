function Write-MySubGreeting {
    Write-PodeJsonResponse -Value @{ Message = "Mudkipz! [$(Get-Random -Maximum 100)]" }
}

Export-PodeFunction -Name 'Write-MySubGreeting'