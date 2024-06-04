 try {
    $FileBrowserPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
    $podePath = Split-Path -Parent -Path (Split-Path -Parent -Path $FileBrowserPath)
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -ErrorAction Stop
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
