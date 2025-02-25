<#
.SYNOPSIS
    Extracts functions from PowerShell scripts, supports merging them back, and provides backup/restore functionality.

.DESCRIPTION
    This script processes .ps1 files within the Private and Public subdirectories of the specified
    source directory. It extracts functions into separate files (optionally preserving any "using namespace"
    directives from the top of the file) and supports merging them back. Merge mode can operate per-extraction folder
    (the default) or, if -MergeAll is specified, all extracted files within each target subdirectory are merged into a
    single file (Private.ps1 or Public.ps1). Optionally, -StripHeaders removes the header portion from each function
    file during merge.

    The script also automatically creates a backup of the Private and Public folders (unless running in restore mode)
    and supports restoring from a specified backup (or the latest backup if none is specified).

.PARAMETER SourceDirectory
    The root directory containing the Private and Public subdirectories. Defaults to './src'.

.PARAMETER Merge
    Performs merge operations. In default mode, each extraction folder is merged into a file in its parent folder.

.PARAMETER MergeAll
    When used with -Merge, all extracted function files under each target subdirectory are merged into a single file
    (Private.ps1 for the Private folder, and Public.ps1 for the Public folder).

.PARAMETER StripHeaders
    When used with -Merge or -MergeAll, removes header sections (as returned by Get-PrecedingHeader) from each function
    file so that only the function body remains.

.PARAMETER Restore
    Restores a backup of the Private and Public subdirectories. Optionally, a backup folder name can be provided via
    -BackupName; if omitted, the most recent backup is used.

.PARAMETER BackupOnly
    Creates a backup of the Private and Public subdirectories without performing any extraction or merge operations.

.EXAMPLE
    # Extract functions (with automatic backup) from scripts in ./src
    .\YourScript.ps1 -SourceDirectory "./src"

.EXAMPLE
    # Merge extracted function files per extraction folder (default merge behavior)
    .\YourScript.ps1 -SourceDirectory "./src" -Merge

.EXAMPLE
    # Merge all extracted function files in Private and Public into Private.ps1 and Public.ps1,
    # and remove header sections from each function.
    .\YourScript.ps1 -SourceDirectory "./src" -Merge -MergeAll -StripHeaders

.EXAMPLE
    # Restore the latest backup
    .\YourScript.ps1 -SourceDirectory "./src" -Restore

.EXAMPLE
    # Restore from a specific backup folder
    .\YourScript.ps1 -SourceDirectory "./src" -Restore -BackupName "20230425123045"
#>
[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    [Parameter(Mandatory = $false)]
    [string]$SourceDirectory = './src',

    [Parameter(Mandatory = $true, ParameterSetName = 'Merge')]
    [switch]$Merge,

    [Parameter(Mandatory = $false, ParameterSetName = 'Merge')]
    [switch]$MergeAll,

    [Parameter(Mandatory = $false, ParameterSetName = 'Merge')]
    [switch]$StripHeaders,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [switch]$Restore,

    [Parameter(Mandatory = $false, ParameterSetName = 'Restore')]
    [string]$BackupName,

    [Parameter(Mandatory = $true, ParameterSetName = 'BackupOnly')]
    [switch]$BackupOnly
)

# Define the backup folder under the source.
$BackupFolder = Join-Path $SourceDirectory 'Backup'

###############################################################################
# RESTORE MODE
if ($Restore) {
    if (-not (Test-Path $BackupFolder)) {
        Write-Error "No backup folder found under $SourceDirectory\Backup."
        exit 1
    }
    # If a backup name is provided, use that; otherwise, choose the most recent backup.
    if ($BackupName) {
        $backupToRestore = Join-Path $BackupFolder $BackupName
        if (-not (Test-Path $backupToRestore)) {
            Write-Error "Backup folder '$BackupName' not found under $BackupFolder."
            exit 1
        }
    }
    else {
        $backupToRestore = Get-ChildItem -Path $BackupFolder -Directory | Sort-Object CreationTime -Descending | Select-Object -First 1
        if (-not $backupToRestore) {
            Write-Error "No backup subfolder found under $BackupFolder."
            exit 1
        }
        $backupToRestore = $backupToRestore.FullName
    }
    Write-Output "Restoring backup from '$backupToRestore' to '$SourceDirectory' ..."

    # Remove existing target directories ("Private" and "Public")
    @('Private', 'Public') | ForEach-Object {
        $target = Join-Path $SourceDirectory $_
        if (Test-Path $target) {
            Remove-Item -Path $target -Recurse -Force
            Write-Output "Removed existing directory: $target"
        }
    }

    # Copy backup content back to source (overwrite existing files)
    Copy-Item -Path (Join-Path $backupToRestore '*') -Destination $SourceDirectory -Recurse -Force
    Write-Output 'Restore complete.'
    exit
}

###############################################################################
# AUTOMATIC BACKUP (unless in Restore mode)
# (Automatically performed unless in restore mode.)
if (-not (Test-Path $BackupFolder)) {
    New-Item -Path $BackupFolder -ItemType Directory | Out-Null
}
$timestamp = (Get-Date -Format 'yyyyMMddHHmmss')
$BackupSubFolder = Join-Path $BackupFolder $timestamp
New-Item -Path $BackupSubFolder -ItemType Directory | Out-Null

# Determine target subdirectories: only 'Private' and 'Public'
$targetSubDirs = @('Private', 'Public') | ForEach-Object {
    $fullPath = Join-Path $SourceDirectory $_
    if (Test-Path $fullPath -PathType Container) { $fullPath }
}
foreach ($sub in $targetSubDirs) {
    $subName = Split-Path $sub -Leaf
    $destBackup = Join-Path $BackupSubFolder $subName
    Copy-Item -Path $sub -Destination $destBackup -Recurse -Force
}
Write-Output "Backup created at $BackupSubFolder"
if ($BackupOnly) {
    exit
}

###############################################################################
# HELPER FUNCTIONS

function Get-PrecedingHeader {
    param (
        [string[]]$Lines,
        [int]$FunctionStartLine, # 1-indexed line number where the function starts
        [int]$IndentSize = 4       # Settable indentation size (default: 4 spaces)
    )

    $headerLines = [System.Collections.Generic.List[string]]::new()
    $i = $FunctionStartLine - 2  # Index of the line immediately before the function definition

    $inBlockComment = $false
    $indentationLevel = -1  # Default detected indentation level (-1 means not detected)
    $foundClosingComment = $false  # Flag to detect #> (end of comment)

    while ($i -ge 0) {
        $line = $Lines[$i]
        $trimmed = $line.Trim()

        if ($trimmed -match '^\.SYNOPSIS') {
            # If we find .SYNOPSIS, look at the next line for indentation reference
            if ($i + 1 -lt $Lines.Length) {
                $nextLine = $Lines[$i + 1]
                if ($nextLine -match '^(\s+)') {
                    $indentationLevel = $matches[1].Length  # Capture the number of spaces used
                }
            }
        }

        # If indentation level was never detected, default to IndentSize
        if ($indentationLevel -eq -1) {
            $indentationLevel = $IndentSize
        }

        if ($inBlockComment) {
            if (![string]::IsNullOrWhiteSpace($line) -and -not ($line.StartsWith('.') -or $line.StartsWith('<#'))) {
                # Ensure all non-dot-prefixed lines use IndentSize
                if ($line -match '^\s*') {
                    $line = (' ' * $IndentSize) + $line.TrimStart()
                }
            }
            $headerLines.Insert(0, $line)

            if ($trimmed -match '^<#') {
                break
            }
        }
        else {
            if ($trimmed -eq '') {
                # Remove empty lines **only if we've already found #>**
                if ($foundClosingComment) {
                    $headerLines.Insert(0, $line)
                }
            }
            elseif ($trimmed -match '^<#') {
                $headerLines.Insert(0, $line)
                break
            }
            elseif ($trimmed -match '^#>') {
                $inBlockComment = $true
                $foundClosingComment = $true  # Set flag to remove extra empty lines after this
                $headerLines.Insert(0, $line)
            }
            elseif ($trimmed -match '^#') {
                if (![string]::IsNullOrWhiteSpace($line) -and -not ($line.StartsWith('.') -or $line.StartsWith('<#'))) {
                    # Ensure all non-dot-prefixed lines use IndentSize
                    if ($line -match '^\s*') {
                        $line = (' ' * $IndentSize) + $line.TrimStart()
                    }
                }
                $headerLines.Insert(0, $line)
            }
            else {
                break
            }
        }
        $i--
    }
    return $headerLines
}

# This helper function strips header content from a merged function file.
# It assumes that if a header exists, it ends at the line that starts with "#>".
# Improved Remove-Header function
# Improved Remove-Header function
function Remove-Header {
    param (
        [string]$Content
    )
    $lines = $Content -split [Environment]::NewLine
    $headerEndIndex = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*#>') {
            $headerEndIndex = $i
            break
        }
    }
    if ($null -ne $headerEndIndex ) {
        if ($headerEndIndex + 1 -lt $lines.Count) {
            return ($lines[($headerEndIndex + 1)..($lines.Count - 1)] -join [Environment]::NewLine).Trim()
        }
        else {
            return ""
        }
    }
    return $Content.Trim()
}

# MERGE ALL MODE (with improved header stripping and using namespace handling)
if ($Merge -and $MergeAll) {
    foreach ($subDir in $targetSubDirs) {
        $targetName = Split-Path $subDir -Leaf
        # Gather all extracted function files (recursively) in this subdirectory.
        $allFunctionFiles = Get-ChildItem -Path $subDir -Recurse -File -Filter '*.ps1'

        # Initialize a hash table for unique using namespace lines and an array for processed contents.
        $usingNamespaces = @{}
        $processedContents = @()

        foreach ($file in ($allFunctionFiles | Sort-Object FullName)) {
            $content = Get-Content -Path $file.FullName -Raw
            $lines = $content -split [Environment]::NewLine

            # Remove leading lines that start with 'using namespace'
            $index = 0
            while ($index -lt $lines.Count -and $lines[$index].Trim() -match '^using\s+namespace') {
                $usingLine = $lines[$index].Trim()
                $usingNamespaces[$usingLine] = $true
                $index++
            }
            # Rebuild the file content without the using namespace lines.
            if ($index -lt $lines.Count) {
                $newContent = $lines[$index..($lines.Count - 1)] -join [Environment]::NewLine
            }
            else {
                $newContent = ''
            }
            # If the StripHeaders switch is set, remove the header from the content.
            if ($StripHeaders) {
                $newContent = Remove-Header $newContent
            }
            $processedContents += $newContent
        }

        # Build the unique using namespace block (preserving the original order).
        $usingBlock = ($usingNamespaces.Keys) -join [Environment]::NewLine

        # Merge all processed contents with a blank line between them.
        $mergedBody = $processedContents -join ([Environment]::NewLine + [Environment]::NewLine)
        if ($usingBlock.Trim().Length -gt 0) {
            $mergedContent = "$usingBlock$([Environment]::NewLine)$([Environment]::NewLine)$mergedBody"
        }
        else {
            $mergedContent = $mergedBody
        }

        $mergedFilePath = Join-Path $subDir "$targetName.ps1"
        Set-Content -Path $mergedFilePath -Value $mergedContent.TrimEnd() -Encoding UTF8
        Write-Output "Merged all function files in '$subDir' into '$mergedFilePath'"

        # Remove all extraction folders (child directories) under this target subdirectory.
        Get-ChildItem -Path $subDir -Directory | ForEach-Object {
            Remove-Item -Path $_.FullName -Recurse -Force
            Write-Output "Removed extraction folder: $($_.FullName)"
        }
    }
}


###############################################################################
# Determine the target subdirectories ("Private" and "Public") within the source.
$targetSubDirs = @('Private', 'Public') | ForEach-Object {
    $fullPath = Join-Path $SourceDirectory $_
    if (Test-Path $fullPath -PathType Container) { $fullPath }
}
if (-not $targetSubDirs) {
    Write-Error "No 'Private' or 'Public' subdirectories found under $SourceDirectory"
    exit 1
}

###############################################################################
# MAIN OPERATION
if ($Merge) {
    if ($MergeAll) {
        foreach ($subDir in $targetSubDirs) {
            $targetName = Split-Path $subDir -Leaf
            # Gather all extracted function files (recursively) in this subdirectory.
            $allFunctionFiles = Get-ChildItem -Path $subDir -Recurse -File -Filter '*.ps1'

            # Initialize a hash table for unique using namespace lines and an array for processed contents.
            $usingNamespaces = @{}
            $processedContents = @()

            foreach ($file in ($allFunctionFiles | Sort-Object FullName)) {
                $content = Get-Content -Path $file.FullName -Raw
                $lines = $content -split [Environment]::NewLine

                # Remove leading lines that start with 'using namespace'
                $index = 0
                while ($index -lt $lines.Count -and $lines[$index].Trim() -match '^using\s+namespace') {
                    $usingLine = $lines[$index].Trim()
                    $usingNamespaces[$usingLine] = $true
                    $index++
                }
                # Rebuild the file content without the using namespace lines.
                if ($index -lt $lines.Count) {
                    $newContent = $lines[$index..($lines.Count - 1)] -join [Environment]::NewLine
                }
                else {
                    $newContent = ''
                }
                # If the StripHeaders switch is set, remove the header from the content.
                if ($StripHeaders) {
                    $newContent = Remove-Header $newContent
                }
                $processedContents += $newContent
            }

            # Build the unique using namespace block.
            $usingBlock = ($usingNamespaces.Keys) -join [Environment]::NewLine

            # Merge all processed contents with a blank line between them.
            $mergedBody = $processedContents -join ([Environment]::NewLine + [Environment]::NewLine)
            if ($usingBlock.Trim().Length -gt 0) {
                $mergedContent = "$usingBlock$([Environment]::NewLine)$([Environment]::NewLine)$mergedBody"
            }
            else {
                $mergedContent = $mergedBody
            }

            $mergedFilePath = Join-Path $subDir "$targetName.ps1"
            Set-Content -Path $mergedFilePath -Value $mergedContent.TrimEnd() -Encoding UTF8
            Write-Output "Merged all function files in '$subDir' into '$mergedFilePath'"

            # Remove all extraction folders (child directories) under this target subdirectory.
            Get-ChildItem -Path $subDir -Directory | ForEach-Object {
                Remove-Item -Path $_.FullName -Recurse -Force
                Write-Output "Removed extraction folder: $($_.FullName)"
            }
        }
    }
    else {
        # EXISTING MERGE MODE: Merge extracted function files per extraction folder.
        foreach ($subDir in $targetSubDirs) {
            Get-ChildItem -Path $subDir -Recurse -Directory | ForEach-Object {
                $currentDir = $_.FullName
                # Process only directories that contain one or more .ps1 files.
                $ps1Files = Get-ChildItem -Path $currentDir -Filter '*.ps1' -File
                if ($ps1Files.Count -gt 0) {
                    # Initialize a hash table for unique using namespace lines.
                    $usingNamespaces = @{}

                    # Array to store the processed content of each function file.
                    $processedContents = @()

                    foreach ($file in ($ps1Files | Sort-Object Name)) {
                        $content = Get-Content -Path $file.FullName -Raw
                        $lines = $content -split [Environment]::NewLine

                        # Remove leading lines that start with 'using namespace'
                        $index = 0
                        while ($index -lt $lines.Count -and $lines[$index].Trim() -match '^using\s+namespace') {
                            $usingLine = $lines[$index].Trim()
                            $usingNamespaces[$usingLine] = $true
                            $index++
                        }
                        # Rebuild the file content without the using namespace lines.
                        if ($index -lt $lines.Count) {
                            $newContent = $lines[$index..($lines.Count - 1)] -join [Environment]::NewLine
                        }
                        else {
                            $newContent = ''
                        }
                        $processedContents += $newContent
                    }

                    # Build the unique using namespace block (preserving the original order).
                    $usingBlock = ($usingNamespaces.Keys) -join [Environment]::NewLine

                    # Merge the processed contents with a blank line between them.
                    $mergedBody = $processedContents -join ([Environment]::NewLine + [Environment]::NewLine)

                    # Prepend the using block if any were found.
                    if ($usingBlock.Trim().Length -gt 0) {
                        $mergedContent = "$usingBlock$([Environment]::NewLine)$([Environment]::NewLine)$mergedBody"
                    }
                    else {
                        $mergedContent = $mergedBody
                    }

                    $mergedFileName = "$($_.Name).ps1"
                    $mergedFilePath = Join-Path $_.Parent.FullName $mergedFileName
                    Write-Output "Merging folder '$currentDir' into '$mergedFilePath'"

                    Set-Content -Path $mergedFilePath -Value $mergedContent.TrimEnd() -Encoding UTF8

                    Remove-Item -Path $currentDir -Recurse -Force
                    Write-Output "Removed extraction folder: $currentDir"
                }
            }
        }
    }
}
else {
    # EXTRACTION MODE: Process .ps1 files in the Private and Public subdirectories.
    foreach ($subDir in $targetSubDirs) {
        Get-ChildItem -Path $subDir -File -Filter '*.ps1' |
            # Exclude any file that is already in an extraction folder (its parent folder matches its BaseName)
            Where-Object { $_.Directory.Name -ne $_.BaseName } |
            ForEach-Object {
                $FilePath = $_.FullName
                $BaseName = $_.BaseName
                $FileDirectory = $_.DirectoryName

                # Create a destination folder with the same name as the file.
                $DestinationFolder = Join-Path $FileDirectory $BaseName
                if (!(Test-Path $DestinationFolder -PathType Container)) {
                    New-Item -Path $DestinationFolder -ItemType Directory | Out-Null
                }

                # Read the file's content.
                $Content = Get-Content -Path $FilePath -Raw
                $Lines = Get-Content -Path $FilePath

                # Check for multiple "using namespace" lines at the top.
                $usingNamespaces = @()
                $idx = 0
                while ($idx -lt $Lines.Count -and $Lines[$idx].Trim() -match '^using\s+namespace') {
                    $lineUsing = $Lines[$idx].Trim()
                    if ($usingNamespaces -notcontains $lineUsing) {
                        $usingNamespaces += $lineUsing
                    }
                    $idx++
                }
                $usingBlock = $null
                if ($usingNamespaces.Count -gt 0) {
                    $usingBlock = $usingNamespaces -join [Environment]::NewLine
                }

                # Parse the file for functions using AST.
                $null = $Error.Clear()
                $Tokens = $null
                $Ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$Tokens, [ref]$null)
                $FunctionAsts = $Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

                if ($FunctionAsts.Count -eq 0) {
                    Write-Warning "No functions found in file: $FilePath"
                }
                else {
                    foreach ($funcAst in $FunctionAsts) {
                        $startLine = $funcAst.Extent.StartLineNumber
                        $headerLines = Get-PrecedingHeader -Lines $Lines -FunctionStartLine $startLine
                        $headerText = $headerLines -join [Environment]::NewLine
                        $functionText = $funcAst.Extent.Text.Trim()

                        if ($headerText.Trim().Length -gt 0) {
                            $fullText = "$headerText$([Environment]::NewLine)$functionText"
                        }
                        else {
                            $fullText = $functionText
                        }

                        # Prepend the using namespace block if present.
                        if ($usingBlock) {
                            $fullText = "$usingBlock$([Environment]::NewLine)$fullText"
                        }

                        $functionName = $funcAst.Name
                        if ([string]::IsNullOrWhiteSpace($functionName)) {
                            $functionName = 'UnknownFunction'
                        }
                        # Create the function file.
                        $functionFile = Join-Path $DestinationFolder "$functionName.ps1"
                        Set-Content -Path $functionFile -Value $fullText -Encoding UTF8
                        Write-Output "Extracted: $functionName -> $functionFile"
                    }
                }

                # Remove the original file after extraction.
                Remove-Item -Path $FilePath -Force
                Write-Output "Removed original file: $FilePath"
            }
    }
}