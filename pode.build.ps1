param (
    [string]
    $Version = ''
)

<#
# Helper Functions
#>

function Test-IsUnix
{
    return $PSVersionTable.Platform -ieq 'unix'
}

function Test-IsWindows
{
    $v = $PSVersionTable
    return ($v.Platform -ilike '*win*' -or ($null -eq $v.Platform -and $v.PSEdition -ieq 'desktop'))
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


<#
# Helper Tasks
#>

# Synopsis: Stamps the version onto the Module
task StampVersion {
    (Get-Content ./src/Pode.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./src/Pode.psd1
    (Get-Content ./packers/choco/pode.nuspec) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/pode.nuspec
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

task ChocoDeps -If (Test-IsWindows) {
    if (!(Test-Command 'choco')) {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

task PackDeps ChocoDeps, {
    if (Test-IsWindows) {
        if (!(Test-Command 'checksum')) {
            choco install checksum --version '0.2.0' -y
        }

        if (!(Test-Command '7z')) {
            choco install 7zip.install --version '18.5.0.20180730' -y
        }
    }
    else {
        # TODO: Install 7zip on nix
    }
}

# Synopsis: Install dependencies for running tests
task TestDeps {
    Install-Module -Name Pester -Scope CurrentUser -RequiredVersion '4.4.2' -Force -SkipPublisherCheck
}

#
task DocsDeps ChocoDeps, {
    if (Test-IsWindows) {
        if (!(Test-Command 'mkdocs')) {
            choco install mkdocs --version '1.0.4' -y
        }
    }
    else {
        # TODO:
    }

    if ((pip list --format json | ConvertFrom-Json).name -inotcontains 'mkdocs-material') {
        pip install mkdocs-material
    }
}


<#
# Packaging
#>

# Synopsis: Creates a Zip of the Module
task 7Zip PackDeps, StampVersion, {
    exec { & 7z -tzip a $Version-Binaries.zip ./src/* }
}, PrintChecksum

# Synopsis: Creates a Chocolately package of the Module
task ChocoPack -If (Test-IsWindows) PackDeps, StampVersion, {
    exec { choco pack ./packers/choco/pode.nuspec }
}

# Synopsis: Package up the Module
task Pack 7Zip, ChocoPack


<#
# Testing
#>

# Synopsis: Run the tests
task Test TestDeps, {
    $Script:TestResultFile = "$($pwd)/TestResults.xml"
    $Script:TestStatus = Invoke-Pester './tests/unit' -OutputFormat NUnitXml -OutputFile $TestResultFile -PassThru
}, PushAppVeyorTests, CheckFailedTests

# Synopsis: Check if any of the tests failed
task CheckFailedTests {
    if ($TestStatus.FailedCount -gt 0) {
        throw "$($TestStatus.FailedCount) tests failed"
    }
}

# Synopsis: If AppVeyor, push result artifacts
task PushAppVeyorTests -If (![string]::IsNullOrWhiteSpace($env:APPVEYOR_JOB_ID)) {
    $url = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
    (New-Object 'System.Net.WebClient').UploadFile($url, $TestResultFile)
    Push-AppveyorArtifact $TestResultFile
}


<#
# Docs
#>

#
task Docs DocsDeps, {
    mkdocs serve
}

#
task DocsBuild DocsDeps, {
    mkdocs build
}