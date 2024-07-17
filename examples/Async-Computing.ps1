param(
    [Parameter()]
    [int]
    $Port = 8080,
    [switch]
    $Quiet,
    [switch]
    $DisableTermination
)



<#
$mortyCommonHeaders = @{
  'accept'        = 'application/json'
  'X-API-KEY'     = 'test-api-key'
  'Authorization' = 'Basic bW9ydHk6cGlja2xl'
}

$mindyCommonHeaders = @{
            'accept'        = 'application/json'
            'X-API-KEY'     = 'test2-api-key'
            'Authorization' = 'Basic bWluZHk6cGlja2xl'
}




$squaretask=@()
for($i=0; $i -lt  [int]::MaxValue ; $i+=1M+1){
$squareHeader=@{
Start=$i
End=$i+1M
}|Convertto-json
$squaretask += Invoke-RestMethod -Uri 'http://localhost:8080/SumOfSquares' -Method Get -Headers $squareHeader
}


$query=@{
 "Name"= @{
    "op"+ "LIKE",
    "value"= "__Get_SumOfSquares__"
  }
}|Convertto-json








$response_asyncUsingCancelable = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsingCancelable' -Method Put -Headers $mortyCommonHeaders

$body = @{
  callbackUrl = 'http://localhost:8080/receive/callback'
} | ConvertTo-Json

$headersWithContentType = $mortyCommonHeaders.Clone()
$headersWithContentType['Content-Type'] = 'application/json'

$response_asyncUsing = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncUsing' -Method Put -Headers $headersWithContentType -Body $body

$response_asyncState = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncState' -Method Put -Headers $mortyCommonHeaders

$response_asyncParam = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncParam' -Method Put -Headers $mortyCommonHeaders

$response_asyncWaitForeverTimeout = Invoke-RestMethod -Uri 'http://localhost:8080/auth/asyncWaitForeverTimeout' -Method Put -Headers $mortyCommonHeaders



$response = Invoke-RestMethod -Uri 'http://localhost:8080/tasks' -Method Post -Body '{}' -Headers $mindyCommonHeaders

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

# Get the temporary directory path
$tempDir = [System.IO.Path]::GetTempPath()

# Define the file path
$filePath = Join-Path -Path $tempDir -ChildPath 'SumOfSquares.ps1'
# Define the function content
$functionContent = @'
function SumOfSquares {
    param (
        [int]$Start,
        [int]$End

    )
    [double] $sum = 0
    for ($i = $Start; $i -le $End; $i++) {
        $sum += [math]::Pow($i, 2)
    }
    return $sum
}
'@

# Write the function content to the file
Set-Content -Path $filePath -Value $functionContent


$SumOfSquaresModulefilePath = Join-Path -Path $tempDir -ChildPath 'SumOfSquares.psm1'
# Define the function content
$functionContent = @'
function SumOfSquaresModule {
    param (
        [int]$Start,
        [int]$End

    )
    [double] $sum = 0
    for ($i = $Start; $i -le $End; $i++) {
        $sum += [math]::Pow($i, 2)
    }
    return $sum
}
Export-ModuleMember -Function SumOfSquaresModule
'@

# Write the function content to the file
Set-Content -Path $SumOfSquaresModulefilePath -Value $functionContent




Start-PodeServer -Threads 30 -Quiet:$Quiet -DisableTermination:$DisableTermination {
    Import-PodeModule -Path $SumOfSquaresModulefilePath
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http
    New-PodeLoggingMethod -name 'async' -File  -Path "$ScriptPath/logs" | Enable-PodeErrorLogging

    # request logging
    # New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging

    Enable-PodeOpenApi -Path '/docs/openapi' -OpenApiVersion '3.0.3'  -DisableMinimalDefinitions -NoDefaultResponses

    Add-PodeOAInfo -Title 'Async Computing - OpenAPI 3.0' -Version 0.0.1

    Enable-PodeOAViewer -Type Swagger -Path '/docs/swagger'

    Enable-PodeOAViewer -Editor -Path '/docs/swagger-editor'
    Enable-PodeOAViewer -Bookmarks -Path '/docs'

    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquares' -ScriptBlock {
        function SumOfSquares {
            param (
                [int]$Start,
                [int]$End

            )
            [double] $sum = 0
            for ($i = $Start; $i -le $End; $i++) {
                $sum += [math]::Pow($i, 2)
            }
            return $sum
        }

        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "Start=$start End=$end"
        [double] $sum = SumOfSquares -Start $Start -End $End
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 10 -MinRunspaces 5 -PassThru | Set-PodeOARouteInfo -Summary 'Caluclate sum of squares'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
            (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
             (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }



    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquaresPSM1' -ScriptBlock {

        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "Start=$start End=$end"
        [double] $sum = SumOfSquaresModule -Start $Start -End $End
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 10 -MinRunspaces 5 -PassThru | Set-PodeOARouteInfo -Summary 'Caluclate sum of squares'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
               (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
                (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }



    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquaresDotSourcing' -ScriptBlock {

        . (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'SumOfSquares.ps1')
        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "Start=$start End=$end"
        [double] $sum = SumOfSquares -Start $Start -End $End
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 2 -MinRunspaces 2 -PassThru | Set-PodeOARouteInfo -Summary 'Caluclate sum of squares'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
                (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
                 (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }



    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquaresNoLoop' -ScriptBlock {
        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "Start=$start End=$end"

        # Calculate the sum of squares from 1 to $End
        $n = $End
        [double]$sumEnd = ($n * ($n + 1) * (2 * $n + 1)) / 6

        # Calculate the sum of squares from 1 to $Start-1
        $m = $Start - 1
        [double]$sumStart = ($m * ($m + 1) * (2 * $m + 1)) / 6

        # The sum of squares from $Start to $End
        [double]$sum = $sumEnd - $sumStart
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 2 -MinRunspaces 2 -PassThru | Set-PodeOARouteInfo -Summary 'Caluclate sum of squares'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
                (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
                 (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }





    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquaresInCSharp' -ScriptBlock {
        Add-Type -TypeDefinition @'
public class MathOperations
{
    public static double SumOfSquares(int start, int end)
    {
        double sum = 0;
        for (int i = start; i <= end; i++)
        {
            sum += (long)System.Math.Pow(i, 2);
        }
        return sum;
    }
}
'@
        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "C# code - Start=$start End=$end"
        $sum = [MathOperations]::SumOfSquares($Start, $End)
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 100 -MinRunspaces 5 -PassThru | Set-PodeOARouteInfo -Summary 'Caluclate sum of squares'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
                (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
                 (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }


    Add-PodeRoute -PassThru -Method Get -path '/SumOfSquareRoot' -ScriptBlock {
        $start = [int]( Get-PodeHeader -Name 'Start')
        $end = [int]( Get-PodeHeader -Name 'End')
        Write-PodeHost "Start=$start End=$end"
        [double]$sum = 0.0
        for ($i = $Start; $i -le $End; $i++) {
            $sum += [math]::Sqrt($i )
        }
        Write-PodeHost "Result of Start=$start End=$end is $sum"
        return $sum
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml' -MaxRunspaces 99 -MinRunspaces 5 -PassThru | Set-PodeOARouteInfo -Summary 'Caluclate sum of square roots'  -PassThru |
        Set-PodeOARequest -PassThru -Parameters (
          (  New-PodeOANumberProperty -Name 'Start' -Format Double -Description 'Start' -Required | ConvertTo-PodeOAParameter -In Header),
             (   New-PodeOANumberProperty -Name 'End' -Format Double -Description 'End' -Required | ConvertTo-PodeOAParameter -In Header)
        ) | Add-PodeOAResponse -StatusCode 200 -Description 'Successful operation' -Content  @{ 'application/json' = New-PodeOANumberProperty -Name 'Result' -Format Double -Description 'Result' -Required -Object }


    Add-PodeAsyncGetRoute -Path '/task' -ResponseContentType  'application/json', 'application/yaml'  -In Path
    Add-PodeAsyncStopRoute -Path '/task' -ResponseContentType 'application/json', 'application/yaml' -In Query

    Add-PodeAsyncQueryRoute -path '/tasks'  -ResponseContentType 'application/json', 'application/yaml'   -Payload  Body -QueryContentType 'application/json', 'application/yaml'


    Add-PodeRoute  -Method 'Post' -Path '/close' -ScriptBlock {
        Close-PodeServer
    } -PassThru | Set-PodeOARouteInfo -Summary 'Shutdown the server'

    Add-PodeRoute  -Method 'Get' -Path '/hello' -ScriptBlock {
        Write-PodeJsonResponse -Value @{'message' = 'Hello!' } -StatusCode 200
    } -PassThru | Set-PodeOARouteInfo -Summary 'Hello from the server'
    <#
    Add-PodeRoute -PassThru -Method Put -Path '/asyncglobal'    -ScriptBlock {

        Write-PodeHost "global:gSleepTime=$($global:gSleepTime)"
        Write-PodeHost "global:gMessage=$($global:gMessage)"
        for ($i = 0; $i -lt 20; $i++) {
            Start-Sleep $global:gSleepTime
        }
        return @{ InnerValue = $global:gMessage }
    } | Set-PodeAsyncRoute -ResponseContentType 'application/json', 'application/yaml'

#>

}