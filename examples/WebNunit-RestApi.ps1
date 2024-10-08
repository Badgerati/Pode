<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server for running NUnit tests.

.DESCRIPTION
    This script sets up a Pode server listening on port 8081 with a POST endpoint for running NUnit tests.
    It accepts JSON data specifying the test DLL path and the tests to run, executes the tests using NUnit,
    and returns the test results as an XML response.

.EXAMPLE
    To run the sample: ./Nunit-RestApi.ps1

    A typical request to "localhost:8087/api/nunit/run-rest" looks as follows:

    {
        "dll": "/path/test.dll",
        "tests": [
            "Test.Tests.Method1"
        ],
        "categories": {}
    }

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/WebNunit-RestApi.ps1
.NOTES
    Author: Pode Team
    License: MIT License
#>

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

# create a server, and start listening on port 8081
Start-PodeServer {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http

    # post endpoint, that accepts test to run, and path to test dll
    Add-PodeRoute -Method Post -Path '/api/nunit/run-test' -ScriptBlock {
        # general
        $date = [DateTime]::UtcNow.ToString('yyyy-MM-dd_HH-mm-ss-fffff')
        $data = $WebEvent.Data

        # get data passed in
        $dll = $data.dll
        $tests = $data.tests -join ','
        $catsInclude = $data.categories.include -join ','
        $catsExclude = $data.categories.exclude -join ','
        $results = "$($date).xml"
        $outputs = "$($date).txt"
        $tool = 'C:\Program Files (x86)\NUnit 2.6.4\bin\nunit-console.exe'

        # run the tests
        if (![string]::IsNullOrWhiteSpace($catsInclude))
        {
            $catsInclude = "/include=$($catsInclude)"
        }

        if (![string]::IsNullOrWhiteSpace($catsExclude))
        {
            $catsExclude = "/exclude=$($catsExclude)"
        }

        $_args = "/result=$($results) /out=$($outputs) $($catsInclude) $($catsExclude) /run=$($tests) /nologo /nodots `"$($dll)`""
        Start-Process -FilePath $tool -NoNewWindow -Wait -ArgumentList $_args -ErrorAction Stop | Out-Null

        # return results
        Write-PodeXmlResponse -Path $results

        # delete results file
        Remove-Item -Path $results -Force | Out-Null
        Remove-Item -Path $outputs -Force | Out-Null
    }

}