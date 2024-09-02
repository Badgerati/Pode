<#
.SYNOPSIS
    PowerShell script to set up a Pode server with static file browsing and authentication.

.DESCRIPTION
    This script sets up a Pode server that listens on port 8081. It includes static file browsing
    with different routes, some of which require authentication. The script also demonstrates
    how to set up basic authentication using Pode.

    The server includes routes for downloading files, browsing files without downloading, and
    accessing files with authentication.

.EXAMPLE
    To run the sample: ./FileBrowser/FileBrowser.ps1

    Access the file browser:
        Navigate to 'http://localhost:8081/' to browse the files in the specified directory.
    Download a file:
        Navigate to 'http://localhost:8081/download' to download files.
    Access a file with authentication:
        Navigate to 'http://localhost:8081/auth' and provide the username 'morty' and password 'pickle'.

.LINK
    https://github.com/Badgerati/Pode/blob/develop/examples/FileBrowser/FileBrowser.ps1

.NOTES
    Author: Pode Team
    License: MIT License
#>
try {
    $FileBrowserPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $podePath = Split-Path -Parent -Path (Split-Path -Parent -Path $FileBrowserPath)
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }

$directoryPath = $podePath
# Start Pode server
Start-PodeServer -ScriptBlock {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Default

    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic -Realm 'Pode Static Page' | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID   = 'M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }
    Add-PodeRoute -Method Get -Path '/LICENSE.txt' -ScriptBlock {
        $value = @'
Don't kid me. Nobody will believe that you want to read this legal nonsense.
I want to be kind; this is a summary of the content:

Nothing to report :D
'@
        Write-PodeTextResponse -Value $value
    }
    Add-PodeStaticRouteGroup -FileBrowser -Routes {

        Add-PodeStaticRoute -Path '/' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/download' -Source $using:directoryPath -DownloadOnly
        Add-PodeStaticRoute -Path '/nodownload' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/any/*/test' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/auth' -Source $using:directoryPath   -Authentication 'Validate'
    }
    Add-PodeStaticRoute -Path '/nobrowsing' -Source $directoryPath

    Add-PodeRoute -Method Get -Path '/attachment/*/test' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'ruler.png'
    }
}
