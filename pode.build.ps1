[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUSeDeclaredVarsMoreThanAssignments', '')]
param(
    [string]
    $Version = '0.0.0',

    [string]
    [ValidateSet('None', 'Normal' , 'Detailed', 'Diagnostic')]
    $PesterVerbosity = 'Normal',

    [string]
    $PowerShellVersion = 'lts',

    [string]
    $ReleaseNoteVersion,

    [string]
    $UICulture = 'en-US'
)

# Fix for PS7.5 Preview - https://github.com/PowerShell/PowerShell/issues/23868
$ProgressPreference = 'SilentlyContinue'

<#
# Dependency Versions
#>
$Versions = @{
    Pester      = '5.6.1'
    MkDocs      = '1.6.0'
    PSCoveralls = '1.0.0'
    SevenZip    = '18.5.0.20180730'
    DotNet      = '8.0'
    MkDocsTheme = '9.5.23'
    PlatyPS     = '0.14.2'
}

<#
# Helper Functions
#>
function Test-PodeBuildIsWindows {
    $v = $PSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}

function Test-PodeBuildIsGitHub {
    return (![string]::IsNullOrWhiteSpace($env:GITHUB_REF))
}

function Test-PodeBuildCanCodeCoverage {
    return (@('1', 'true') -icontains $env:PODE_RUN_CODE_COVERAGE)
}

function Get-PodeBuildService {
    return 'github-actions'
}

function Test-PodeBuildCommand($cmd) {
    $path = $null

    if (Test-PodeBuildIsWindows) {
        $path = (Get-Command $cmd -ErrorAction Ignore)
    }
    else {
        $path = (which $cmd)
    }

    return (![string]::IsNullOrWhiteSpace($path))
}

function Get-PodeBuildBranch {
    return ($env:GITHUB_REF -ireplace 'refs\/heads\/', '')
}

function Invoke-PodeBuildInstall($name, $version) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (Test-PodeBuildIsWindows) {
        if (Test-PodeBuildCommand 'choco') {
            choco install $name --version $version -y --no-progress
        }
    }
    else {
        if (Test-PodeBuildCommand 'brew') {
            brew install $name
        }
        elseif (Test-PodeBuildCommand 'apt-get') {
            sudo apt-get install $name -y
        }
        elseif (Test-PodeBuildCommand 'yum') {
            sudo yum install $name -y
        }
    }
}

function Install-PodeBuildModule($name) {
    if ($null -ne ((Get-Module -ListAvailable $name) | Where-Object { $_.Version -ieq $Versions[$name] })) {
        return
    }

    Write-Host "Installing $($name) v$($Versions[$name])"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-Module -Name "$($name)" -Scope CurrentUser -RequiredVersion "$($Versions[$name])" -Force -SkipPublisherCheck
}

function Invoke-PodeBuildDotnetBuild($target) {
    # Retrieve the highest installed SDK version
    $majorVersion = ([version](dotnet --version)).Major

    # Determine if the target framework is compatible
    $isCompatible = $False
    switch ($majorVersion) {
        8 { if ($target -in @('net6.0', 'netstandard2.0', 'net8.0')) { $isCompatible = $True } }
        7 { if ($target -in @('net6.0', 'netstandard2.0')) { $isCompatible = $True } }
        6 { if ($target -in @('net6.0', 'netstandard2.0')) { $isCompatible = $True } }
    }

    # Skip build if not compatible
    if ($isCompatible) {
        Write-Host "SDK for target framework $target is compatible with the installed SDKs"
    }
    else {
        Write-Host "SDK for target framework $target is not compatible with the installed SDKs. Skipping build."
        return
    }
    if ($Version) {
        Write-Host "Assembly Version $Version"
        $AssemblyVersion = "-p:Version=$Version"
    }
    else {
        $AssemblyVersion = ''
    }

    dotnet publish --configuration Release --self-contained --framework $target $AssemblyVersion --output ../Libs/$target
    if (!$?) {
        throw "dotnet publish failed for $($target)"
    }

}

function Get-PodeBuildPwshEOL {
    $eol = Invoke-RestMethod -Uri 'https://endoflife.date/api/powershell.json' -Headers @{ Accept = 'application/json' }
    return @{
        eol       = ($eol | Where-Object { [datetime]$_.eol -lt [datetime]::Now }).cycle -join ','
        supported = ($eol | Where-Object { [datetime]$_.eol -ge [datetime]::Now }).cycle -join ','
    }
}

function Test-PodeBuildOSWindows {
    return ($IsWindows -or
        ![string]::IsNullOrEmpty($env:ProgramFiles) -or
        (($PSVersionTable.Keys -contains 'PSEdition') -and ($PSVersionTable.PSEdition -eq 'Desktop')))
}

function Get-PodeBuildOSPwshName {
    if (Test-PodeBuildOSWindows) {
        return 'win'
    }

    if ($IsLinux) {
        return 'linux'
    }

    if ($IsMacOS) {
        return 'osx'
    }
}

function Get-PodeBuildOSPwshArchitecture {
    $arch = [string]::Empty

    # windows
    if (Test-PodeBuildOSWindows) {
        $arch = $env:PROCESSOR_ARCHITECTURE
    }

    # unix
    if ($IsLinux -or $IsMacOS) {
        $arch = uname -m
    }

    Write-Host "OS Architecture: $($arch)"

    # convert to pwsh arch
    switch ($arch.ToLowerInvariant()) {
        'amd64' { return 'x64' }
        'x86' { return 'x86' }
        'x86_64' { return 'x64' }
        'armv7*' { return 'arm32' }
        'aarch64*' { return 'arm64' }
        'arm64' { return 'arm64' }
        'arm64*' { return 'arm64' }
        'armv8*' { return 'arm64' }
        default { throw "Unsupported architecture: $($arch)" }
    }
}

function Convert-PodeBuildOSPwshTagToVersion {
    $result = Invoke-RestMethod -Uri "https://aka.ms/pwsh-buildinfo-$($PowerShellVersion)"
    return $result.ReleaseTag -ireplace '^v'
}

function Install-PodeBuildPwshWindows($target) {
    $installFolder = "$($env:ProgramFiles)\PowerShell\7"

    if (Test-Path $installFolder) {
        Remove-Item $installFolder -Recurse -Force -ErrorAction Stop
    }

    Copy-Item -Path "$($target)\" -Destination "$($installFolder)\" -Recurse -ErrorAction Stop
}

function Install-PodeBuildPwshUnix($target) {
    $targetFullPath = Join-Path -Path $target -ChildPath 'pwsh'
    $null = chmod 755 $targetFullPath

    $symlink = $null
    if ($IsMacOS) {
        $symlink = '/usr/local/bin/pwsh'
    }
    else {
        $symlink = '/usr/bin/pwsh'
    }

    $uid = id -u
    if ($uid -ne '0') {
        $sudo = 'sudo'
    }
    else {
        $sudo = ''
    }

    # Make symbolic link point to installed path
    & $sudo ln -fs $targetFullPath $symlink
}

function Get-PodeBuildCurrentPwshVersion {
    return ("$(pwsh -v)" -split ' ')[1].Trim()
}

function Invoke-PodeBuildDockerBuild($tag, $file) {
    docker build -t badgerati/pode:$tag -f $file .
    if (!$?) {
        throw "docker build failed for $($tag)"
    }

    docker tag badgerati/pode:$tag docker.pkg.github.com/badgerati/pode/pode:$tag
    if (!$?) {
        throw "docker tag failed for $($tag)"
    }
}

function Split-PodeBuildPwshPath {
    if (Test-PodeBuildOSWindows) {
        return $env:PSModulePath -split ';'
    }
    else {
        return $env:PSModulePath -split ':'
    }
}


<#
# Helper Tasks
#>

# Synopsis: Stamps the version onto the Module
Task StampVersion {
    $pwshVersions = Get-PodeBuildPwshEOL
    (Get-Content ./pkg/Pode.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version -replace '\$versionsUntested\$', $pwshVersions.eol -replace '\$versionsSupported\$', $pwshVersions.supported -replace '\$buildyear\$', ((get-date).Year) } | Set-Content ./pkg/Pode.psd1
    (Get-Content ./pkg/Pode.Internal.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./pkg/Pode.Internal.psd1
    (Get-Content ./packers/choco/pode_template.nuspec) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/pode.nuspec
    (Get-Content ./packers/choco/tools/ChocolateyInstall_template.ps1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/tools/ChocolateyInstall.ps1
}

# Synopsis: Generating a Checksum of the Zip
Task PrintChecksum {
    $Script:Checksum = (Get-FileHash "./deliverable/$Version-Binaries.zip" -Algorithm SHA256).Hash
    Write-Host "Checksum: $($Checksum)"
}


<#
# Dependencies
#>

# Synopsis: Installs Chocolatey
Task ChocoDeps -If (Test-PodeBuildIsWindows) {
    if (!(Test-PodeBuildCommand 'choco')) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

# Synopsis: Install dependencies for packaging
Task PackDeps -If (Test-PodeBuildIsWindows) ChocoDeps, {
    if (!(Test-PodeBuildCommand '7z')) {
        Invoke-PodeBuildInstall '7zip' $Versions.SevenZip
    }
}

# Synopsis: Install dependencies for compiling/building
Task BuildDeps {
    # install dotnet
    if (Test-PodeBuildIsWindows) {
        $dotnet = 'dotnet'
    }
    else {
        $dotnet = "dotnet-sdk-$($Versions.DotNet)"
    }

    if (!(Test-PodeBuildCommand 'dotnet')) {
        Invoke-PodeBuildInstall $dotnet $Versions.DotNet
    }
}

# Synopsis: Install dependencies for running tests
Task TestDeps {
    # install pester
    Install-PodeBuildModule Pester

    # install PSCoveralls
    if (Test-PodeBuildCanCodeCoverage) {
        Install-PodeBuildModule PSCoveralls
    }
}

# Synopsis: Install dependencies for documentation
Task DocsDeps ChocoDeps, {
    # install mkdocs
    if (!(Test-PodeBuildCommand 'mkdocs')) {
        Invoke-PodeBuildInstall 'mkdocs' $Versions.MkDocs
    }

    $_installed = (pip list --format json --disable-pip-version-check | ConvertFrom-Json)
    if (($_installed | Where-Object { $_.name -ieq 'mkdocs-material' -and $_.version -ieq $Versions.MkDocsTheme } | Measure-Object).Count -eq 0) {
        pip install "mkdocs-material==$($Versions.MkDocsTheme)" --force-reinstall --disable-pip-version-check --quiet
    }

    # install platyps
    Install-PodeBuildModule PlatyPS
}


<#
# Building
#>

# Synopsis: Build the .NET Listener
Task Build BuildDeps, {
    if (Test-Path ./src/Libs) {
        Remove-Item -Path ./src/Libs -Recurse -Force | Out-Null
    }

    try {
        Push-Location ./src/Listener
        Invoke-PodeBuildDotnetBuild -target 'netstandard2.0'
        Invoke-PodeBuildDotnetBuild -target 'net6.0'
        Invoke-PodeBuildDotnetBuild -target 'net8.0'
    }
    finally {
        Pop-Location
    }
}


<#
# Packaging
#>

# Synopsis: Creates a Zip of the Module
Task 7Zip -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
    exec { & 7z -tzip a $Version-Binaries.zip ./pkg/* }
}, PrintChecksum


# Synopsis: Creates a Zip of the Module
Task Compress StampVersion, {
    $path = './deliverable'
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }
    # create the pkg dir
    New-Item -Path $path -ItemType Directory -Force | Out-Null
    Compress-Archive -Path './pkg/*' -DestinationPath "$path/$Version-Binaries.zip"
}, PrintChecksum

# Synopsis: Creates a Chocolately package of the Module
Task ChocoPack -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
    exec { choco pack ./packers/choco/pode.nuspec }
    Move-Item -Path "pode.$Version.nupkg" -Destination './deliverable'
}

# Synopsis: Create docker tags
Task DockerPack {
    # check if github and windows, and output warning
    if ((Test-PodeBuildIsGitHub) -and (Test-PodeBuildIsWindows)) {
        Write-Warning 'Docker images are not built on GitHub Windows runners, and Docker is in Windows container only mode. Exiting task.'
        return
    }

    try {
        # Try to get the Docker version to check if Docker is installed
        docker --version
    }
    catch {
        # If Docker is not available, exit the task
        Write-Warning 'Docker is not installed or not available in the PATH. Exiting task.'
        return
    }

    Invoke-PodeBuildDockerBuild -Tag $Version -File './Dockerfile'
    Invoke-PodeBuildDockerBuild -Tag 'latest' -File './Dockerfile'
    Invoke-PodeBuildDockerBuild -Tag "$Version-alpine" -File './alpine.dockerfile'
    Invoke-PodeBuildDockerBuild -Tag 'latest-alpine' -File './alpine.dockerfile'

    if (!(Test-PodeBuildIsGitHub)) {
        Invoke-PodeBuildDockerBuild -Tag "$Version-arm32" -File './arm32.dockerfile'
        Invoke-PodeBuildDockerBuild -Tag 'latest-arm32' -File './arm32.dockerfile'
    }
    else {
        Write-Warning 'Docker images for ARM32 are not built on GitHub runners due to having the wrong OS architecture. Skipping.'
    }
}

# Synopsis: Package up the Module
Task Pack Build, {
    $path = './pkg'
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }

    # create the pkg dir
    New-Item -Path $path -ItemType Directory -Force | Out-Null

    # which source folders do we need? create them and copy their contents
    $folders = @('Private', 'Public', 'Misc', 'Libs', 'Locales')
    $folders | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $path $_) -Force | Out-Null
        Copy-Item -Path "./src/$($_)/*" -Destination (Join-Path $path $_) -Force -Recurse | Out-Null
    }

    # which route folders to we need? create them and copy their contents
    $folders = @('licenses')
    $folders | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $path $_) -Force | Out-Null
        Copy-Item -Path "./$($_)/*" -Destination (Join-Path $path $_) -Force -Recurse | Out-Null
    }

    # copy general files
    $files = @('src/Pode.psm1', 'src/Pode.psd1', 'src/Pode.Internal.psm1', 'src/Pode.Internal.psd1', 'LICENSE.txt')
    $files | ForEach-Object {
        Copy-Item -Path "./$($_)" -Destination $path -Force | Out-Null
    }
}, StampVersion, Compress, ChocoPack, DockerPack


<#
# Testing
#>

# Synopsis: Run the tests
Task TestNoBuild TestDeps, {
    $p = (Get-Command Invoke-Pester)
    if ($null -eq $p -or $p.Version -ine $Versions.Pester) {
        Remove-Module Pester -Force -ErrorAction Ignore
        Import-Module Pester -Force -RequiredVersion $Versions.Pester
    }

    # for windows, output current netsh excluded ports
    if (Test-PodeBuildIsWindows) {
        netsh int ipv4 show excludedportrange protocol=tcp | Out-Default
    }
    if ($UICulture -ne ([System.Threading.Thread]::CurrentThread.CurrentUICulture) ) {
        $originalUICulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture
        Write-Output "Original UICulture is $originalUICulture"
        Write-Output "Set UICulture to $UICulture"
        # set new UICulture
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $UICulture
    }
    $Script:TestResultFile = "$($pwd)/TestResults.xml"

    # get default from static property
    $configuration = [PesterConfiguration]::Default
    $configuration.run.path = @('./tests/unit', './tests/integration')
    $configuration.run.PassThru = $true
    $configuration.TestResult.OutputFormat = 'NUnitXml'
    $configuration.Output.Verbosity = $PesterVerbosity
    $configuration.TestResult.OutputPath = $Script:TestResultFile

    # if run code coverage if enabled
    if (Test-PodeBuildCanCodeCoverage) {
        $srcFiles = (Get-ChildItem "$($pwd)/src/*.ps1" -Recurse -Force).FullName
        $configuration.CodeCoverage.Enabled = $true
        $configuration.CodeCoverage.Path = $srcFiles
        $Script:TestStatus = Invoke-Pester -Configuration $configuration
    }
    else {
        $Script:TestStatus = Invoke-Pester -Configuration $configuration
    }
    if ($originalUICulture){
        Write-Output "Restore UICulture to $originalUICulture"
        # restore original UICulture
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $originalUICulture
    }
}, PushCodeCoverage, CheckFailedTests

# Synopsis: Run tests after a build
Task Test Build, TestNoBuild


# Synopsis: Check if any of the tests failed
Task CheckFailedTests {
    if ($TestStatus.FailedCount -gt 0) {
        throw "$($TestStatus.FailedCount) tests failed"
    }
}

# Synopsis: If AppyVeyor or GitHub, push code coverage stats
Task PushCodeCoverage -If (Test-PodeBuildCanCodeCoverage) {
    try {
        $service = Get-PodeBuildService
        $branch = Get-PodeBuildBranch

        Write-Host "Pushing coverage for $($branch) from $($service)"
        $coverage = New-CoverallsReport -Coverage $Script:TestStatus.CodeCoverage -ServiceName $service -BranchName $branch
        Publish-CoverallsReport -Report $coverage -ApiToken $env:PODE_COVERALLS_TOKEN
    }
    catch {
        $_.Exception | Out-Default
    }
}


<#
# Docs
#>

# Synopsis: Run the documentation locally
Task Docs DocsDeps, DocsHelpBuild, {
    mkdocs serve --open
}

# Synopsis: Build the function help documentation
Task DocsHelpBuild DocsDeps, Build, {
    # import the local module
    Remove-Module Pode -Force -ErrorAction Ignore | Out-Null
    Import-Module ./src/Pode.psm1 -Force | Out-Null

    # build the function docs
    $path = './docs/Functions'
    $map = @{}

    (Get-Module Pode).ExportedFunctions.Keys | ForEach-Object {
        $type = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf -Path (Get-Command $_ -Module Pode).ScriptBlock.File))
        New-MarkdownHelp -Command $_ -OutputFolder (Join-Path $path $type) -Force -Metadata @{ PodeType = $type } -AlphabeticParamsOrder | Out-Null
        $map[$_] = $type
    }

    # update docs to bind links to unlinked functions
    $path = Join-Path $pwd 'docs'
    Get-ChildItem -Path $path -Recurse -Filter '*.md' | ForEach-Object {
        $depth = ($_.FullName.Replace($path, [string]::Empty).trim('\/') -split '[\\/]').Length
        $updated = $false

        $content = (Get-Content -Path $_.FullName | ForEach-Object {
                $line = $_

                while ($line -imatch '\[`(?<name>[a-z]+\-pode[a-z]+)`\](?<char>([^(]|$))') {
                    $updated = $true
                    $name = $Matches['name']
                    $char = $Matches['char']
                    $line = ($line -ireplace "\[``$($name)``\]([^(]|$)", "[``$($name)``]($('../' * $depth)Functions/$($map[$name])/$($name))$($char)")
                }

                $line
            })

        if ($updated) {
            $content | Out-File -FilePath $_.FullName -Force -Encoding ascii
        }
    }

    # remove the module
    Remove-Module Pode -Force -ErrorAction Ignore | Out-Null
}

# Synopsis: Build the documentation
Task DocsBuild DocsDeps, DocsHelpBuild, {
    mkdocs build --quiet
}


<#
# Clean-up
#>

# Synopsis: Clean the build enviroment
Task Clean  CleanPkg, CleanDeliverable, CleanLibs, CleanListener

# Synopsis: Clean the Deliverable folder
Task CleanDeliverable {
    $path = './deliverable'
    if (Test-Path -Path $path -PathType Container) {
        Write-Host 'Removing ./deliverable folder'
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }
    Write-Host "Cleanup $path done"
}

# Synopsis: Clean the pkg directory
Task CleanPkg {
    $path = './pkg'
    if ((Test-Path -Path $path -PathType Container )) {
        Write-Host 'Removing ./pkg folder'
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }

    if ((Test-Path -Path .\packers\choco\tools\ChocolateyInstall.ps1 -PathType Leaf )) {
        Write-Host 'Removing .\packers\choco\tools\ChocolateyInstall.ps1'
        Remove-Item -Path .\packers\choco\tools\ChocolateyInstall.ps1
    }

    if ((Test-Path -Path .\packers\choco\pode.nuspec -PathType Leaf )) {
        Write-Host 'Removing .\packers\choco\pode.nuspec'
        Remove-Item -Path .\packers\choco\pode.nuspec
    }

    Write-Host "Cleanup $path done"
}

# Synopsis: Clean the libs folder
Task CleanLibs {
    $path = './src/Libs'
    if (Test-Path -Path $path -PathType Container) {
        Write-Host "Removing $path  contents"
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }

    Write-Host "Cleanup $path done"
}

# Synopsis: Clean the Listener folder
Task CleanListener {
    $path = './src/Listener/bin'
    if (Test-Path -Path $path -PathType Container) {
        Write-Host "Removing $path contents"
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }

    Write-Host "Cleanup $path done"
}


<#
# Local module management
#>

# Synopsis: Install Pode Module locally
Task Install-Module -If ($Version) Pack, {
    $PSPaths = Split-PodeBuildPwshPath

    $dest = Join-Path -Path $PSPaths[0] -ChildPath 'Pode' -AdditionalChildPath "$Version"
    if (Test-Path $dest) {
        Remove-Item -Path $dest -Recurse -Force | Out-Null
    }

    # create the dest dir
    New-Item -Path $dest -ItemType Directory -Force | Out-Null
    $path = './pkg'

    # copy over folders
    $folders = @('Private', 'Public', 'Misc', 'Libs', 'licenses', 'Locales')
    $folders | ForEach-Object {
        Copy-Item -Path (Join-Path -Path $path -ChildPath $_) -Destination $dest -Force -Recurse | Out-Null
    }

    # copy over general files
    $files = @('Pode.psm1', 'Pode.psd1', 'Pode.Internal.psm1', 'Pode.Internal.psd1', 'LICENSE.txt')
    $files | ForEach-Object {
        Copy-Item -Path (Join-Path -Path $path -ChildPath $_) -Destination $dest -Force | Out-Null
    }

    Write-Host "Deployed to $dest"
}

# Synopsis: Remove the Pode Module from the local registry
Task Remove-Module {
    if (!$Version) {
        throw 'Parameter -Version is required'
    }

    $PSPaths = Split-PodeBuildPwshPath

    $dest = Join-Path -Path $PSPaths[0] -ChildPath 'Pode' -AdditionalChildPath "$Version"
    if (!(Test-Path $dest)) {
        Write-Warning "Directory $dest doesn't exist"
    }

    Write-Host "Deleting module from $dest"
    Remove-Item -Path $dest -Recurse -Force | Out-Null
}


<#
# PowerShell setup
#>

# Synopsis: Setup the PowerShell environment
Task SetupPowerShell {
    # code for this step is altered versions of the code found here:
    # - https://github.com/bjompen/UpdatePWSHAction/blob/main/UpgradePwsh.ps1
    # - https://raw.githubusercontent.com/PowerShell/PowerShell/master/tools/install-powershell.ps1

    # fail if no version supplied
    if ([string]::IsNullOrWhiteSpace($PowerShellVersion)) {
        throw 'No PowerShell version supplied to set up'
    }

    # is the version valid?
    $tags = @('preview', 'lts', 'daily', 'stable')
    if (($PowerShellVersion -inotin $tags) -and ($PowerShellVersion -inotmatch '^\d+\.\d+\.\d+(-\w+(\.\d+)?)?$')) {
        throw "Invalid PowerShell version supplied: $($PowerShellVersion)"
    }

    # tag version or literal version?
    $isTagVersion = $PowerShellVersion -iin $tags
    if ($isTagVersion) {
        Write-Host "Release tag: $($PowerShellVersion)"
        $PowerShellVersion = Convert-PodeBuildOSPwshTagToVersion
    }
    Write-Host "Release version: $($PowerShellVersion)"

    # base/prefix versions
    $atoms = $PowerShellVersion -split '\-'
    $baseVersion = $atoms[0]

    # do nothing if the current version is the version we're trying to set up
    $currentVersion = Get-PodeBuildCurrentPwshVersion
    Write-Host "Current PowerShell version: $($currentVersion)"

    if ($baseVersion -ieq $currentVersion) {
        Write-Host "PowerShell version $($PowerShellVersion) is already installed"
        return
    }

    # build the package name
    $arch = Get-PodeBuildOSPwshArchitecture
    $os = Get-PodeBuildOSPwshName

    $packageName = (@{
            win   = "PowerShell-$($PowerShellVersion)-$($os)-$($arch).zip"
            linux = "powershell-$($PowerShellVersion)-$($os)-$($arch).tar.gz"
            osx   = "powershell-$($PowerShellVersion)-$($os)-$($arch).tar.gz"
        })[$os]

    # build the blob name
    $blobName = "v$($PowerShellVersion -replace '\.', '-')"

    # download the package to a temp location
    $outputFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $packageName
    $downloadParams = @{
        Uri         = "https://pscoretestdata.blob.core.windows.net/$($blobName)/$($packageName)"
        OutFile     = $outputFile
        ErrorAction = 'Stop'
    }

    Write-Host "Downloading $($packageName) from $($downloadParams.Uri)"
    Write-Host "Output file: $($outputFile)"

    # retry the download 3 times, with a sleep of 10s between each attempt
    $counter = 0
    $success = $false

    do {
        try {
            $counter++
            Write-Host "Attempt $($counter) of 3"

            Invoke-WebRequest @downloadParams

            $success = $true
            Write-Host "Downloaded $($packageName) successfully"
        }
        catch {
            $success = $false
            if ($counter -ge 3) {
                throw "Failed to download PowerShell package after 3 attempts. Error: $($_.Exception.Message)"
            }

            Start-Sleep -Seconds 10
        }
    } while (!$success)

    # create target folder for package
    $targetFolder = Join-Path -Path (Resolve-Path ~).Path -ChildPath ($packageName -ireplace '\.tar$')
    if (!(Test-Path $targetFolder)) {
        $null = New-Item -Path $targetFolder -ItemType Directory -Force
    }

    # extract the package
    switch ($os) {
        'win' {
            Expand-Archive -Path $outputFile -DestinationPath $targetFolder -Force
        }

        { $_ -iin 'linux', 'osx' } {
            $null = tar -xzf $outputFile -C $targetFolder
        }
    }

    # install the package
    Write-Host "Installing PowerShell $($PowerShellVersion) to $($targetFolder)"
    if (Test-PodeBuildOSWindows) {
        Install-PodeBuildPwshWindows -Target $targetFolder
    }
    else {
        Install-PodeBuildPwshUnix -Target $targetFolder
    }
}


<#
# Release Notes
#>

# Synopsis: Build the Release Notes
task ReleaseNotes {
    if ([string]::IsNullOrWhiteSpace($ReleaseNoteVersion)) {
        Write-Host 'Please provide a ReleaseNoteVersion' -ForegroundColor Red
        return
    }

    # get the PRs for the ReleaseNoteVersion
    $prs = gh search prs --milestone $ReleaseNoteVersion --repo badgerati/pode --merged --limit 200 --json 'number,title,labels,author' | ConvertFrom-Json

    # group PRs into categories, filtering out some internal PRs
    $categories = [ordered]@{
        Features      = @()
        Enhancements  = @()
        Bugs          = @()
        Documentation = @()
    }

    $dependabot = @{}

    foreach ($pr in $prs) {
        $label = ($pr.labels[0].name -split ' ')[0]
        if ($label -iin @('new-release', 'internal-code')) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($label)) {
            $label = 'misc'
        }

        switch ($label.ToLowerInvariant()) {
            'feature' { $label = 'Features' }
            'enhancement' { $label = 'Enhancements' }
            'bug' { $label = 'Bugs' }
        }

        if (!$categories.Contains($label)) {
            $categories[$label] = @()
        }

        if ($pr.author.login -ilike '*dependabot*') {
            if ($pr.title -imatch 'Bump (?<name>\S+) from (?<from>[0-9\.]+) to (?<to>[0-9\.]+)') {
                if (!$dependabot.ContainsKey($Matches['name'])) {
                    $dependabot[$Matches['name']] = @{
                        Name   = $Matches['name']
                        Number = $pr.number
                        From   = [version]$Matches['from']
                        To     = [version]$Matches['to']
                    }
                }
                else {
                    $item = $dependabot[$Matches['name']]
                    if ([int]$pr.number -gt [int]$item.Number) {
                        $item.Number = $pr.number
                    }
                    if ([version]$Matches['from'] -lt $item.From) {
                        $item.From = [version]$Matches['from']
                    }
                    if ([version]$Matches['to'] -gt $item.To) {
                        $item.To = [version]$Matches['to']
                    }
                }

                continue
            }
        }

        $titles = @($pr.title)
        if ($pr.title.Contains(';')) {
            $titles = ($pr.title -split ';').Trim()
        }

        $author = $null
        if (($pr.author.login -ine 'badgerati') -and ($pr.author.login -inotlike '*dependabot*')) {
            $author = $pr.author.login
        }

        foreach ($title in $titles) {
            $str = "* #$($pr.number): $($title)"
            if (![string]::IsNullOrWhiteSpace($author)) {
                $str += " (thanks @$($author)!)"
            }

            if ($str -imatch '\s+(docs|documentation)\s+') {
                $categories['Documentation'] += $str
            }
            else {
                $categories[$label] += $str
            }
        }
    }

    # add dependabot aggregated PRs
    if ($dependabot.Count -gt 0) {
        $label = 'dependencies'
        if (!$categories.Contains($label)) {
            $categories[$label] = @()
        }

        foreach ($dep in $dependabot.Values) {
            $categories[$label] += "* #$($dep.Number): Bump $($dep.Name) from $($dep.From) to $($dep.To)"
        }
    }

    # output the release notes
    Write-Host "# v$($ReleaseNoteVersion)`n"

    $culture = (Get-Culture).TextInfo
    foreach ($category in $categories.Keys) {
        if ($categories[$category].Length -eq 0) {
            continue
        }

        Write-Host "### $($culture.ToTitleCase($category))"
        $categories[$category] | Sort-Object | ForEach-Object { Write-Host $_ }
        Write-Host ''
    }
}
