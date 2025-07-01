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
#Start-PodeServer -ConfigFile '..\Server.psd1' -ScriptBlock {
Start-PodeServer -ScriptBlock {

    Add-PodeEndpoint -Address localhost -Port 8081 -Protocol Http -Default

    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    #   Set-PodeServerSetting -Compression -Enable -Encoding 'gzip'

    #Set-PodeServerSetting -Cache -Enable
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
    Add-PodeRoute -Method Get -Path '*/LICENSE.txt' -ScriptBlock {
        $value = @'
Don't kid me. Nobody will believe that you want to read this legal nonsense.
I want to be kind; this is a summary of the content:

Nothing to report :D
'@
        Write-PodeTextResponse -Value $value
    }
    Add-PodeStaticRouteGroup -FileBrowser -Routes {

        Add-PodeStaticRoute -Path '/standard' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/download' -Source $using:directoryPath -DownloadOnly  -PassThru | Add-PodeRouteCompression -Enable -Encoding gzip
        Add-PodeStaticRoute -Path '/nodownload' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/gzip' -Source $using:directoryPath -PassThru | Add-PodeRouteCompression -Enable -Encoding gzip
        Add-PodeStaticRoute -Path '/deflate' -Source $using:directoryPath -PassThru | Add-PodeRouteCompression -Enable -Encoding deflate
        Add-PodeStaticRoute -Path '/cache' -Source $using:directoryPath -PassThru | Add-PodeRouteCache -Enable -MaxAge 3600 -Visibility public -ETagMode mtime -Immutable

        Add-PodeStaticRoute -Path '/compress_cache' -Source $using:directoryPath -PassThru | Add-PodeRouteCache -Enable -MaxAge 3600 -Visibility public -ETagMode mtime -Immutable -PassThru | Add-PodeRouteCompression -Enable -Encoding deflate, gzip, br

        if ($IsCoreCLR) {
            Add-PodeStaticRoute -Path '/br' -Source $using:directoryPath    -PassThru | Add-PodeRouteCompression -Enable -Encoding br
        }
        Add-PodeStaticRoute -Path '/any/*/test' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/auth' -Source $using:directoryPath   -Authentication 'Validate'
    }
    Add-PodeStaticRoute -Path '/nobrowsing' -Source $directoryPath

    Add-PodeRoute -Method Get -Path '/attachment/*/test' -ScriptBlock {
        Set-PodeResponseAttachment -Path 'ruler.png'
    }

    Add-PodeRoute -Method Get -Path '/encoding/transfer' -ScriptBlock {
        write-podehost $webEvent -explode -ShowType -label 'Add-PodeRoute Response'
        $string = Get-Content -Path $using:directoryPath/pode.build.ps1 -raw
        $data = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($string))
        # write-podetextresponse -Value "This is a response with transfer encoding. The Accept-Encoding header was: $($WebEvent.AcceptEncoding)"
        Write-PodeJsonResponse -Value @{ Data = $data }
    } -PassThru | Add-PodeRouteCompression -Enable -Encoding gzip

    
   Add-PodeRoute -Method Post -Path '/encoding/transfer' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Data.username }
                }
  Add-PodeRoute -Method Post -Path '/encoding/transfer-forced-type' -TransferEncoding 'gzip' -ScriptBlock {
                    Write-PodeJsonResponse -Value @{ Username = $WebEvent.Data.username }
                }

    Add-PodeRoute -Method Get -Path '/'    -ScriptBlock {
        $str = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Pode Static-Route Index</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; }
        h1   { margin-bottom: .5rem; }
        ul   { list-style: none; padding-left: 0; }
        li   { margin: .25rem 0; }
        a    { text-decoration: none; color: #0060df; }
        a:hover { text-decoration: underline; }
        small { color: #666; }
    </style>
</head>
<body>
    <h1>Route Links</h1>
    <ul>
        <li><a href="/standard">/standard</a></li>

        <!-- triggers a download -->
        <li><a href="/download">/download</a> <small>(Download-only)</small></li>

        <li><a href="/nodownload">/nodownload</a></li>

        <!-- compression examples -->
        <li><a href="/gzip">/gzip</a> <small>(gzip)</small></li>
        <li><a href="/deflate">/deflate</a> <small>(deflate)</small></li>
        <li><a href="/br">/br</a> <small>(Brotli – .NET Core only)</small></li>

        <!-- caching -->
        <li><a href="/cache">/cache</a> <small>(cache-controlled)</small></li>

         <!-- caching and compress-->
        <li><a href="/compress_cache">/compress_cache</a> <small>(cache-controlled with compression)</small></li>

        <!-- wildcard routes with sample segments -->
        <li><a href="/any/sample/test">/any/*/test</a></li>
        <li><a href="/attachment/123/test">/attachment/*/test</a></li>

        <!-- auth-protected -->
        <li><a href="/auth">/auth</a> <small>(authentication required)</small></li>

        <!-- browsing disabled -->
        <li><a href="/nobrowsing">/nobrowsing</a> <small>(directory listing disabled)</small></li>
    </ul>
</body>
</html>
'@
        Write-PodeHtmlResponse -Value $str -StatusCode 200
    }

}
