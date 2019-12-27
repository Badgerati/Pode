{
    Add-PodeEndpoint -Address * -Port 8081 -Protocol Http
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    Set-PodeViewEngine -Type Pode

    Add-PodeTimer -Name 'Hi' -Interval 4 -ScriptBlock {
        'Hello from a file!' | Out-PodeHost
    }

    Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
        Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(1, 2, 3); }
    }
}