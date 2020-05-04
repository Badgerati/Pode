$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
Example call:
Send-MailMessage -SmtpServer localhost -To 'to@pode.com' -From 'from@pode.com' -Body 'Hello' -Subject 'Hi there' -Port 25
#>

# create a server, and start listening on port 25
Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address localhost -Protocol SMTP

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # allow the local ip
    #Add-PodeAccessRule -Access Allow -Type IP -Values 127.0.0.1

    # setup an smtp handler
    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
        param($e)
        Write-Host '- - - - - - - - - - - - - - - - - -'
        Write-Host $e.Email.From
        Write-Host $e.Email.To
        Write-Host ([string]::Empty)
        Write-Host $e.Email.Body
        Write-Host ([string]::Empty)
        Write-Host $e.Email.Data
        Write-Host '- - - - - - - - - - - - - - - - - -'
    }

}