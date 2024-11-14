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
    $UICulture = 'en-US',

    [string[]]
    [ValidateSet('netstandard2.0', 'netstandard2.1', 'netcoreapp3.0', 'netcoreapp3.1', 'net5.0', 'net6.0', 'net7.0', 'net8.0', 'net9.0', 'net10.0')]
    $TargetFrameworks,

    [string]
    [ValidateSet('netstandard2.0', 'netstandard2.1', 'netcoreapp3.0', 'netcoreapp3.1', 'net5.0', 'net6.0', 'net7.0', 'net8.0', 'net9.0', 'net10.0')]
    $SdkVersion
)


# Check if the script is running under Invoke-Build
if (($null -ne $PSCmdlet.MyInvocation) -and ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('BuildRoot') -or $null -ne $BuildRoot)) {

    # Dependency Versions
    $Versions = @{
        Pester      = '5.6.1'
        MkDocs      = '1.6.1'
        PSCoveralls = '1.0.0'
        SevenZip    = '18.5.0.20180730'
        DotNet      = @($(if ($null -eq $TargetFrameworks) { 'auto' } else { $TargetFrameworks }))
        MkDocsTheme = '9.5.44'
        PlatyPS     = '0.14.2'
    }


    # Helper Functions
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

    function Get-TargetFramework {
        param(
            [string]
            $TargetFrameworks
        )

        switch ($TargetFrameworks) {
            'netstandard2.0' { return  2 }
            'netstandard2.1' { return  3 }
            'netcoreapp3.0' { return  3 }
            'net5.0' { return  5 }
            'net6.0' { return  6 }
            'net7.0' { return  7 }
            'net8.0' { return 8 }
            'net9.0' { return  9 }
            default {
                Write-Warning "$TargetFrameworks is not a valid  Framework. Rollback to netstandard2.0"
                return 2
            }
        }
    }


    function Get-TargetFrameworkName {
        param(
            $Version
        )

        switch ( $Version) {
            '2' { return 'netstandard2.0' }
            '3' { return 'netstandard2.1' }
            '5' { return  'net5.0' }
            '6' { return  'net6.0' }
            '7' { return  'net7.0' }
            '8' { return  'net8.0' }
            '9' { return 'net9.0' }
            default {
                Write-Warning "$Version is not a valid  Framework. Rollback to netstandard2.0"
                return 'netstandard2.0'
            }
        }
    }

    function Invoke-PodeBuildDotnetBuild {
        param (
            [string]$target
        )

        # Retrieve the installed SDK versions
        $sdkVersions = dotnet --list-sdks | ForEach-Object { $_.Split('[')[0].Trim() }
        if ([string]::IsNullOrEmpty($AvailableSdkVersion)) {
            $majorVersions = $sdkVersions | ForEach-Object { ([version]$_).Major } | Sort-Object -Descending | Select-Object -Unique
        }
        else {
            $majorVersions = $sdkVersions.Where( { ([version]$_).Major -ge (Get-TargetFramework -TargetFrameworks $AvailableSdkVersion) } ) | Sort-Object -Descending | Select-Object -Unique
        }
        # Map target frameworks to minimum SDK versions

        if ($null -eq $majorVersions) {
            Write-Error "The requested '$AvailableSdkVersion' framework is not available."
            return
        }
        $requiredSdkVersion = Get-TargetFramework -TargetFrameworks $target

        # Determine if the target framework is compatible
        $isCompatible = $majorVersions -ge $requiredSdkVersion

        if ($isCompatible) {
            Write-Output "SDK for target framework '$target' is compatible with the '$AvailableSdkVersion' framework."
        }
        else {
            Write-Warning "SDK for target framework '$target' is not compatible with the '$AvailableSdkVersion' framework. Skipping build."
            return
        }

        # Optionally set assembly version
        if ($Version) {
            Write-Output "Assembly Version: $Version"
            $AssemblyVersion = "-p:Version=$Version"
        }
        else {
            $AssemblyVersion = ''
        }

        # Use dotnet publish for .NET Core and .NET 5+
        dotnet publish --configuration Release --self-contained --framework $target $AssemblyVersion --output ../Libs/$target

        if (!$?) {
            throw "Build failed for target framework '$target'."
        }
    }

    function Get-PodeBuildPwshEOL {
        $uri = 'https://endoflife.date/api/powershell.json'
        try {
            $eol = Invoke-RestMethod -Uri $uri -Headers @{ Accept = 'application/json' }
            return @{
                eol       = ($eol | Where-Object { [datetime]$_.eol -lt [datetime]::Now }).cycle -join ','
                supported = ($eol | Where-Object { [datetime]$_.eol -ge [datetime]::Now }).cycle -join ','
            }
        }
        catch {
            Write-Warning "Invoke-RestMethod to $uri failed: $($_.ErrorDetails.Message)"
            return  @{
                eol       = ''
                supported = ''
            }
        }
    }


    function Get-PodeBuildDotNetEOL {
        param(
            [switch]
            $LatestVersion
        )
        $uri = 'https://endoflife.date/api/dotnet.json'
        try {
            $eol = Invoke-RestMethod -Uri $uri -Headers @{ Accept = 'application/json' }
            if ($LatestVersion) {
                return (($eol | Where-Object { [datetime]$_.eol -ge [datetime]::Now }).cycle)[0]
            }
            else {
                return @{
                    eol       = ($eol | Where-Object { [datetime]$_.eol -lt [datetime]::Now }).cycle -join ','
                    supported = ($eol | Where-Object { [datetime]$_.eol -ge [datetime]::Now }).cycle -join ','
                }
            }
        }
        catch {
            Write-Warning "Invoke-RestMethod to $uri failed: $($_.ErrorDetails.Message)"
            return  @{
                eol       = ''
                supported = ''
            }
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
    Add-BuildTask StampVersion {
        $pwshVersions = Get-PodeBuildPwshEOL
    (Get-Content ./pkg/Pode.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version -replace '\$versionsUntested\$', $pwshVersions.eol -replace '\$versionsSupported\$', $pwshVersions.supported -replace '\$buildyear\$', ((get-date).Year) } | Set-Content ./pkg/Pode.psd1
    (Get-Content ./pkg/Pode.Internal.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./pkg/Pode.Internal.psd1
    (Get-Content ./packers/choco/pode_template.nuspec) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/pode.nuspec
    (Get-Content ./packers/choco/tools/ChocolateyInstall_template.ps1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/tools/ChocolateyInstall.ps1
    }

    # Synopsis: Generating a Checksum of the Zip
    Add-BuildTask PrintChecksum {
        $Script:Checksum = (Get-FileHash "./deliverable/$Version-Binaries.zip" -Algorithm SHA256).Hash
        Write-Host "Checksum: $($Checksum)"
    }


    <#
# Dependencies
#>

    # Synopsis: Installs Chocolatey
    Add-BuildTask ChocoDeps -If (Test-PodeBuildIsWindows) {
        if (!(Test-PodeBuildCommand 'choco')) {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression ([System.Net.WebClient]::new().DownloadString('https://chocolatey.org/install.ps1'))
        }
    }

    # Synopsis: Install dependencies for packaging
    Add-BuildTask PackDeps -If (Test-PodeBuildIsWindows) ChocoDeps, {
        if (!(Test-PodeBuildCommand '7z')) {
            Invoke-PodeBuildInstall '7zip' $Versions.SevenZip
        }
    }

    # Synopsis: Install dependencies for compiling/building
    Add-BuildTask BuildDeps {
        if ([string]::IsNullOrEmpty($SdkVersion)) {
            $_sdkVersion = Get-PodeBuildDotNetEOL -LatestVersion
        }
        else {
            $_sdkVersion = $SdkVersion
        }

        # install dotnet
        if (Test-PodeBuildIsWindows) {
            $dotnet = 'dotnet'
        }
        elseif (Test-PodeBuildCommand 'brew') {
            $dotnet = 'dotnet-sdk'
        }
        else {
            $dotnet = "dotnet-sdk-$_sdkVersion"
        }

        if (!(Test-PodeBuildCommand 'dotnet')) {
            Invoke-PodeBuildInstall $dotnet $_sdkVersion
        }
        elseif (![string]::IsNullOrEmpty($SdkVersion)) {
            $sdkVersions = dotnet --list-sdks | ForEach-Object { $_.Split('[')[0].Trim() }
            $majorVersions = $sdkVersions | ForEach-Object { ([version]$_).Major } | Sort-Object -Descending | Select-Object -Unique
            if ($majorVersions -lt (Get-TargetFramework -TargetFrameworks $SdkVersion)) {
                Invoke-PodeBuildInstall $dotnet $SdkVersion
                $sdkVersions = dotnet --list-sdks | ForEach-Object { $_.Split('[')[0].Trim() }
                $majorVersions = $sdkVersions | ForEach-Object { ([version]$_).Major } | Sort-Object -Descending | Select-Object -Unique
                if ($majorVersions -lt (Get-TargetFramework -TargetFrameworks $SdkVersion)) {
                    Write-Error "The requested framework '$SdkVersion' is not available."
                    return
                }

            }
            else {
                $script:AvailableSdkVersion = Get-TargetFrameworkName  -Version $majorVersions
                Write-Warning "The requested SDK version '$SdkVersion' is superseded by the installed '$($script:AvailableSdkVersion)' framework."
                return
            }
        }
        $script:AvailableSdkVersion = Get-TargetFrameworkName  -Version $_sdkVersion

    }

    # Synopsis: Install dependencies for running tests
    Add-BuildTask TestDeps {
        # install pester
        Install-PodeBuildModule Pester

        # install PSCoveralls
        if (Test-PodeBuildCanCodeCoverage) {
            Install-PodeBuildModule PSCoveralls
        }
    }

    # Synopsis: Install dependencies for documentation
    Add-BuildTask DocsDeps ChocoDeps, {
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

    Add-BuildTask IndexSamples {
        $examplesPath = './examples'
        if (!(Test-Path -PathType Container -Path $examplesPath)) {
            return
        }

        # List of directories to exclude
        $sampleMarkDownPath = './docs/Getting-Started/Samples.md'
        $excludeDirs = @('scripts', 'views', 'static', 'public', 'assets', 'timers', 'modules',
            'Authentication', 'certs', 'logs', 'relative', 'routes', 'issues')

        # Convert exlusion list into single regex pattern for directory matching
        $dirSeparator = [IO.Path]::DirectorySeparatorChar
        $excludeDirs = "\$($dirSeparator)($($excludeDirs -join '|'))\$($dirSeparator)"

        # build the page content
        Get-ChildItem -Path $examplesPath -Filter *.ps1 -Recurse -File -Force |
            Where-Object {
                $_.FullName -inotmatch $excludeDirs
            } |
            Sort-Object -Property FullName |
            ForEach-Object {
                Write-Verbose "Processing Sample: $($_.FullName)"

                # get the script help
                $help = Get-Help -Name $_.FullName -ErrorAction Stop

                # add help content
                $urlFileName = ($_.FullName -isplit 'examples')[1].Trim('\/') -replace '[\\/]', '/'
                $markdownContent += "## [$($_.BaseName)](https://github.com/Badgerati/Pode/blob/develop/examples/$($urlFileName))`n`n"
                $markdownContent += "**Synopsis**`n`n$($help.Synopsis)`n`n"
                $markdownContent += "**Description**`n`n$($help.Description.Text)`n`n"
            }

        Write-Output "Write Markdown document for the sample files to $($sampleMarkDownPath)"
        Set-Content -Path $sampleMarkDownPath -Value "# Sample Scripts`n`n$($markdownContent)" -Force
    }

    <#
# Building
#>

    # Synopsis: Build the .NET Listener
    Add-BuildTask Build BuildDeps, {
        if (Test-Path ./src/Libs) {
            Remove-Item -Path ./src/Libs -Recurse -Force | Out-Null
        }
        if ($Versions.DotNet -eq 'auto') {
            # Retrieve supported .NET versions
            $eol = Get-PodeBuildDotNetEOL

            $targetFrameworks = @()

            if (![string]::IsNullOrEmpty($eol.supported)) {

                # Parse supported versions into an array
                $supportedVersions = $eol['supported'] -split ','

                # Construct target framework monikers
                $targetFrameworks += ($supportedVersions | ForEach-Object { "net$_.0" })
            }
        }
        else {
            $targetFrameworks = $Versions.DotNet
        }
        # Optionally include netstandard2.0
        $targetFrameworks += 'netstandard2.0'


        # Retrieve the SDK version being used
        #   $dotnetVersion = dotnet --version

        # Display the SDK version
        Write-Output "Building targets '$($targetFrameworks -join "','")' using .NET '$AvailableSdkVersion' framework."

        # Build for supported target frameworks
        try {
            Push-Location ./src/Listener
            foreach ($target in $targetFrameworks) {
                Invoke-PodeBuildDotnetBuild -target $target
                Write-Host
                Write-Host '***********************' -ForegroundColor DarkMagenta

            }
        }
        finally {
            Pop-Location
        }

    }


    <#
# Packaging
#>

    # Synopsis: Creates a Zip of the Module
    Add-BuildTask 7Zip -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
        exec { & 7z -tzip a $Version-Binaries.zip ./pkg/* }
    }, PrintChecksum

    #Synopsis: Create the Deliverable folder
    Add-BuildTask DeliverableFolder {
        $path = './deliverable'
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force | Out-Null
        }

        # create the deliverable dir
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }

    # Synopsis: Creates a Zip of the Module
    Add-BuildTask Compress PackageFolder, StampVersion, DeliverableFolder, {
        $path = './deliverable'
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force | Out-Null
        }
        # create the pkg dir
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Compress-Archive -Path './pkg/*' -DestinationPath "$path/$Version-Binaries.zip"
    }, PrintChecksum

    # Synopsis: Creates a Chocolately package of the Module
    Add-BuildTask ChocoPack -If (Test-PodeBuildIsWindows) PackDeps, PackageFolder, StampVersion, DeliverableFolder, {
        exec { choco pack ./packers/choco/pode.nuspec }
        Move-Item -Path "pode.$Version.nupkg" -Destination './deliverable'
    }

    # Synopsis: Create docker tags
    Add-BuildTask DockerPack PackageFolder, StampVersion, {
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
    Add-BuildTask Pack Compress, ChocoPack, DockerPack

    # Synopsis: Package up the Module into a /pkg folder
    Add-BuildTask PackageFolder Build, {
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
    }


    <#
# Testing
#>

    # Synopsis: Run the tests
    Add-BuildTask TestNoBuild TestDeps, {
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
        if ($originalUICulture) {
            Write-Output "Restore UICulture to $originalUICulture"
            # restore original UICulture
            [System.Threading.Thread]::CurrentThread.CurrentUICulture = $originalUICulture
        }
    }, PushCodeCoverage, CheckFailedTests

    # Synopsis: Run tests after a build
    Add-BuildTask Test Build, TestNoBuild

    # Synopsis: Check if any of the tests failed
    Add-BuildTask CheckFailedTests {
        if ($TestStatus.FailedCount -gt 0) {
            throw "$($TestStatus.FailedCount) tests failed"
        }
    }

    # Synopsis: If AppyVeyor or GitHub, push code coverage stats
    Add-BuildTask PushCodeCoverage -If (Test-PodeBuildCanCodeCoverage) {
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
    Add-BuildTask Docs DocsDeps, DocsHelpBuild, {
        mkdocs serve --open
    }

    # Synopsis: Build the function help documentation
    Add-BuildTask DocsHelpBuild IndexSamples, DocsDeps, Build, {
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
    Add-BuildTask DocsBuild DocsDeps, DocsHelpBuild, {
        mkdocs build --quiet
    }


    <#
# Clean-up
#>

    # Synopsis: Clean the build enviroment
    Add-BuildTask Clean  CleanPkg, CleanDeliverable, CleanLibs, CleanListener, CleanDocs

    # Synopsis: Clean the Deliverable folder
    Add-BuildTask CleanDeliverable {
        $path = './deliverable'
        if (Test-Path -Path $path -PathType Container) {
            Write-Host 'Removing ./deliverable folder'
            Remove-Item -Path $path -Recurse -Force | Out-Null
        }
        Write-Host "Cleanup $path done"
    }

    # Synopsis: Clean the pkg directory
    Add-BuildTask CleanPkg {
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
    Add-BuildTask CleanLibs {
        $path = './src/Libs'
        if (Test-Path -Path $path -PathType Container) {
            Write-Host "Removing $path  contents"
            Remove-Item -Path $path -Recurse -Force | Out-Null
        }

        Write-Host "Cleanup $path done"
    }

    # Synopsis: Clean the Listener folder
    Add-BuildTask CleanListener {
        $path = './src/Listener/bin'
        if (Test-Path -Path $path -PathType Container) {
            Write-Host "Removing $path contents"
            Remove-Item -Path $path -Recurse -Force | Out-Null
        }

        Write-Host "Cleanup $path done"
    }

    Add-BuildTask CleanDocs {
        $path = './docs/Getting-Started/Samples.md'
        if (Test-Path -Path $path -PathType Leaf) {
            Write-Host "Removing $path"
            Remove-Item -Path $path -Force | Out-Null
        }
    }
    <#
# Local module management
#>

    # Synopsis: Install Pode Module locally
    Add-BuildTask Install-Module -If ($Version) Pack, {
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
    Add-BuildTask Remove-Module {
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
    Add-BuildTask SetupPowerShell {
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

        # build the URL
        $urls = @{
            Old = "https://pscoretestdata.blob.core.windows.net/v$($PowerShellVersion -replace '\.', '-')/$($packageName)"
            New = "https://powershellinfraartifacts-gkhedzdeaghdezhr.z01.azurefd.net/install/v$($PowerShellVersion)/$($packageName)"
        }

        # download the package to a temp location
        $outputFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $packageName
        $downloadParams = @{
            Uri         = $urls.New
            OutFile     = $outputFile
            ErrorAction = 'Stop'
        }

        Write-Host "Output file: $($outputFile)"

        # retry the download 6 times, with a sleep of 10s between each attempt, and altering between old and new URLs
        $counter = 0
        $success = $false

        do {
            try {
                $counter++
                Write-Host "Attempt $($counter) of 6"

                # use new URL for odd attempts, and old URL for even attempts
                if ($counter % 2 -eq 0) {
                    $downloadParams.Uri = $urls.Old
                }
                else {
                    $downloadParams.Uri = $urls.New
                }

                # download the package
                Write-Host "Attempting download of $($packageName) from $($downloadParams.Uri)"
                Invoke-WebRequest @downloadParams

                $success = $true
                Write-Host "Downloaded $($packageName) successfully"
            }
            catch {
                $success = $false
                if ($counter -ge 6) {
                    throw "Failed to download PowerShell package after 6 attempts. Error: $($_.Exception.Message)"
                }

                Start-Sleep -Seconds 5
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
            if ($pr.labels.name -icontains 'superseded') {
                continue
            }

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

            $titles = @($pr.title).Trim()
            if ($pr.title.Contains(';')) {
                $titles = ($pr.title -split ';').Trim()
            }

            $author = $null
            if (($pr.author.login -ine 'badgerati') -and ($pr.author.login -inotlike '*dependabot*')) {
                $author = $pr.author.login
            }

            foreach ($title in $titles) {
                $str = "* #$($pr.number): $($title -replace '`', "'")"
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
}
else {
    Write-Host 'This script is intended to be run with Invoke-Build. Please use Invoke-Build to execute the tasks defined in this script.' -ForegroundColor Yellow
}