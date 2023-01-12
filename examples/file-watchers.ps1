$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 9000
Start-PodeServer -Verbose {

    # add two endpoints
    # Add-PodeEndpoint -Address * -Port 9000 -Protocol Http

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # watchers
    # Add-PodeFileWatcher -Name 'Test' -Path './public' -Include '*.txt', '*.md' -ScriptBlock {
    #     "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
    # }

    Add-PodeFileWatcher -Path 'C:/Projects/:project/src' -Include '*.ps1' -ScriptBlock {
        "[$($FileEvent.Type)][$($FileEvent.Parameters['project'])]: $($FileEvent.FullPath)" | Out-Default
    }

    # Add-PodeTimer -Name 'Test' -Interval 10 -ScriptBlock {
    #     $root = Get-PodeServerPath
    #     $file = Join-Path $root 'myfile.txt'
    #     'hi!' | Out-File -FilePath $file -Append -Force
    # }

    # Add-PodeFileWatcher -Path '.' -Include '*.txt' -ScriptBlock {
    #     "[$($FileEvent.Type)]: $($FileEvent.FullPath)" | Out-Default
    # }
}