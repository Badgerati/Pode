function Write-MyGreeting {
    Write-PodeJsonResponse -Value @{ Message = "Hello, world! [$(Get-Random -Maximum 100)]" }
}

Export-PodeFunction -Name 'Write-MyGreeting'
Use-PodeScript -Path (Join-Path $PSScriptRoot .\imported-sub-funcs.ps1)