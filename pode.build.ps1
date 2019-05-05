param (
    [string]
    $Version = ''
)

<#
# Dependency Versions
#>

$PesterVersion = '4.8.0'
$MkDocsVersion = '1.0.4'
$CoverallsVersion = '1.0.25'
$7ZipVersion = '18.5.0.20180730'
$ChecksumVersion = '0.2.0'
$MkDocsThemeVersion = '4.2.0'

<#
# Helper Functions
#>

function Test-IsWindows
{
    $v = $PSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
}

function Test-IsAppVeyor
{
    return (![string]::IsNullOrWhiteSpace($env:APPVEYOR_JOB_ID))
}

function Test-Command($cmd)
{
    $path = $null

    if (Test-IsWindows) {
        $path = (Get-Command $cmd -ErrorAction Ignore)
    }
    else {
        $path = (which $cmd)
    }

    return (![string]::IsNullOrWhiteSpace($path))
}

function Invoke-Install($name, $version)
{
    if (Test-IsWindows) {
        if (Test-Command 'choco') {
            choco install $name --version $version -y
        }
    }
    else {
        if (Test-Command 'brew') {
            brew install $name
        }
        elseif (Test-Command 'apt-get') {
            sudo apt-get install $name -y
        }
        elseif (Test-Command 'yum') {
            sudo yum install $name -y
        }
    }
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
    if (Test-IsWindows) {
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
task ChocoDeps -If (Test-IsWindows) {
    if (!(Test-Command 'choco')) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

# Synopsis: Install dependencies for packaging
task PackDeps -If (Test-IsWindows) ChocoDeps, {
    if (!(Test-Command 'checksum')) {
        Invoke-Install 'checksum' $ChecksumVersion
    }

    if (!(Test-Command '7z')) {
        Invoke-Install '7zip' $7ZipVersion
    }
}

# Synopsis: Install dependencies for running tests
task TestDeps {
    # install pester
    if (((Get-Module -ListAvailable Pester) | Where-Object { $_.Version -ieq $PesterVersion }) -eq $null) {
        Write-Host 'Installing Pester'
        Install-Module -Name Pester -Scope CurrentUser -RequiredVersion $PesterVersion -Force -SkipPublisherCheck
    }

    # install coveralls
    if (Test-IsAppVeyor)
    {
        if (((Get-Module -ListAvailable coveralls) | Where-Object { $_.Version -ieq $CoverallsVersion }) -eq $null) {
            Write-Host 'Installing Coveralls'
            Install-Module -Name coveralls -Scope CurrentUser -RequiredVersion $CoverallsVersion -Force -SkipPublisherCheck
        }
    }
}

# Synopsis: Install dependencies for documentation
task DocsDeps ChocoDeps, {
    if (!(Test-Command 'mkdocs')) {
        Invoke-Install 'mkdocs' $MkDocsVersion
    }

    $_installed = (pip list --format json --disable-pip-version-check | ConvertFrom-Json)
    if (($_installed | Where-Object { $_.name -ieq 'mkdocs-material' -and $_.version -ieq $MkDocsThemeVersion } | Measure-Object).Count -eq 0) {
        pip install "mkdocs-material==$($MkDocsThemeVersion)" --force-reinstall --disable-pip-version-check
    }
}


<#
# Packaging
#>

# Synopsis: Creates a Zip of the Module
task 7Zip -If (Test-IsWindows) PackDeps, StampVersion, {
    exec { & 7z -tzip a $Version-Binaries.zip ./src/* }
}, PrintChecksum

# Synopsis: Creates a Chocolately package of the Module
task ChocoPack -If (Test-IsWindows) PackDeps, StampVersion, {
    exec { choco pack ./packers/choco/pode.nuspec }
}

# Synopsis: Package up the Module
task Pack -If (Test-IsWindows) 7Zip, ChocoPack


<#
# Testing
#>

# Synopsis: Run the tests
task Test TestDeps, {
    $p = (Get-Command Invoke-Pester)
    if ($null -eq $p -or $p.Version -ine $PesterVersion) {
        Import-Module Pester -Force -RequiredVersion $PesterVersion
    }

    $Script:TestResultFile = "$($pwd)/TestResults.xml"

    # if appveyor, run code coverage
    if (Test-IsAppVeyor) {
        $srcFiles = (Get-ChildItem "$($pwd)/src/*.ps1" -Recurse -Force).FullName
        $Script:TestStatus = Invoke-Pester './tests/unit' -OutputFormat NUnitXml -OutputFile $TestResultFile -CodeCoverage $srcFiles -PassThru
    }
    else {
        $Script:TestStatus = Invoke-Pester './tests/unit' -OutputFormat NUnitXml -OutputFile $TestResultFile -PassThru
    }
}, PushAppVeyorTests, PushCodeCoverage, CheckFailedTests

# Synopsis: Check if any of the tests failed
task CheckFailedTests {
    if ($TestStatus.FailedCount -gt 0) {
        throw "$($TestStatus.FailedCount) tests failed"
    }
}

# Synopsis: If AppVeyor, push result artifacts
task PushAppVeyorTests -If (Test-IsAppVeyor) {
    $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
    (New-Object 'System.Net.WebClient').UploadFile($url, $TestResultFile)
    Push-AppveyorArtifact $TestResultFile
}

# Synopsis: If AppyVeyor, push code coverage stats
task PushCodeCoverage -If (Test-IsAppVeyor) {
    $coverage = Format-Coverage -PesterResults $Script:TestStatus -CoverallsApiToken $env:PODE_COVERALLS_TOKEN -RootFolder $pwd -BranchName $ENV:APPVEYOR_REPO_BRANCH
    Publish-Coverage -Coverage $coverage
}


<#
# Docs
#>

# Synopsis: Run the documentation
task Docs DocsDeps, {
    mkdocs serve
}

# Synopsis: Build the documentation
task DocsBuild DocsDeps, {
    mkdocs build
}