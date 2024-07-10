return {
    $using:hmm | out-default
    Write-PodeViewResponse -Path 'simple' -Data @{ 'numbers' = @(4, 5, 6); }
}