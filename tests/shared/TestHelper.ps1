<#
.SYNOPSIS
	Ensures the Pode assembly is loaded into the current session.

.DESCRIPTION
	This function checks if the Pode assembly is already loaded into the current PowerShell session.
	If not, it determines the appropriate .NET runtime version and attempts to load the Pode.dll
	from the most compatible directory. If no specific version is found, it defaults to netstandard2.0.

.PARAMETER SrcPath
	The base path where the Pode library (Libs folder) is located.

.EXAMPLE
	Import-PodeAssembly -SrcPath 'C:\Projects\MyApp'
	Ensures that Pode.dll is loaded from the appropriate .NET folder.

.NOTES
	Ensure that the Pode library path is correctly structured with folders named
	`netstandard2.0`, `net6.0`, etc., inside the `Libs` folder.
#>
function Import-PodeAssembly {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SrcPath
    )

    # Check if Pode is already loaded
    if (!([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Pode' })) {
        # Fetch the .NET runtime version
        $version = [System.Environment]::Version.Major
        $libsPath = Join-Path -Path $SrcPath -ChildPath 'Libs'

        # Filter .NET DLL folders based on version and get the latest one
        $netFolder = if (![string]::IsNullOrWhiteSpace($version)) {
            Get-ChildItem -Path $libsPath -Directory -Force |
                Where-Object { $_.Name -imatch "net[1-$($version)]" } |
                Sort-Object -Property Name -Descending |
                Select-Object -First 1 -ExpandProperty FullName
        }

        # Use netstandard2.0 if no folder found
        if ([string]::IsNullOrWhiteSpace($netFolder)) {
            $netFolder = Join-Path -Path $libsPath -ChildPath 'netstandard2.0'
        }

        # Append Pode.dll and mount
        Add-Type -LiteralPath (Join-Path -Path $netFolder -ChildPath 'Pode.dll') -ErrorAction Stop
    }
}


