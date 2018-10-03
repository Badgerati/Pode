param (
    [string]
    $Version = ''
)

<#
# Helpers
#>

# Synopsis: Stamps the version onto the Module
task StampVersion {
    (Get-Content ./src/Pode.psd1) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./src/Pode.psd1
    (Get-Content ./packers/choco/pode.nuspec) | ForEach-Object { $_ -replace '\$version\$', $Version } | Set-Content ./packers/choco/pode.nuspec
}

# Synopsis: Generating a Checksum of the Zip
task PrintChecksum {
    $Script:Checksum = (checksum -t sha256 $Version-Binaries.zip)
    Write-Host "Checksum: $($Checksum)"
}


<#
# Dependencies
#>

# Synopsis: Install dependencies for running tests
task TestDeps {
    Install-Module -Name Pester -Scope CurrentUser -RequiredVersion '4.4.2' -Force -SkipPublisherCheck
}


<#
# Packaging
#>

# Synopsis: Creates a Zip of the Module
task 7Zip StampVersion, {
    exec { & 7z -tzip a $Version-Binaries.zip ./src/* }
}, PrintChecksum

# Synopsis: Creates a Chocolately package of the Module
task ChocoPack StampVersion, {
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