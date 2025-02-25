[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    [Parameter(Mandatory = $false)]
    [string]$SourceDirectory = './src',

    [Parameter(Mandatory = $true, ParameterSetName = 'Merge')]
    [switch]$Merge,

    [Parameter(Mandatory = $true, ParameterSetName = 'Restore')]
    [switch]$Restore,

    [Parameter(Mandatory = $false, ParameterSetName = 'Restore')]
    [string]$BackupName,

    [Parameter(Mandatory = $true, ParameterSetName = 'BackupOnly')]
    [switch]$BackupOnly
)

# Define the backup folder under the source.
$BackupFolder = Join-Path $SourceDirectory 'Backup'

# === RESTORE MODE ===
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

# === BACKUP MODE ===
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
# === Define the helper function for header processing ===
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
                # Remove empty lines **only if we've already found `#>`**
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



# Determine the target subdirectories ("Private" and "Public") within the source.
$targetSubDirs = @('Private', 'Public') | ForEach-Object {
    $fullPath = Join-Path $SourceDirectory $_
    if (Test-Path $fullPath -PathType Container) { $fullPath }
}

if (-not $targetSubDirs) {
    Write-Error "No 'Private' or 'Public' subdirectories found under $SourceDirectory"
    exit 1
}

if ($Merge) {
    # MERGE MODE: Merge extracted function files back into a single file per original file.
    # For each extraction folder (created during extraction) found under Private and Public,
    # merge its .ps1 files (sorted by name) into a file named after the folder in its parent,
    # then remove the extraction folder.
    foreach ($subDir in $targetSubDirs) {
        Get-ChildItem -Path $subDir -Recurse -Directory | ForEach-Object {
            $currentDir = $_.FullName
            # Process only directories that contain one or more .ps1 files.
            $ps1Files = Get-ChildItem -Path $currentDir -Filter '*.ps1' -File
            if ($ps1Files.Count -gt 0) {
                $mergedFileName = "$($_.Name).ps1"
                $mergedFilePath = Join-Path $_.Parent.FullName $mergedFileName
                Write-Output "Merging folder '$currentDir' into '$mergedFilePath'"

                $mergedContent = (($ps1Files | Sort-Object Name | ForEach-Object {
                            Get-Content -Path $_.FullName
                            [Environment]::NewLine  # Adds a newline after each file's content
                        }) -join [Environment]::NewLine).TrimEnd()
                Set-Content -Path $mergedFilePath -Value $mergedContent -Encoding UTF8

                Remove-Item -Path $currentDir -Recurse -Force
                Write-Output "Removed extraction folder: $currentDir"
            }
        }
    }
}
else {
    # EXTRACTION MODE:
    # Process only .ps1 files located in the Private and Public subdirectories.
    foreach ($subDir in $targetSubDirs) {
        Get-ChildItem -Path $subDir -File -Filter '*.ps1' |
            # Exclude any file that is already in an extraction folder (its parent folder matches its BaseName)
            Where-Object { $_.Directory.Name -ne $_.BaseName } |
            ForEach-Object {
                $FilePath = $_.FullName
                $BaseName = $_.BaseName
                $FileDirectory = $_.DirectoryName

                # Create a destination folder with the same name as the file
                $DestinationFolder = Join-Path $FileDirectory $BaseName
                if (!(Test-Path $DestinationFolder -PathType Container)) {
                    New-Item -Path $DestinationFolder -ItemType Directory | Out-Null
                }

                # Read the file's content
                $Content = Get-Content -Path $FilePath -Raw
                $Lines = Get-Content -Path $FilePath

                # Parse the file for functions using AST
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

                        $functionName = $funcAst.Name
                        if ([string]::IsNullOrWhiteSpace($functionName)) {
                            $functionName = 'UnknownFunction'
                        }
                        # Directly create the function file (no duplicate indexing)
                        $functionFile = Join-Path $DestinationFolder "$functionName.ps1"

                        Set-Content -Path $functionFile -Value $fullText -Encoding UTF8
                        Write-Output "Extracted: $functionName -> $functionFile"
                    }
                }

                # Remove the original file after extraction
                Remove-Item -Path $FilePath -Force
                Write-Output "Removed original file: $FilePath"
            }
    }
}
