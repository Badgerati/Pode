function Invoke-TravisTest
{
    # run the tests
    $file = "$($pwd)/TestsResults.xml"
    $status = Invoke-Pester "$($pwd)/tests/unit" -OutputFormat NUnitXml -OutputFile $file -PassThru
    
    # fail build if any tests failed
    Test-TravisTestResults -ResultStatus $status -ResultFile $file
}

function Test-TravisTestResults
{
    param (
        $ResultStatus,
        $ResultFile
    )

    Write-Host 'Checking if any of the tests have failed'

    if ($ResultStatus.FailedCount -gt 0) {
        Write-Host 'Some of the tests have failed' -ForegroundColor Red
        throw "$($ResultStatus.FailedCount) tests failed."
    }
    else {
          Write-Host 'No tests failed!' -ForegroundColor Green
    }
}