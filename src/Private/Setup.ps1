function Invoke-PodePackageScript {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
    param(
        [Parameter()]
        [string]
        $ActionScript
    )

    if ([string]::IsNullOrWhiteSpace($ActionScript)) {
        return
    }

    Invoke-Expression -Command $ActionScript
}

<#
.SYNOPSIS
    Installs a local Pode module.

.DESCRIPTION
    This function installs a local Pode module by downloading it from the specified repository. It checks the module version and retrieves the latest version if 'latest' is specified. The module is saved to the specified path.

.PARAMETER Module
    The Pode module to install. It should include the module name, version, and repository information.

.NOTES
    This is an internal function and may change in future releases of Pode.
#>
function Install-PodeLocalModule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
    param(
        [Parameter()]
        $Module = $null
    )

    if ($null -eq $Module) {
        return
    }

    $psModules = './ps_modules'

    # download modules to ps_modules
    $Module.psobject.properties.name | ForEach-Object {
        $_name = $_

        # get the module version
        $_version = $Module.$_name.version
        if ([string]::IsNullOrWhiteSpace($_version)) {
            $_version = $Module.$_name
        }

        # get the module repository
        $_repository = Protect-PodeValue -Value $Module.$_name.repository -Default 'PSGallery'

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
            throw ($PodeLocale.moduleOrVersionNotFoundExceptionMessage -f $_repository, $_name, $_version) #"Module or version not found on $($_repository): $($_name)@$($_version)"
        }
    }
}