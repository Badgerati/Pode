param (
    [int]$StepSize = 10000000,
    [int]$ThrottleLimit = 20
)

$squaretask = @()
$totalSteps = [math]::Floor([int]::MaxValue / ($StepSize  ))
 
$jobs = 0..$totalSteps | ForEach-Object -Parallel {

    $i = ($_ ) * ($using:StepSize )
    $squareHeader = @{
        Start = $i
        End   = ($i + $using:StepSize)

    }
    if ($squareHeader.End -le [int]::MaxValue ) {
        Write-Host  "$_/$using:totalSteps) $($using:StepSize+$i)"
        # Invoke-RestMethod -Uri 'http://localhost:8080/SumOfSquares' -Method Get -Headers $squareHeader
        #   Invoke-RestMethod -Uri 'http://localhost:8080/SumOfSquaresInCSharp' -Method Get -Headers $squareHeader
     #  Invoke-RestMethod -Uri 'http://localhost:8080/SumOfSquaresDotSourcing' -Method Get -Headers $squareHeader
        Invoke-RestMethod -Uri 'http://localhost:8080/SumOfSquaresNoLoop' -Method Get -Headers $squareHeader
  #    Invoke-RestMethod -Uri 'http://localhost:8080/SumOfSquaresPSM1' -Method Get -Headers $squareHeader
    }
} -ThrottleLimit 20 #-ArgumentList $StepSize  # Adjust the ThrottleLimit as needed

$squaretask += $jobs
