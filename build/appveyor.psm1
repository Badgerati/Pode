function Invoke-AppVeyorTest
{
    # run the tests
    $file = "$($pwd)\TestsResults.xml"
    $status = Invoke-Pester "$($pwd)\tests\unit" -OutputFormat NUnitXml -OutputFile $file -PassThru

    # upload the results
    Update-AppVeyorTestResults -ResultFile $file
    
    # fail build if any tests failed
    Test-AppVeyorTestResults -ResultStatus $status -ResultFile $file
}

function Update-AppVeyorTestResults
{
    param (
        $ResultFile
    )

    Write-Host "Uploading results for Job ID '$($env:APPVEYOR_JOB_ID)'" -ForegroundColor Cyan
    (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", $ResultFile)
    Write-Host 'Results uploaded' -ForegroundColor Green
}

function Test-AppVeyorTestResults
{
    param (
        $ResultStatus,
        $ResultFile
    )

    Write-Host 'Checking if any of the tests have failed'

    if ($ResultStatus.FailedCount -gt 0) {
        Write-Host 'Some of the tests have failed' -ForegroundColor Red
        Push-AppveyorArtifact $ResultFile
        throw "$($ResultStatus.FailedCount) tests failed."
    }
    else {
          Write-Host 'No tests failed!' -ForegroundColor Green
    }
}