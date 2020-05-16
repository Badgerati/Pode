param (
    [string]
    $Version = ''
)

<#
# Dependency Versions
#>

$Versions = @{
    Pester = '4.8.0'
    MkDocs = '1.0.4'
    PSCoveralls = '1.0.0'
    SevenZip = '18.5.0.20180730'
    Checksum = '0.2.0'
    MkDocsTheme = '4.6.0'
    PlatyPS = '0.14.0'
}

<#
# Helper Functions
#>

function Test-PodeBuildIsWindows
{
    $v = $PSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}

function Test-PodeBuildIsAppVeyor
{
    return (![string]::IsNullOrWhiteSpace($env:APPVEYOR_JOB_ID))
}

function Test-PodeBuildIsGitHub
{
    return (![string]::IsNullOrWhiteSpace($env:GITHUB_REF))
}

function Test-PodeBuildCanCodeCoverage
{
    return (@('1', 'true') -icontains $env:PODE_RUN_CODE_COVERAGE)
}

function Get-PodeBuildService
{
    if (Test-PodeBuildIsAppVeyor) {
        return 'appveyor'
    }

    if (Test-PodeBuildIsGitHub) {
        return 'github-actions'
    }

    return 'travis-ci'
}

function Test-PodeBuildCommand($cmd)
{
    $path = $null

    if (Test-PodeBuildIsWindows) {
        $path = (Get-Command $cmd -ErrorAction Ignore)
    }
    else {
        $path = (which $cmd)
    }

    return (![string]::IsNullOrWhiteSpace($path))
}

function Get-PodeBuildBranch
{
    if (Test-PodeBuildIsAppVeyor) {
        $branch = $env:APPVEYOR_REPO_BRANCH
    }
    elseif (Test-PodeBuildIsGitHub) {
        $branch = $env:GITHUB_REF
    }

    return ($branch -ireplace 'refs\/heads\/', '')
}

function Invoke-PodeBuildInstall($name, $version)
{
    if (Test-PodeBuildIsWindows) {
        if (Test-PodeBuildCommand 'choco') {
            choco install $name --version $version -y
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

function Install-PodeBuildModule($name)
{
    if ($null -ne ((Get-Module -ListAvailable $name) | Where-Object { $_.Version -ieq $Versions.$name })) {
        return
    }

    Write-Host "Installing $($name)"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Install-Module -Name $name -Scope CurrentUser -RequiredVersion $Versions.$name -Force -SkipPublisherCheck
}


<#
# Helper Tasks
#>

# Synopsis: Stamps the version onto the Module
task StampVersion {
    (Get-Content ./src/Pode.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./src/Pode.psd1
    (Get-Content ./packers/choco/pode.nuspec) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/pode.nuspec
    (Get-Content ./packers/choco/tools/ChocolateyInstall.ps1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/tools/ChocolateyInstall.ps1
}

# Synopsis: Generating a Checksum of the Zip
task PrintChecksum {
    if (Test-PodeBuildIsWindows) {
        $Script:Checksum = (checksum -t sha256 $Version-Binaries.zip)
    }
    else {
        $Script:Checksum = (shasum -a 256 ./$Version-Binaries.zip | awk '{ print $1 }').ToUpper()
    }

    Write-Host "Checksum: $($Checksum)"
}


<#
# Dependencies
#>

# Synopsis: Installs Chocolatey
task ChocoDeps -If (Test-PodeBuildIsWindows) {
    if (!(Test-PodeBuildCommand 'choco')) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

# Synopsis: Install dependencies for packaging
task PackDeps -If (Test-PodeBuildIsWindows) ChocoDeps, {
    if (!(Test-PodeBuildCommand 'checksum')) {
        Invoke-PodeBuildInstall 'checksum' $Versions.Checksum
    }

    if (!(Test-PodeBuildCommand '7z')) {
        Invoke-PodeBuildInstall '7zip' $Versions.SevenZip
    }
}

# Synopsis: Install dependencies for running tests
task TestDeps {
    # install pester
    Install-PodeBuildModule Pester

    # install PSCoveralls
    if (Test-PodeBuildCanCodeCoverage)
    {
        Install-PodeBuildModule PSCoveralls
    }
}

# Synopsis: Install dependencies for documentation
task DocsDeps ChocoDeps, {
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
# Packaging
#>

# Synopsis: Creates a Zip of the Module
task 7Zip -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
    exec { & 7z -tzip a $Version-Binaries.zip ./src/* }
}, PrintChecksum

# Synopsis: Creates a Chocolately package of the Module
task ChocoPack -If (Test-PodeBuildIsWindows) PackDeps, StampVersion, {
    exec { choco pack ./packers/choco/pode.nuspec }
}

# Synopsis: Package up the Module
task Pack -If (Test-PodeBuildIsWindows) 7Zip, ChocoPack


<#
# Testing
#>

# Synopsis: Run the tests
task Test TestDeps, {
    $p = (Get-Command Invoke-Pester)
    if ($null -eq $p -or $p.Version -ine $Versions.Pester) {
        Import-Module Pester -Force -RequiredVersion $Versions.Pester
    }

    $Script:TestResultFile = "$($pwd)/TestResults.xml"

    # if appveyor or github, run code coverage
    if (Test-PodeBuildCanCodeCoverage) {
        $srcFiles = (Get-ChildItem "$($pwd)/src/*.ps1" -Recurse -Force).FullName
        $Script:TestStatus = Invoke-Pester './tests/unit', './tests/integration' -OutputFormat NUnitXml -OutputFile $TestResultFile -CodeCoverage $srcFiles -PassThru
    }
    else {
        $Script:TestStatus = Invoke-Pester './tests/unit', './tests/integration' -OutputFormat NUnitXml -OutputFile $TestResultFile -Show Failed -PassThru
    }
}, PushAppVeyorTests, PushCodeCoverage, CheckFailedTests

# Synopsis: Check if any of the tests failed
task CheckFailedTests {
    if ($TestStatus.FailedCount -gt 0) {
        throw "$($TestStatus.FailedCount) tests failed"
    }
}

# Synopsis: If AppVeyor, push result artifacts
task PushAppVeyorTests -If (Test-PodeBuildIsAppVeyor) {
    $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
    (New-Object 'System.Net.WebClient').UploadFile($url, $TestResultFile)
    Push-AppveyorArtifact $TestResultFile
}

# Synopsis: If AppyVeyor or GitHub, push code coverage stats
task PushCodeCoverage -If (Test-PodeBuildCanCodeCoverage) {
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
task Docs DocsDeps, DocsHelpBuild, {
    mkdocs serve
}

# Synopsis: Build the function help documentation
task DocsHelpBuild DocsDeps, {
    # import the local module
    Remove-Module Pode -Force -ErrorAction Ignore | Out-Null
    Import-Module ./src/Pode.psm1 -Force | Out-Null

    # build the function docs
    $path = './docs/Functions'
    $map =@{}

    (Get-Module Pode).ExportedFunctions.Keys | ForEach-Object {
        $type = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf -Path (Get-Command $_ -Module Pode).ScriptBlock.File))
        New-MarkdownHelp -Command $_ -OutputFolder (Join-Path $path $type) -Force -Metadata @{ PodeType = $type } -AlphabeticParamsOrder | Out-Null
        $map[$_] = $type
    }

    # update docs to bind links to unlinked functions
    $path = Join-Path $pwd 'docs'
    Get-ChildItem -Path $path -Recurse -Filter '*.md' | ForEach-Object {
        $depth = ($_.FullName.Replace($path, [string]::Empty).trim('\/') -split '[\\/]').Length

        $content = (Get-Content -Path $_.FullName | ForEach-Object {
            $line = $_

            while ($line -imatch '\[`(?<name>[a-z]+\-pode[a-z]+)`\](?<char>[^(])') {
                $name = $Matches['name']
                $char = $Matches['char']
                $line = ($line -ireplace "\[``$($name)``\][^(]", "[``$($name)``]($('../' * $depth)Functions/$($map[$name])/$($name))$($char)")
            }

            $line
        })

        $content | Out-File -FilePath $_.FullName -Force -Encoding ascii
    }

    # remove the module
    Remove-Module Pode -Force -ErrorAction Ignore | Out-Null
}

# Synopsis: Build the documentation
task DocsBuild DocsDeps, DocsHelpBuild, {
    mkdocs build
}