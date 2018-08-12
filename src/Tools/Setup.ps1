function Pode
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('init', 'test', 'start', 'install', 'build')]
        [Alias('a')]
        [string]
        $Action
    )

    # default config file name and content
    $file = './package.json'
    $name = Split-Path -Leaf -Path $pwd
    $data = $null

    # defualt config data that's used to populate on init
    $map = @{
        'name' = $name;
        'version' = '1.0.0';
        'description' = '';
        'main' = './index.ps1';
        'scripts' = @{
            'start' = './index.ps1';
            'install' = 'yarn install --force --ignore-scripts --modules-folder pode_modules';
            "build" = 'psake';
            'test' = 'invoke-pester ./tests/*.ps1'
        };
        'author' = '';
        'license' = 'MIT';
    }

    # check and load config if already exists
    if (Test-Path $file) {
        $data = (Get-Content $file | ConvertFrom-Json)
    }

    # quick check to see if the data is required
    if ($Action -ine 'init') {
        if ($null -eq $data) {
            Write-Host 'package.json file not found' -ForegroundColor Red
            return
        }
        else {
            $value = $data.scripts.$Action

            if ([string]::IsNullOrWhiteSpace($value) -and $Action -ieq 'start') {
                $value = $data.main
            }

            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Host "package.config does not contain a script for $($Action)" -ForegroundColor Yellow
                return
            }
        }
    }
    else {
        if ($null -ne $data) {
            Write-Host 'package.json already exists' -ForegroundColor Yellow
            return
        }
    }

    switch ($Action.ToLowerInvariant())
    {
        'init' {
            $v = Read-Host -Prompt "name ($($map.name))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.name = $v }

            $v = Read-Host -Prompt "version ($($map.version))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.version = $v }

            $map.description = Read-Host -Prompt "description"

            $v = Read-Host -Prompt "entry point ($($map.main))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.main = $v; $map.scripts.start = $v }

            $map.author = Read-Host -Prompt "author"

            $v = Read-Host -Prompt "license ($($map.license))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.license = $v }

            $map | ConvertTo-Json -Depth 10 | Out-File -FilePath $file -Encoding utf8 -Force
            Write-Host 'Success, saved package.json' -ForegroundColor Green
        }

        'test' {
            Invoke-PodePackageScript -Value $value
        }

        'start' {
            Invoke-PodePackageScript -Value $value
        }

        'install' {
            Invoke-PodePackageScript -Value $value
        }

        'build' {
            Invoke-PodePackageScript -Value $value
        }
    }
}

function Invoke-PodePackageScript
{
    param (
        [Parameter()]
        [string]
        $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return
    }

    if (Test-IsPSCore) {
        pwsh.exe /c "$($value)"
    }
    else {
        powershell.exe /c "$($value)"
    }
}