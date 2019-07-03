function Await
{
    param (
        [Parameter(Mandatory=$true)]
        [System.Threading.Tasks.Task]
        $Task
    )

    # is there a cancel token to supply?
    if ($null -eq $PodeContext -or $null -eq $PodeContext.Tokens.Cancellation.Token) {
        $Task.Wait()
    }
    else {
        $Task.Wait($PodeContext.Tokens.Cancellation.Token)
    }

    # only return a value if the result has one
    if ($null -ne $Task.Result) {
        return $Task.Result
    }
}

function Dispose
{
    param (
        [Parameter()]
        [System.IDisposable]
        $InputObject,

        [switch]
        $Close,

        [switch]
        $CheckNetwork
    )

    if ($null -eq $InputObject) {
        return
    }

    try {
        if ($Close) {
            $InputObject.Close()
        }
    }
    catch [exception] {
        if ($CheckNetwork -and (Test-PodeValidNetworkFailure $_.Exception)) {
            return
        }

        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $InputObject.Dispose()
    }
}

function Include
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('p')]
        [string]
        $Path,

        [Parameter()]
        [Alias('d')]
        $Data = @{}
    )

    # default data if null
    if ($null -eq $Data) {
        $Data = @{}
    }

    # add view engine extension
    $ext = Get-PodeFileExtension -Path $Path
    if (Test-Empty $ext) {
        $Path += ".$($PodeContext.Server.ViewEngine.Extension)"
    }

    # only look in the view directory
    $Path = (Join-Path $PodeContext.Server.InbuiltDrives['views'] $Path)

    # test the file path, and set status accordingly
    if (!(Test-PodePath $Path -NoStatus)) {
        throw "File not found at path: $($Path)"
    }

    # run any engine logic
    return (Get-PodeFileContentUsingViewEngine -Path $Path -Data $Data)
}

function Lock
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [object]
        $InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    if ($null -eq $InputObject) {
        return
    }

    if ($InputObject.GetType().IsValueType) {
        throw 'Cannot lock value types'
    }

    $locked = $false

    try {
        [System.Threading.Monitor]::Enter($InputObject.SyncRoot)
        $locked = $true

        if ($ScriptBlock -ne $null) {
            Invoke-ScriptBlock -ScriptBlock $ScriptBlock -NoNewClosure
        }
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        if ($locked) {
            [System.Threading.Monitor]::Pulse($InputObject.SyncRoot)
            [System.Threading.Monitor]::Exit($InputObject.SyncRoot)
        }
    }
}

function Root
{
    return $PodeContext.Server.Root
}

function Save
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('p')]
        [string]
        $Path = '.'
    )

    # if path is '.', replace with server root
    $Path = Get-PodeRelativePath -Path $Path -JoinRoot

    # ensure the parameter name exists in data
    $fileName = $WebEvent.Data[$Name]
    if ([string]::IsNullOrWhiteSpace($fileName)) {
        throw "A parameter called '$($Name)' was not supplied in the request"
    }

    # ensure the file data exists
    if (!$WebEvent.Files.ContainsKey($fileName)) {
        throw "No data for file '$($fileName)' was uploaded in the request"
    }

    # if the path is a directory, add the filename
    if (Test-PodePathIsDirectory -Path $Path) {
        $Path = Join-Path $Path $fileName
    }

    # save the file
    [System.IO.File]::WriteAllBytes($Path, $WebEvent.Files[$fileName].Bytes)
}

function State
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('set', 'get', 'remove', 'save', 'restore')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('n')]
        [string]
        $Name,

        [Parameter()]
        [Alias('o')]
        [object]
        $Object
    )

    try {
        if ($null -eq $PodeContext -or $null -eq $PodeContext.Server.State) {
            return $null
        }

        switch ($Action.ToLowerInvariant())
        {
            'set' {
                $PodeContext.Server.State[$Name] = $Object
            }

            'get' {
                $Object = $PodeContext.Server.State[$Name]
            }

            'remove' {
                $Object = $PodeContext.Server.State[$Name]
                $PodeContext.Server.State.Remove($Name) | Out-Null
            }

            'save' {
                $Path = Get-PodeRelativePath -Path $Name -JoinRoot
                $PodeContext.Server.State |
                    ConvertTo-Json -Depth 10 |
                    Out-File -FilePath $Path -Force |
                    Out-Null
                return
            }

            'restore' {
                $Path = Get-PodeRelativePath -Path $Name -JoinRoot
                if (!(Test-Path $Path)) {
                    return
                }

                if (Test-IsPSCore) {
                    $PodeContext.Server.State = (Get-Content $Path -Force | ConvertFrom-Json -AsHashtable -Depth 10)
                }
                else {
                    (Get-Content $Path -Force | ConvertFrom-Json).psobject.properties | ForEach-Object {
                        $PodeContext.Server.State[$_.Name] = $_.Value
                    }
                }

                return
            }
        }

        return $Object
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
}

function Stopwatch
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    try {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        . $ScriptBlock
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $watch.Stop()
        Out-Default -InputObject "[Stopwatch]: $($watch.Elapsed) [$($Name)]"
    }
}

function Stream
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [System.IDisposable]
        $InputObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [scriptblock]
        $ScriptBlock
    )

    try {
        return (Invoke-ScriptBlock -ScriptBlock $ScriptBlock -Arguments $InputObject -Return -NoNewClosure)
    }
    catch {
        $Error[0] | Out-Default
        throw $_.Exception
    }
    finally {
        $InputObject.Dispose()
    }
}

function Tcp
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('write', 'read')]
        [Alias('a')]
        [string]
        $Action,

        [Parameter()]
        [Alias('m')]
        [string]
        $Message,

        [Parameter()]
        [Alias('c')]
        $Client
    )

    # error if serverless
    Test-PodeIsServerless -FunctionName 'tcp' -ThrowError

    # use the main client if one isn't supplied
    if ($null -eq $Client) {
        $Client = $TcpEvent.Client
    }

    switch ($Action.ToLowerInvariant())
    {
        'write' {
            $encoder = New-Object System.Text.ASCIIEncoding
            $buffer = $encoder.GetBytes("$($Message)`r`n")
            $stream = $Client.GetStream()
            await $stream.WriteAsync($buffer, 0, $buffer.Length)
            $stream.Flush()
        }

        'read' {
            $bytes = New-Object byte[] 8192
            $encoder = New-Object System.Text.ASCIIEncoding
            $stream = $Client.GetStream()
            $bytesRead = (await $stream.ReadAsync($bytes, 0, 8192))
            return $encoder.GetString($bytes, 0, $bytesRead)
        }
    }
}

function Pode
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('init', 'test', 'start', 'install', 'build')]
        [Alias('a')]
        [string]
        $Action,

        [switch]
        [Alias('d')]
        $Dev
    )

    # default config file name and content
    $file = './package.json'
    $name = Split-Path -Leaf -Path $pwd
    $data = $null

    # default config data that's used to populate on init
    $map = @{
        'name' = $name;
        'version' = '1.0.0';
        'description' = '';
        'main' = './server.ps1';
        'scripts' = @{
            'start' = './server.ps1';
            'install' = 'yarn install --force --ignore-scripts --modules-folder pode_modules';
            "build" = 'psake';
            'test' = 'invoke-pester ./tests/*.ps1'
        };
        'author' = '';
        'license' = 'MIT';
    }

    # check and load config if already exists
    if (Test-Path $file) {
        $data = (Get-Content $file | ConvertFrom-Json)
    }

    # quick check to see if the data is required
    if ($Action -ine 'init') {
        if ($null -eq $data) {
            Write-Host 'package.json file not found' -ForegroundColor Red
            return
        }
        else {
            $actionScript = $data.scripts.$Action

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ieq 'start') {
                $actionScript = $data.main
            }

            if ([string]::IsNullOrWhiteSpace($actionScript) -and $Action -ine 'install') {
                Write-Host "package.json does not contain a script for the $($Action) action" -ForegroundColor Yellow
                return
            }
        }
    }
    else {
        if ($null -ne $data) {
            Write-Host 'package.json already exists' -ForegroundColor Yellow
            return
        }
    }

    switch ($Action.ToLowerInvariant())
    {
        'init' {
            $v = Read-Host -Prompt "name ($($map.name))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.name = $v }

            $v = Read-Host -Prompt "version ($($map.version))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.version = $v }

            $map.description = Read-Host -Prompt "description"

            $v = Read-Host -Prompt "entry point ($($map.main))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.main = $v; $map.scripts.start = $v }

            $map.author = Read-Host -Prompt "author"

            $v = Read-Host -Prompt "license ($($map.license))"
            if (![string]::IsNullOrWhiteSpace($v)) { $map.license = $v }

            $map | ConvertTo-Json -Depth 10 | Out-File -FilePath $file -Encoding utf8 -Force
            Write-Host 'Success, saved package.json' -ForegroundColor Green
        }

        'test' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'start' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'install' {
            if ($Dev) {
                Install-PodeLocalModules -Modules $data.devModules
            }

            Install-PodeLocalModules -Modules $data.modules
            Invoke-PodePackageScript -ActionScript $actionScript
        }

        'build' {
            Invoke-PodePackageScript -ActionScript $actionScript
        }
    }
}