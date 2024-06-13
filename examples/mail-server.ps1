try {
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
    }
}
catch { throw }

# or just:
# Import-Module Pode

<#
Example call:
Send-MailMessage -SmtpServer localhost -To 'to@pode.com' -From 'from@pode.com' -Body 'Hello' -Subject 'Hi there' -Port 25

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
Send-MailMessage -SmtpServer localhost -To 'to@pode.com' -From 'from@pode.com' -Body 'Hello' -Subject 'Hi there' -Port 587 -UseSSL
#>

# create a server, and start listening on port 25
Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address localhost -Protocol Smtp
    Add-PodeEndpoint -Address localhost -Protocol Smtps -SelfSigned -TlsMode Explicit
    Add-PodeEndpoint -Address localhost -Protocol Smtps -SelfSigned -TlsMode Implicit

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels Error, Debug

    # allow the local ip
    #Add-PodeAccessRule -Access Allow -Type IP -Values 127.0.0.1

    # setup an smtp handler
    Add-PodeHandler -Type Smtp -Name 'Main' -ScriptBlock {
        Write-PodeHost '- - - - - - - - - - - - - - - - - -'
        Write-PodeHost $SmtpEvent.Email.From
        Write-PodeHost $SmtpEvent.Email.To
        Write-PodeHost '|'
        Write-PodeHost $SmtpEvent.Email.Body
        Write-PodeHost '|'
        # Write-PodeHost $SmtpEvent.Email.Data
        # Write-PodeHost '|'
        $SmtpEvent.Email.Attachments | Out-Default
        if ($SmtpEvent.Email.Attachments.Length -gt 0) {
            #$SmtpEvent.Email.Attachments[0].Save('C:\temp')
        }
        Write-PodeHost '|'
        $SmtpEvent.Email | Out-Default
        $SmtpEvent.Request | out-default
        $SmtpEvent.Email.Headers | out-default
        Write-PodeHost '- - - - - - - - - - - - - - - - - -'
    }

}