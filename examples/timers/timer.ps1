Add-PodeTimer -Name 'imported-timer' -Interval 10 -ScriptBlock {
    'i am imported!' | Out-Default
}