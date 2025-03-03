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




function Compare-Hashtable {
    param (
        [object]$Hashtable1,
        [object]$Hashtable2
    )

    # Function to compare two hashtable values
    function Compare-Value($value1, $value2) {
        # Check if both values are hashtables
        if ((($value1 -is [hashtable] -or $value1 -is [System.Collections.Specialized.OrderedDictionary]) -and
    ($value2 -is [hashtable] -or $value2 -is [System.Collections.Specialized.OrderedDictionary]))) {
            return Compare-Hashtable -Hashtable1 $value1 -Hashtable2 $value2
        }
        # Check if both values are arrays
        elseif (($value1 -is [Object[]]) -and ($value2 -is [Object[]])) {
            if ($value1.Count -ne $value2.Count) {
                return $false
            }
            for ($i = 0; $i -lt $value1.Count; $i++) {
                $found = $false
                for ($j = 0; $j -lt $value2.Count; $j++) {
                    if ( Compare-Value $value1[$i] $value2[$j]) {
                        $found = $true
                    }
                }
                if ($found -eq $false) {
                    return $false
                }
            }
            return $true
        }
        else {
            if ($value1 -is [string] -and $value2 -is [string]) {
                return  Compare-StringRnLn $value1 $value2
            }
            # Check if the values are equal
            return $value1 -eq $value2
        }
    }

    $keys1 = $Hashtable1.Keys
    $keys2 = $Hashtable2.Keys

    # Check if both hashtables have the same keys
    if ($keys1.Count -ne $keys2.Count) {
        return $false
    }

    foreach ($key in $keys1) {
        if (! ($Hashtable2.Keys -contains $key)) {
            return $false
        }

        if ($Hashtable2[$key] -is [hashtable] -or $Hashtable2[$key] -is [System.Collections.Specialized.OrderedDictionary]) {
            if (! (Compare-Hashtable -Hashtable1 $Hashtable1[$key] -Hashtable2 $Hashtable2[$key])) {
                return $false
            }
        }
        elseif (!(Compare-Value $Hashtable1[$key] $Hashtable2[$key])) {
            return $false
        }
    }

    return $true
}


function Compare-StringRnLn {
    param (
        [string]$InputString1,
        [string]$InputString2
    )
    return ($InputString1.Trim() -replace "`r`n|`n|`r", "`n") -eq ($InputString2.Trim() -replace "`r`n|`n|`r", "`n")
}

function Convert-PsCustomObjectToOrderedHashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$InputObject
    )
    begin {
        # Define a recursive function within the process block
        function Convert-ObjectRecursively {
            param (
                [Parameter(Mandatory = $true)]
                [System.Object]
                $InputObject
            )

            # Initialize an ordered dictionary
            $orderedHashtable = [ordered]@{}

            # Loop through each property of the PSCustomObject
            foreach ($property in $InputObject.PSObject.Properties) {
                # Check if the property value is a PSCustomObject
                if ($property.Value -is [PSCustomObject]) {
                    # Recursively convert the nested PSCustomObject
                    $orderedHashtable[$property.Name] = Convert-ObjectRecursively -InputObject $property.Value
                }
                elseif ($property.Value -is [System.Collections.IEnumerable] -and -not ($property.Value -is [string])) {
                    # If the value is a collection, check each element
                    $convertedCollection = @()
                    foreach ($item in $property.Value) {
                        if ($item -is [PSCustomObject]) {
                            $convertedCollection += Convert-ObjectRecursively -InputObject $item
                        }
                        else {
                            $convertedCollection += $item
                        }
                    }
                    $orderedHashtable[$property.Name] = $convertedCollection
                }
                else {
                    # Add the property name and value to the ordered hashtable
                    $orderedHashtable[$property.Name] = $property.Value
                }
            }

            # Return the resulting ordered hashtable
            return $orderedHashtable
        }
    }
    process {
        # Call the recursive helper function for each input object
        Convert-ObjectRecursively -InputObject $InputObject
    }
}

function Get-PodeModuleManifest {
    param(
        [string]$Src
    )
    # Construct the path to the module manifest (.psd1 file)
    $moduleManifestPath = Join-Path -Path $Src -ChildPath 'Pode.psd1'

    # Import the module manifest to access its properties
    $moduleManifest = Import-PowerShellDataFile -Path $moduleManifestPath
    return  $moduleManifest
}