BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
}

Describe 'Exported Functions' {
    It 'Have Parameter Descriptions' {
        $psDataFile = Import-PowerShellDataFile "$src/Pode.psd1"
        $funcs = $psDataFile.FunctionsToExport
        $found = @()

        foreach ($func in $funcs) {
            $params = (Get-Help -Name $func -Detailed).parameters.parameter
            foreach ($param in $params) {
                if (!$param.Description) {
                    $found += "$($func): $($param.Name)"
                }
            }
        }

        $found | Should -Be @()
    }
}