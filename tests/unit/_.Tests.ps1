[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeDiscovery {
    $path = $PSCommandPath
    $examplesPath = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/examples/'

    $excludeDirs = @('scripts', 'views', 'static', 'public', 'assets', 'timers', 'modules',
        'Authentication', 'certs', 'logs', 'relative', 'routes') # List of directories to exclude
    # Filter out non-existing directories
    $existingExcludeDirs = @()
    foreach ($dir in $excludeDirs) {
        if (Test-Path -Path (Join-Path -Path $examplesPath -ChildPath $dir)) {
            $existingExcludeDirs += $dir
        }
    }
    $ps1Files = (Get-ChildItem -Path $examplesPath -Filter *.ps1 -Recurse |
            Where-Object {
                $exclude = $false
                foreach ($dir in $existingExcludeDirs) {
                    if ($_.FullName -like "*$([IO.Path]::DirectorySeparatorChar)$dir$([IO.Path]::DirectorySeparatorChar)*") {
                        $exclude = $true
                        break
                    }
                }
                -not $exclude
            }).FullName
}
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'

    # public functions
    $sysFuncs = Get-ChildItem Function:
    $sysAliases = Get-ChildItem Alias:

    Get-ChildItem "$($src)/Public/*.ps1" | ForEach-Object { . $_ }
    $publicFuncs = Get-ChildItem Function: | Where-Object { $sysFuncs -notcontains $_ }
    $publicAliases = Get-ChildItem Alias: | Where-Object { $sysAliases -notcontains $_ }

    # private functions
    $sysFuncs = Get-ChildItem Function:
    $sysAliases = Get-ChildItem Alias:

    Get-ChildItem "$($src)/Private/*.ps1" | ForEach-Object { . $_ }
    $privateFuncs = Get-ChildItem Function: | Where-Object { $sysFuncs -notcontains $_ }
    $privateAliases = Get-ChildItem Alias: | Where-Object { $sysAliases -notcontains $_ }
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

    It 'Are in PSD1' {
        $psDataFile = Import-PowerShellDataFile "$src/Pode.psd1"
        $funcs = $psDataFile.FunctionsToExport
        $missing = @()

        foreach ($func in $publicFuncs) {
            if ($func.Name -inotin $funcs) {
                $missing += $func.Name
            }
        }

        $missing | SHould -Be @()
    }
}

Describe 'Exported Aliases' {
    It 'Are in PSD1' {
        $psDataFile = Import-PowerShellDataFile "$src/Pode.psd1"
        $aliases = $psDataFile.AliasesToExport
        $missing = @()

        foreach ($alias in $publicAliases) {
            if ($alias.Name -inotin $aliases) {
                $missing += $alias.Name
            }
        }

        $missing | SHould -Be @()
    }
}

Describe 'All Functions' {
    It 'Have Pode Tag' {
        $found = @()

        foreach ($func in ($publicFuncs + $privateFuncs)) {
            if (($func.Noun -cnotlike 'Pode*') -and ($func.Name -cne 'Pode')) {
                $found += $func.Name
            }
        }

        $found | Should -Be @()
    }

    It 'Use Approved Verbs' {
        $found = @()
        $verbs = (Get-Verb).Verb

        foreach ($func in ($publicFuncs + $privateFuncs)) {
            if (![string]::IsNullOrEmpty($func.Verb) -and ($func.Verb -cnotin $verbs)) {
                $found += $func.Name
            }
        }

        $found | Should -Be @()
    }
}

Describe 'All Aliases' {
    It 'Have Pode Tag' {
        $found = @()

        foreach ($alias in ($publicAliases + $privateAliases)) {
            if ($alias.Name -cnotlike '*-Pode*') {
                $found += $alias.Name
            }
        }

        $found | Should -Be @()
    }

    It 'Use Approved Verbs' {
        $found = @()
        $verbs = (Get-Verb).Verb

        foreach ($alias in ($publicAliases + $privateAliases)) {
            if (($alias.Name -split '-')[0] -cnotin $verbs) {
                $found += $alias.Name
            }
        }

        $found | Should -Be @()
    }
}


Describe 'Examples Script Headers' {
    Context 'Checking file: [<_>]' -ForEach ($ps1Files) {
        BeforeAll {
            $content = Get-Content -Path $_ -Raw
        }
        It 'should have a .SYNOPSIS section' {
            $hasSynopsis = $content -match '\.SYNOPSIS\s+([^\#]*)'
            $hasSynopsis | Should -Be $true
        }

        It 'should have a .DESCRIPTION section' {
            $hasDescription = $content -match '\.DESCRIPTION\s+([^\#]*)'
            $hasDescription | Should -Be $true
        }

        It 'should have a .NOTES section with Author and License' {
            $hasNotes = $content -match '\.NOTES\s+([^\#]*?)Author:\s*Pode Team\s*License:\s*MIT License'
            $hasNotes | Should -Be $true
        }

    <#     It 'should have a .LINK section' {
            $hasDescription = $content -match '\.LINK\s+([^\#]*)'
            $hasDescription | Should -Be $true
        }

        It 'should have a .EXAMPLE section' {
            $hasDescription = $content -match '\.EXAMPLE\s+([^\#]*)'
            $hasDescription | Should -Be $true
        }#>
    }

}