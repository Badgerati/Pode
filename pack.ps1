param (
    [Parameter()]
    [string]
    $build_version,

    [Parameter()]
    [string]
    $workspace
)

Write-Host 'Packing Pode'

if ([string]::IsNullOrWhiteSpace($build_version))
{
    $build_version = $env:BUILD_VERSION
    if ([string]::IsNullOrWhiteSpace($build_version))
    {
        $build_version = '1.0.0'
    }
}

if ([string]::IsNullOrWhiteSpace($workspace))
{
    $workspace = $env:WORKSPACE
    if ([string]::IsNullOrWhiteSpace($workspace))
    {
        $workspace = $pwd
    }
}

# == BUNDLE =======================================================

Write-Host "Copying scripts into package"

New-Item -ItemType Directory -Path './Package/src/Tools'
Copy-Item -Path './src/*' -Destination './Package/src/' -Recurse -Force

Write-Host "Scripts copied successfully"

# == ZIP =======================================================

Write-Host "Zipping package"
Push-Location "C:\Program Files\7-Zip\"
$zipName = "$($build_version)-Binaries.zip"

try
{
    .\7z.exe -tzip a "$($workspace)\$($zipName)" "$($workspace)\Package\*"
	if (!$?)
	{
		throw 'failed to make archive'
	}

    Write-Host "Package zipped successfully"
}
finally
{
    Pop-Location
}

# == CHOCO =======================================================

Write-Host "Building Package Checksum"
Push-Location "$workspace"

try
{
    $checksum = (checksum -t sha256 -f $zipName)
    Write-Host "Checksum: $checksum"
}
finally
{
    Pop-Location
}

Write-Host "Building Choco Package"
Push-Location "./packers/choco"

try
{
    (Get-Content 'pode.nuspec') | ForEach-Object { $_ -replace '\$version\$', $build_version } | Set-Content 'pode.nuspec'
    Set-Location tools
    (Get-Content 'ChocolateyInstall.ps1') | ForEach-Object { $_ -replace '\$version\$', $build_version } | Set-Content 'ChocolateyInstall.ps1'
    (Get-Content 'ChocolateyInstall.ps1') | ForEach-Object { $_ -replace '\$checksum\$', $checksum } | Set-Content 'Chocolateyinstall.ps1'
    Set-Location ..
	choco pack
}
finally
{
    Pop-Location
}

# =========================================================

Write-Host 'Pode Packed'