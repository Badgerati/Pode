function Get-Greeting {
    return "Hello, world! [$(Get-Random -Maximum 100)]"
}