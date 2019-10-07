function Invoke-PodePackageScript
{
    param (
        [Parameter()]
        [string]
        $ActionScript
    )

    if ([string]::IsNullOrWhiteSpace($ActionScript)) {
        return
    }

    if (Test-PodeIsPSCore) {
        pwsh.exe /c "$($ActionScript)"
    }
    else {
        powershell.exe /c "$($ActionScript)"
    }
}

function Install-PodeLocalModules
{
    param (
        [Parameter()]
        $Modules = $null
    )

    if ($null -eq $Modules) {
        return
    }

    $psModules = './ps_modules'

    # download modules to ps_modules
    $Modules.psobject.properties.name | ForEach-Object {
        $_name = $_
        $_version = $Modules.$_name

        try {
            # if version is latest, retrieve current
            if ($_version -ieq 'latest') {
                $_version = [string]((Find-Module $_name -ErrorAction Ignore).Version)
            }

            Write-Host "=> Downloading $($_name)@$($_version)... " -NoNewline -ForegroundColor Cyan

            # if the current version exists, do nothing
            if (!(Test-Path (Join-Path $psModules "$($_name)/$($_version)"))) {
                # remove other versions
                if (Test-Path (Join-Path $psModules "$($_name)")) {
                    Remove-Item -Path (Join-Path $psModules "$($_name)") -Force -Recurse | Out-Null
                }

                # download the module
                Save-Module -Name $_name -RequiredVersion $_version -Path $psModules -Force -ErrorAction Stop | Out-Null
            }

            Write-Host 'Success' -ForegroundColor Green
        }
        catch {
            Write-Host 'Failed' -ForegroundColor Red
            throw "Module or version not found: $($_name)@$($_version)"
        }
    }
}