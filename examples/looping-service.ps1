$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start looping
Start-PodeServer -Interval 3 {

    schedule 'date' '@minutely' {
        Write-Host ([DateTime]::Now.ToShortDateString())
    }

    handler service {
        Write-Host 'hello, world!'
    }

}
