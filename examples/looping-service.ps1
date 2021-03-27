$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start looping
Start-PodeServer -Interval 3 {

    Add-PodeHandler -Type Service -Name 'Hello' -ScriptBlock {
        Write-Host 'hello, world!'
        Lock-PodeObject -Object $ServiceEvent.Lockable {
            "Look I'm locked!" | Out-PodeHost
        }
    }

    Add-PodeHandler -Type Service -Name 'Bye' -ScriptBlock {
        Write-Host 'goodbye!'
    }

}
