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

    Invoke-Expression -Command $ActionScript
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
        $_version = $Modules.$_name.version
        $_repository = if ([string]::IsNullOrEmpty("$($Modules.$_name.$_repository)")) {
            'psgallery' 
        }
        else { 
            [string]"$($Modules.$_name.$_repository)" 
        }

        try {
            # if version is latest, retrieve current
            if ($_version -ieq 'latest') {
                $_version = [string]((Find-Module Repository $_repository -Name $_name -ErrorAction Ignore).Version)
            }

            Write-Host "=> Downloading $($_name)@$($_version) from $($_repository)... " -NoNewline -ForegroundColor Cyan

            # if the current version exists, do nothing
            if (!(Test-Path (Join-Path $psModules "$($_name)/$($_version)"))) {
                # remove other versions
                if (Test-Path (Join-Path $psModules "$($_name)")) {
                    Remove-Item -Path (Join-Path $psModules "$($_name)") -Force -Recurse | Out-Null
                }

                # download the module
                Save-Module -Repository $_repository -Name $_name -RequiredVersion $_version -Path $psModules -Force -ErrorAction Stop | Out-Null
            }

            Write-Host 'Success' -ForegroundColor Green
        }
        catch {
            Write-Host 'Failed' -ForegroundColor Red
            throw "Module or version not found: $($_name)@$($_version) in Repository '$($_repository)'"
        }
    }
}
