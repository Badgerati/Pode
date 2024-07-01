try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
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

Start-PodeServer -Verbose {

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    Add-PodeFileWatcher -Path $ScriptPath -Include '*.ps1' -ScriptBlock {
        "[$($FileEvent.Type)][$($FileEvent.Parameters['project'])]: $($FileEvent.FullPath)" | Out-Default
    }
}