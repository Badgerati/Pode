[CmdletBinding()]
param (
    [switch]$CreateFile
)

$FileBrowserPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$podePath = Split-Path -Parent -Path (Split-Path -Parent -Path $FileBrowserPath)
if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
    Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
}
else {
    Import-Module -Name 'Pode'
}

if ($CreateFile) {
    # Define the document root directory
    $directoryPath = "$FileBrowserPath/wwwFiles"

    # Ensure the directory exists
    if (-not (Test-Path -Path $directoryPath)) {
        New-Item -ItemType Directory -Path $directoryPath

        for ($j = 1; $j -le 10; $j++) {
            $DirName = 'folder_' + [Guid]::NewGuid().ToString()
            $DirPath = Join-Path -Path $directoryPath -ChildPath $DirName
            New-Item -ItemType Directory -Path $DirPath
            for ($i = 1; $i -le $j + 6 ; $i++) {
                # Generate a random file name
                $fileName = [Guid]::NewGuid().ToString() + '.txt'
                $filePath = Join-Path -Path $directoryPath -ChildPath $fileName

                # Generate random content
                $content = -join ((65..90) + (97..122) | Get-Random -Count 256 | ForEach-Object { [char]$_ })

                # Create the file with random content
                Set-Content -Path $filePath -Value $content
            }
            #under the new folder
            for ($i = 1; $i -le 100 * $j ; $i++) {
                # Generate a random file name
                $fileName = [Guid]::NewGuid().ToString() + '.txt'
                $filePath = Join-Path -Path $DirPath -ChildPath $fileName

                # Generate random content
                $content = -join ((65..90) + (97..122) | Get-Random -Count 256 | ForEach-Object { [char]$_ })

                # Create the file with random content
                Set-Content -Path $filePath -Value $content
            }
        }
    }
    Write-Output "1000 files with random content and names have been created in $directoryPath"
}
else {
    $directoryPath = $podePath
}
# Start Pode server
Start-PodeServer -ScriptBlock {

    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http -Default

    New-PodeLoggingMethod -Terminal | Enable-PodeRequestLogging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # setup basic auth (base64> username:password in header)
    New-PodeAuthScheme -Basic -Realm 'Pode Static Page' | Add-PodeAuth -Name 'Validate' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{
                User = @{
                    ID ='M0R7Y302'
                    Name = 'Morty'
                    Type = 'Human'
                }
            }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    Add-PodeStaticRouteGroup -FileBrowser  -Routes {
        Add-PodeStaticRoute -Path '/' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/download' -Source $using:directoryPath -DownloadOnly
        Add-PodeStaticRoute -Path '/nodownload' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/auth' -Source $using:directoryPath   -Authentication 'Validate'
    }
    Add-PodeStaticRoute -Path '/nobrowsing' -Source $directoryPath
}
