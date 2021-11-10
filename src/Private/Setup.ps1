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

        # get the module version
        $_version = $Modules.$_name.version
        if ([string]::IsNullOrWhiteSpace($_version)) {
            $_version = $Modules.$_name
        }

        # get the module repository
        $_repository = Protect-PodeValue -Value $Modules.$_name.repository -Default 'PSGallery'

        try {
            # if version is latest, retrieve current
            if ($_version -ieq 'latest') {
                $_version = [string]((Find-Module $_name -Repository $_repository -ErrorAction Ignore).Version)
            }

            Write-Host "=> Downloading $($_name)@$($_version) from $($_repository)... " -NoNewline -ForegroundColor Cyan

            # if the current version exists, do nothing
            if (!(Test-Path ([System.IO.Path]::Combine($psModules, "$($_name)/$($_version)")))) {
                # remove other versions
                if (Test-Path ([System.IO.Path]::Combine($psModules, "$($_name)"))) {
                    $null = Remove-Item -Path ([System.IO.Path]::Combine($psModules, "$($_name)")) -Force -Recurse
                }

                # download the module
                $null = Save-Module -Name $_name -RequiredVersion $_version -Repository $_repository -Path $psModules -Force -ErrorAction Stop
            }

            Write-Host 'Success' -ForegroundColor Green
        }
        catch {
            Write-Host 'Failed' -ForegroundColor Red
            throw "Module or version not found on $($_repository): $($_name)@$($_version)"
        }
    }
}