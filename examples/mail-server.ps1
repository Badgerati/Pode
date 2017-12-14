if ((Get-Module -Name Pode | Measure-Object).Count -ne 0)
{
    Remove-Module -Name Pode
}

$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -ErrorAction Stop

# or just:
# Import-Module Pode

# create a server, and start listening on port 25
Server -Smtp {

    # setup an smtp handler
    Add-PodeTcpHandler 'smtp' {
        param($from, $tos, $data)
        Write-Host $from
        Write-Host $tos
        Write-Host $data
    }

}