function Add-PodeFileWatcher
{
    [CmdletBinding(DefaultParameterSetName='Script')]
    param(
        [Parameter()]
        [string]
        $Name = $null,

        [Parameter()]
        [ValidateSet('Changed', 'Created', 'Deleted', 'Renamed', 'Existed', '*')]
        [string[]]
        $EventName = '*',

        [Parameter(Mandatory=$true)]
        [string]
        $Path,

        [Parameter(Mandatory=$true, ParameterSetName='Script')]
        [scriptblock]
        $ScriptBlock,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
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

    # set random name
    if ([string]::IsNullOrEmpty($Name)) {
        $Name = New-PodeGuid -Secure
    }

    # set all for * event
    if ('*' -iin $EventName) {
        $EventName = @('Changed', 'Created', 'Deleted', 'Renamed')
    }

    # resolve path if relative
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot -Resolve

    # resolve path, and test it
    $hasPlaceholders = Test-PodePlaceholders -Path $Path
    if ($hasPlaceholders) {
        $rgxPath = Update-PodeRouteSlashes -Path $Path -NoLeadingSlash
        $rgxPath = Resolve-PodePlaceholders -Path $rgxPath -Slashes
        $Path = $Path -ireplace (Get-PodePlaceholderRegex), '*'
    }

    # test path to make sure it exists
    if (!(Test-PodePath $Path -NoStatus)) {
        throw "The path does not exist: $($Path)"
    }

    # test if we have the file watcher already
    if (Test-PodeFileWatcher -Name $Name) {
        throw "A File Watcher with the name '$($Name)' has already been defined"
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

    $watchers = @(foreach ($p in $paths) {
        @{
            Path = $p
            Watcher = $null
        }
    })

    # add the file watcher
    $PodeContext.Fim.Items[$Name] = @{
        Name = $Name
        Events = @($EventName)
        Path = $Path
        Placeholders = @{
            Path = $rgxPath
            Exist = $hasPlaceholders
        }
        Script = $ScriptBlock
        UsingVariables = $usingVars
        Arguments = $ArgumentList
        NotifyFilters = @($NotifyFilter)
        IncludeSubdirectories = !$NoSubdirectories.IsPresent
        InternalBufferSize = $InternalBufferSize
        Exclude = (Convert-PodePathPatternsToRegex -Paths @($Exclude))
        Include = (Convert-PodePathPatternsToRegex -Paths @($Include))
        Watchers = $watchers
    }

    # return?
    if ($PassThru) {
        return $PodeContext.Fim.Items[$Name]
    }
}

function Test-PodeFileWatcher
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    return (($null -ne $PodeContext.Fim.Items) -and $PodeContext.Fim.Items.ContainsKey($Name))
}

function Get-PodeFileWatcher
{
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

function Remove-PodeFileWatcher
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $null = $PodeContext.Fim.Items.Remove($Name)
}

function Clear-PodeFileWatchers
{
    [CmdletBinding()]
    param()

    $PodeContext.Fim.Items.Clear()
}

function Use-PodeFileWatchers
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Path
    )

    Use-PodeFolder -Path $Path -DefaultPath 'filewatchers'
}
