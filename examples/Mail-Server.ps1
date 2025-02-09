<#
.SYNOPSIS
    A sample PowerShell script to set up a Pode server with SMTP and SMTPS protocols.

.DESCRIPTION
    This script sets up a Pode server listening on SMTP (port 25) and SMTPS (with explicit and implicit TLS).
    It includes logging for errors and debug information and demonstrates handling incoming SMTP emails with
    potential attachments.

.EXAMPLE
    To run the sample: ./Mail-Server.ps1

    Send-MailMessage -SmtpServer localhost -To 'to@pode.com' -From 'from@pode.com' -Body 'Hello' -Subject 'Hi there' -Port 25

.EXAMPLE
    To run the sample: ./Mail-Server.ps1
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { return $true }
    Send-MailMessage -SmtpServer localhost -To 'to@pode.com' -From 'from@pode.com' -Body 'Hello' -Subject 'Hi there' -Port 587 -UseSSL

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/Mail-Server.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>

try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
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

# create a server, and start listening on port 25
Start-PodeServer -Threads 2 {

    Add-PodeEndpoint -Address localhost -Protocol Smtp
    Add-PodeEndpoint -Address localhost -Protocol Smtps -SelfSigned -TlsMode Explicit
    Add-PodeEndpoint -Address localhost -Protocol Smtps -SelfSigned -TlsMode Implicit

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging -Levels Error, Debug

    # allow the local ip
    #Add-PodeAccessRule -Access Allow -Type IP -Values 127.0.0.1
    # Add-PodeLimitAccessRule -Name 'Main' -Action Deny -Component @(
    #     New-PodeLimitIPComponent -IP '127.0.0.1'
    # )
    # Add-PodeLimitRateRule -Name 'Main' -Limit 1 -Duration 5000 -Component @(
    #     New-PodeLimitIPComponent -IP '127.0.0.1'
    # )

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