# Determine which Program Files path to use
if (![string]::IsNullOrWhiteSpace($env:ProgramFiles))
{
    $modulePath = Join-Path $env:ProgramFiles (Join-Path 'WindowsPowerShell' 'Modules')
}
else
{
    $modulePath = Join-Path ${env:ProgramFiles(x86)} (Join-Path 'WindowsPowerShell' 'Modules')
}

# Delete Pode module
$podeModulePath = Join-Path $modulePath 'Pode'
if (Test-Path $podeModulePath)
{
    Write-Host 'Deleting Pode module directory'
    Remove-Item -Path $podeModulePath -Recurse -Force | Out-Null
    if (!$?)
    {
        throw "Failed to delete: $podeModulePath"
    }
}