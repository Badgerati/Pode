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

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    
    Add-PodeStaticRoute -Path '/nobrowsing' -Source $directoryPath
    Add-PodeStaticRouteGroup -FileBrowser  -Routes {
        Add-PodeStaticRoute -Path '/download' -Source $using:directoryPath   -DownloadOnly
        Add-PodeStaticRoute -Path '/nodownload' -Source $using:directoryPath
        Add-PodeStaticRoute -Path '/' -Source $using:directoryPath   # -DownloadOnly
    }

}
