
function Get-PodeDotSourcedFile {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.Language.Ast]
        $Ast,

        [Parameter()]
        [string]
        $RootPath
    )

    # set default root path
    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $RootPath = $PodeContext.Server.Root
    }

    # get all dot-sourced files
    $cmdTypes = @('dot', 'ampersand')
    $files = ($Ast.FindAll({
        ($args[0] -is [System.Management.Automation.Language.CommandAst]) -and
        ($args[0].InvocationOperator -iin $cmdTypes) -and
        ($args[0].CommandElements.StaticType.Name -ieq 'string')
            }, $false)).CommandElements.Value

    $fileOrder = @()

    # no files found
    if (($null -eq $files) -or ($files.Length -eq 0)) {
        return $fileOrder
    }

    # get any sub sourced files
    foreach ($file in $files) {
        $file = Get-PodeRelativePath -Path $file -RootPath $RootPath -JoinRoot
        $fileOrder += $file

        $ast = Get-PodeAstFromFile -FilePath $file

        $result = Get-PodeDotSourcedFile -Ast $ast -RootPath (Split-Path -Parent -Path $file)
        if (($null -ne $result) -and ($result.Length -gt 0)) {
            $fileOrder += $result
        }
    }

    # return all found files
    return $fileOrder
}


# Convert-PodePathSeparators
function Convert-PodePathSeparator {
    param(
        [Parameter()]
        $Paths
    )

    return @($Paths | ForEach-Object {
            if (![string]::IsNullOrWhiteSpace($_)) {
                $_ -ireplace '[\\/]', [System.IO.Path]::DirectorySeparatorChar
            }
        })
}



function Open-PodeRunspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Type
    )

    try {
        Import-PodeModulesInternal
        Add-PodePSDrivesInternal
        $PodeContext.RunspacePools[$Type].State = 'Ready'
    }
    catch {
        if ($PodeContext.RunspacePools[$Type].State -ieq 'waiting') {
            $PodeContext.RunspacePools[$Type].State = 'Error'
        }

        $_ | Out-Default
        $_.ScriptStackTrace | Out-Default
        throw
    }
}



<#
.SYNOPSIS
Tests if the Pode module is from the development branch.

.DESCRIPTION
The Test-PodeVersionDev function checks if the Pode module's version matches the placeholder value ('$version$'), which is used to indicate the development branch of the module. It returns $true if the version matches, indicating the module is from the development branch, and $false otherwise.

.PARAMETER None
This function does not accept any parameters.

.OUTPUTS
System.Boolean
Returns $true if the Pode module version is '$version$', indicating the development branch. Returns $false for any other version.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '$version$' }
PS> Test-PodeVersionDev

Returns $true, indicating the development branch.

.EXAMPLE
PS> $moduleManifest = @{ ModuleVersion = '1.2.3' }
PS> Test-PodeVersionDev

Returns $false, indicating a specific release version.

.NOTES
This function assumes that $moduleManifest is a hashtable representing the loaded module manifest, with a key of ModuleVersion.

#>
function Test-PodeVersionDev {
    return (Get-PodeModuleManifest).ModuleVersion -eq '$version$'
}
