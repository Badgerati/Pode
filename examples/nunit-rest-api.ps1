if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 8087
Server -Port 8087 {

    # post endpoint, that accepts test to run, and path to test dll
    Add-PodeRoute 'post' '/api/nunit/run-test' {
        param($res, $req, $data)

        # get data passed in
        $dll = $data.dll
        $tests = $data.tests -join ','
        $catsInclude = $data.categories.include -join ','
        $catsExclude = $data.categories.exclude -join ','
        $results = "$([DateTime]::UtcNow.ToString('yyyy-MM-dd_HH-mm-ss-fffff')).xml"
        $tool = 'C:\Program Files (x86)\NUnit 2.6.4\bin\nunit-console.exe'

        # run the tests
        $_args = "/result:$($results) /include:$($catsInclude) /exclude:$($catsExclude) /run:$($tests) $($dll)"
        Start-Process -FilePath $tool -NoNewWindow -WindowStyle Hidden -Wait -ArgumentList $_args | Out-Null

        # return results
        Write-XmlResponseFromFile -Path $results -Response $res

        # delete results file
        Remove-Item -Path $results -Force | Out-Null
    }

}