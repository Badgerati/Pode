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

        # general
        $date = [DateTime]::UtcNow.ToString('yyyy-MM-dd_HH-mm-ss-fffff')

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
        Write-XmlResponseFromFile -Path $results -Response $res

        # delete results file
        Remove-Item -Path $results -Force | Out-Null
        Remove-Item -Path $outputs -Force | Out-Null
    }

}