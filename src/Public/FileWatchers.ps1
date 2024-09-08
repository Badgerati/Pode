<#
.SYNOPSIS
Adds a new File Watcher to monitor file changes in a directory.

.DESCRIPTION
Adds a new File Watcher to monitor file changes in a directory.

.PARAMETER Name
An optional Name for the File Watcher. (Default: GUID)

.PARAMETER EventName
An optional EventName to be monitored. Note: '*' refers to all event names. (Default: Changed, Created, Deleted, Renamed)

.PARAMETER Path
The Path to a directory which contains the files to be monitored.

.PARAMETER ScriptBlock
The ScriptBlock defining logic to be run when events are triggered.

.PARAMETER FilePath
A literal, or relative, path to a file containing a ScriptBlock for the File Watcher's logic.

.PARAMETER ArgumentList
A hashtable of arguments to supply to the File Watcher's ScriptBlock.

.PARAMETER NotifyFilter
The attributes on files to monitor and notify about. (Default: FileName, DirectoryName, LastWrite, CreationTime)

.PARAMETER Exclude
An optional array of file patterns to be excluded.

.PARAMETER Include
An optional array of file patterns to be included. (Default: *.*)

.PARAMETER InternalBufferSize
The InternalBufferSize of the file monitor, used when temporarily storing events. (Default: 8kb)

.PARAMETER NoSubdirectories
If supplied, the File Watcher will only monitor files in the specified directory path, and not in all sub-directories as well.

.PARAMETER PassThru
If supplied, the File Watcher object registered will be returned.

.EXAMPLE
Add-PodeFileWatcher -Path 'C:/Projects/:project/src' -Include '*.ps1' -ScriptBlock {}

.EXAMPLE
Add-PodeFileWatcher -Path 'C:/Websites/:site' -Include '*.config' -EventName Changed -ScriptBlock {}

.EXAMPLE
Add-PodeFileWatcher -Path '/temp/logs' -EventName Created -NotifyFilter CreationTime -ScriptBlock {}

.EXAMPLE
$watcher = Add-PodeFileWatcher -Path '/temp/logs' -Exclude *.txt -ScriptBlock {} -PassThru
#>
function Add-PodeFileWatcher {
    [CmdletBinding(DefaultParameterSetName = 'Script')]
    param(
        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [ValidateSet('Changed', 'Created', 'Deleted', 'Renamed', 'Existed', '*')]
        [string[]]
        $EventName = @('Changed', 'Created', 'Deleted', 'Renamed'),

        [Parameter(Mandatory = $true)]
        [string]
        $Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]
        $FilePath,

        [Parameter()]
        [object[]]
        $ArgumentList,

        [Parameter()]
        [System.IO.NotifyFilters[]]
        $NotifyFilter = @('FileName', 'DirectoryName', 'LastWrite', 'CreationTime'),

        [Parameter()]
        [string[]]
        $Exclude,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Include = '*.*',

        [Parameter()]
        [ValidateRange(4kb, 64kb)]
        [int]
        $InternalBufferSize = 8kb,

        [switch]
        $NoSubdirectories,

        [switch]
        $PassThru
    )

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    # set random name
    if ([string]::IsNullOrEmpty($Name)) {
        $Name = New-PodeGuid -Secure
    }

    # set all for * event
    if ('*' -iin $EventName) {
        $EventName = @('Changed', 'Created', 'Deleted', 'Renamed', 'Existed')
    }

    # resolve path if relative
    if (!(Test-PodeIsPSCore)) {
        $Path = Convert-PodePlaceholder -Path $Path -Prepend '%' -Append '%'
    }

    $Path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

    if (!(Test-PodeIsPSCore)) {
        $Path = Convert-PodePlaceholder -Path $Path -Pattern '\%(?<tag>[\w]+)\%' -Prepend ':' -Append ([string]::Empty)
    }

    # resolve path, and test it
    $hasPlaceholders = Test-PodePlaceholder -Path $Path
    if ($hasPlaceholders) {
        $rgxPath = Update-PodeRouteSlash -Path $Path -NoLeadingSlash
        $rgxPath = Resolve-PodePlaceholder -Path $rgxPath -Slashes
        $Path = $Path -ireplace (Get-PodePlaceholderRegex), '*'
    }

    # test path to make sure it exists
    if (!(Test-PodePath $Path -NoStatus)) {
        # Path does not exist
        throw ($PodeLocale.pathNotExistExceptionMessage -f $Path)
    }

    # test if we have the file watcher already
    if (Test-PodeFileWatcher -Name $Name) {
        # A File Watcher named has already been defined
        throw ($PodeLocale.fileWatcherAlreadyDefinedExceptionMessage -f $Name)
    }

    # if we have a file path supplied, load that path as a scriptblock
    if ($PSCmdlet.ParameterSetName -ieq 'file') {
        $ScriptBlock = Convert-PodeFileToScriptBlock -FilePath $FilePath
    }

    # check for scoped vars
    $ScriptBlock, $usingVars = Convert-PodeScopedVariables -ScriptBlock $ScriptBlock -PSSession $PSCmdlet.SessionState

    # enable the file watcher threads
    $PodeContext.Fim.Enabled = $true

    # resolve the path's widacards if any
    $paths = @($Path)
    if ($Path.Contains('*')) {
        $paths = @(Get-ChildItem -Path $Path -Directory -Force | Select-Object -ExpandProperty FullName)
    }

    # add the file watcher
    $PodeContext.Fim.Items[$Name] = @{
        Name                  = $Name
        Events                = @($EventName)
        Path                  = $Path
        Placeholders          = @{
            Path  = $rgxPath
            Exist = $hasPlaceholders
        }
        Script                = $ScriptBlock
        UsingVariables        = $usingVars
        Arguments             = $ArgumentList
        NotifyFilters         = @($NotifyFilter)
        IncludeSubdirectories = !$NoSubdirectories.IsPresent
        InternalBufferSize    = $InternalBufferSize
        Exclude               = $Exclude
        Include               = $Include
        Paths                 = $paths
    }

    # return?
    if ($PassThru) {
        return $PodeContext.Fim.Items[$Name]
    }
}

<#
.SYNOPSIS
Tests whether the passed File Watcher exists.

.DESCRIPTION
Tests whether the passed File Watcher exists by its name.

.PARAMETER Name
The Name of the File Watcher.

.EXAMPLE
if (Test-PodeFileWatcher -Name WatcherName) { }
#>
function Test-PodeFileWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Fim.Items) -and $PodeContext.Fim.Items.ContainsKey($Name))
}

<#
.SYNOPSIS
Returns any defined File Watchers.

.DESCRIPTION
Returns any defined File Watchers.

.PARAMETER Name
An optional File Watcher Name(s) to be returned.

.EXAMPLE
Get-PodeFileWatcher

.EXAMPLE
Get-PodeFileWatcher -Name Name1, Name2
#>
function Get-PodeFileWatcher {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]
        $Name
    )

    $watchers = $PodeContext.Fim.Items.Values

    # further filter by file watcher names
    if (($null -ne $Name) -and ($Name.Length -gt 0)) {
        $watchers = @(foreach ($_name in $Name) {
                foreach ($watcher in $watchers) {
                    if ($watcher.Name -ine $_name) {
                        continue
                    }

                    $watcher
                }
            })
    }

    # return
    return $watchers
}

<#
.SYNOPSIS
Removes a specific File Watchers.

.DESCRIPTION
Removes a specific File Watchers.

.PARAMETER Name
The Name of the File Watcher to be removed.

.EXAMPLE
Remove-PodeFileWatcher -Name 'Logs'
#>
function Remove-PodeFileWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Name
    )

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    $null = $PodeContext.Fim.Items.Remove($Name)
}

<#
.SYNOPSIS
Removes all File Watchers.

.DESCRIPTION
Removes all File Watchers.

.EXAMPLE
Clear-PodeFileWatchers
#>
function Clear-PodeFileWatchers {
    [CmdletBinding()]
    param()

    # Record the operation on the trace log
    Write-PodeTraceLog -Operation $MyInvocation.MyCommand.Name -Parameters $PSBoundParameters

    $PodeContext.Fim.Items.Clear()
}

<#
.SYNOPSIS
Automatically loads File Watchers ps1 files

.DESCRIPTION
Automatically loads File Watchers ps1 files from either a /filewatcher folder, or a custom folder. Saves space dot-sourcing them all one-by-one.

.PARAMETER Path
Optional Path to a folder containing ps1 files, can be relative or literal.

.EXAMPLE
Use-PodeFileWatchers

.EXAMPLE
Use-PodeFileWatchers -Path './my-watchers'
#>
function Use-PodeFileWatchers {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'filewatchers'
}