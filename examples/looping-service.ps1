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

# create a server, and start looping
Start-PodeServer -Interval 3 {

    Add-PodeHandler -Type Service -Name 'Hello' -ScriptBlock {
        Write-PodeHost 'hello, world!'
        Lock-PodeObject -ScriptBlock {
            "Look I'm locked!" | Out-PodeHost
        }
    }

    Add-PodeHandler -Type Service -Name 'Bye' -ScriptBlock {
        Write-PodeHost 'goodbye!'
    }

}
