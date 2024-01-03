param(
    [string]
    $Version ='',
    [string]
    [ValidateSet(  'None', 'Normal' , 'Detailed', 'Diagnostic')]
    $PesterVerbosity = 'Normal'
)

<#
# Dependency Versions
#>

$Versions = @{
    Pester      = '5.5.0'
    MkDocs      = '1.5.3'
    PSCoveralls = '1.0.0'
    SevenZip    = '18.5.0.20180730'
    DotNet      = '8.0.1'
    Checksum    = '0.2.0'
    MkDocsTheme = '9.4.6'
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
    } else {
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
            choco install $name --version $version -y
        }
    } else {
        if (Test-PodeBuildCommand 'brew') {
            brew install $name
        } elseif (Test-PodeBuildCommand 'apt-get') {
            sudo apt-get install $name -y
        } elseif (Test-PodeBuildCommand 'yum') {
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
    $highestSdkVersion = dotnet --list-sdks | Select-Object -Last 1 | ForEach-Object { $_.Split(' ')[0] }
    $majorVersion = [int]$highestSdkVersion.Split('.')[0]

    # Determine if the target framework is compatible
    $isCompatible = $False
    switch ($majorVersion) {
        8 { if ($target -in @('net6.0', 'net7.0', 'netstandard2.0', 'net8.0')) { $isCompatible = $True } }
        7 { if ($target -in @('net6.0', 'net7.0', 'netstandard2.0')) { $isCompatible = $True } }
        6 { if ($target -in @('net6.0', 'netstandard2.0')) { $isCompatible = $True } }
    }

    # Skip build if not compatible
    if (  $isCompatible) {
        Write-Host "SDK for target framework $target is compatible with the installed SDKs"
    } else {
        Write-Host "SDK for target framework $target is not compatible with the installed SDKs. Skipping build."
        return
    }
    if ($Version) {
        $AssemblyVersion = "-p:Version=$Version"
    } else {
        $AssemblyVersion = ''
    }
    dotnet build --configuration Release --self-contained --framework $target $AssemblyVersion
    if (!$?) {
        throw "dotnet build failed for $($target)"
    }

    dotnet publish --configuration Release --self-contained --framework $target $AssemblyVersion --output ../Libs/$target
    if (!$?) {
        throw "dotnet publish failed for $($target)"
    }

}


<#
# Helper Tasks
#>

# Synopsis: Stamps the version onto the Module
Task StampVersion {
    (Get-Content ./pkg/Pode.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./pkg/Pode.psd1
    (Get-Content ./pkg/Pode.Internal.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./pkg/Pode.Internal.psd1
    (Get-Content ./packers/choco/pode_template.nuspec) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/pode.nuspec
    (Get-Content ./packers/choco/tools/ChocolateyInstall_template.ps1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/tools/ChocolateyInstall.ps1
}

# Synopsis: Generating a Checksum of the Zip
Task PrintChecksum {
    if (Test-PodeBuildIsWindows) {
        $Script:Checksum = (checksum -t sha256 $Version-Binaries.zip)
    } else {
        $Script:Checksum = (shasum -a 256 ./$Version-Binaries.zip | awk '{ print $1 }').ToUpper()
    }

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
    if (!(Test-PodeBuildCommand 'checksum')) {
        Invoke-PodeBuildInstall 'checksum' $Versions.Checksum
    }

    if (!(Test-PodeBuildCommand '7z')) {
        Invoke-PodeBuildInstall '7zip' $Versions.SevenZip
    }
}

# Synopsis: Install dependencies for compiling/building
Task BuildDeps {
    # install dotnet
    if (!(Test-PodeBuildCommand 'dotnet')) {
        Invoke-PodeBuildInstall 'dotnet' $Versions.DotNet
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
        pip install "mkdocs-material==$($Versions.MkDocsTheme)" --force-reinstall --disable-pip-version-check
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
    Write-Host "Powershell Version:"
    $PSVersionTable.PSVersion
    Push-Location ./src/Listener

    try {
        Invoke-PodeBuildDotnetBuild -target 'netstandard2.0'
        Invoke-PodeBuildDotnetBuild -target 'net6.0'
        Invoke-PodeBuildDotnetBuild -target 'net7.0'
        Invoke-PodeBuildDotnetBuild -target 'net8.0'
    } finally {
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

# Synopsis: Creates a Chocolately package of the Module
Task ChocoPack -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
    exec { choco pack ./packers/choco/pode.nuspec }
}

# Synopsis: Create docker tags
Task DockerPack -If ((Test-PodeBuildIsWindows) -or $IsLinux) {
    docker build -t badgerati/pode:$Version -f ./Dockerfile .
    docker build -t badgerati/pode:latest -f ./Dockerfile .
    docker build -t badgerati/pode:$Version-alpine -f ./alpine.dockerfile .
    docker build -t badgerati/pode:latest-alpine -f ./alpine.dockerfile .
    docker build -t badgerati/pode:$Version-arm32 -f ./arm32.dockerfile .
    docker build -t badgerati/pode:latest-arm32 -f ./arm32.dockerfile .

    docker tag badgerati/pode:latest docker.pkg.github.com/badgerati/pode/pode:latest
    docker tag badgerati/pode:$Version docker.pkg.github.com/badgerati/pode/pode:$Version
    docker tag badgerati/pode:latest-alpine docker.pkg.github.com/badgerati/pode/pode:latest-alpine
    docker tag badgerati/pode:$Version-alpine docker.pkg.github.com/badgerati/pode/pode:$Version-alpine
    docker tag badgerati/pode:latest-arm32 docker.pkg.github.com/badgerati/pode/pode:latest-arm32
    docker tag badgerati/pode:$Version-arm32 docker.pkg.github.com/badgerati/pode/pode:$Version-arm32
}

# Synopsis: Package up the Module
Task Pack -If (Test-PodeBuildIsWindows) Build, {
    $path = './pkg'
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }

    # create the pkg dir
    New-Item -Path $path -ItemType Directory -Force | Out-Null

    # which folders do we need?
    $folders = @('Private', 'Public', 'Misc', 'Libs')

    # create the directories, then copy the source
    $folders | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $path $_) -Force | Out-Null
        Copy-Item -Path "./src/$($_)/*" -Destination (Join-Path $path $_) -Force -Recurse | Out-Null
    }

    # copy general files
    Copy-Item -Path ./src/Pode.psm1 -Destination $path -Force | Out-Null
    Copy-Item -Path ./src/Pode.psd1 -Destination $path -Force | Out-Null
    Copy-Item -Path ./src/Pode.Internal.psm1 -Destination $path -Force | Out-Null
    Copy-Item -Path ./src/Pode.Internal.psd1 -Destination $path -Force | Out-Null
    Copy-Item -Path ./LICENSE.txt -Destination $path -Force | Out-Null
}, StampVersion, 7Zip, ChocoPack, DockerPack


<#
# Testing
#>

# Synopsis: Run the tests
Task Test Build, TestDeps, {
    $p = (Get-Command Invoke-Pester)
    if ($null -eq $p -or $p.Version -ine $Versions.Pester) {
        Remove-Module Pester -Force -ErrorAction Ignore
        Import-Module Pester -Force -RequiredVersion $Versions.Pester
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
        $Script:TestStatus = Invoke-Pester   -Configuration $configuration
    } else {
        $configuration.Output.Verbosity = 'Detailed'
        $Script:TestStatus = Invoke-Pester  -Configuration $configuration
    }
}, PushCodeCoverage, CheckFailedTests

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
    } catch {
        $_.Exception | Out-Default
    }
}


<#
# Docs
#>

# Synopsis: Run the documentation locally
Task Docs DocsDeps, DocsHelpBuild, {
    mkdocs serve
}

# Synopsis: Build the function help documentation
Task DocsHelpBuild DocsDeps, {
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
    mkdocs build
}


Task Clean  {

    $path = './pkg'

    if (  (Test-Path $path)) {
        Remove-Item -Path $path -Recurse -Force | Out-Null
    }
    Write-Host "$path Cleanup done"
}

Task InstallCurrentUser  {

    $path = './pkg'

    if ($Version){

        if (! (Test-Path $path)) {
            Invoke-Build Pack -Version $Version
        }
        if ($IsWindows -or (($PSVersionTable.Keys -contains "PSEdition") -and ($PSVersionTable.PSEdition -eq 'Desktop'))) {
            $PSPaths = $ENV:PSModulePath -split ";"
        }
        else {
            $PSPaths = $ENV:PSModulePath -split ":"
        }
        $dest = join-path -Path  $PSPaths[0]  -ChildPath "Pode" -AdditionalChildPath "$Version"

        if (Test-Path $dest) {
            Remove-Item -Path $dest -Recurse -Force | Out-Null
        }

        # create the dest dir
        New-Item -Path $dest -ItemType Directory -Force | Out-Null
        # which folders do we need?

        Copy-Item -Path  (Join-Path -Path $path -ChildPath 'Private'  ) -Destination  $dest -Force -Recurse | Out-Null
        Copy-Item -Path  (Join-Path -Path $path -ChildPath 'Public'  ) -Destination  $dest -Force -Recurse | Out-Null
        Copy-Item -Path  (Join-Path -Path $path -ChildPath 'Misc'  ) -Destination  $dest -Force -Recurse | Out-Null
        Copy-Item -Path  (Join-Path -Path $path -ChildPath 'Libs'  ) -Destination  $dest -Force -Recurse | Out-Null



        # copy general files
        Copy-Item -Path $(Join-Path -Path $path -ChildPath 'Pode.psm1') -Destination $dest -Force | Out-Null
        Copy-Item -Path $(Join-Path -Path $path -ChildPath 'Pode.psd1') -Destination $dest -Force | Out-Null
        Copy-Item -Path $(Join-Path -Path $path -ChildPath 'Pode.Internal.psm1') -Destination $dest -Force | Out-Null
        Copy-Item -Path $(Join-Path -Path $path -ChildPath 'Pode.Internal.psd1') -Destination $dest -Force  | Out-Null
        Copy-Item -Path $(Join-Path -Path $path -ChildPath 'LICENSE.txt') -Destination $dest -Force   | Out-Null

        Write-Host "Deployed to $dest"
    }

}