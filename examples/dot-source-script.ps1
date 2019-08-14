$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# runs the logic once, then exits
Start-PodeServer {

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    Use-PodeScript -Path './modules/script1.ps1'

}
