
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