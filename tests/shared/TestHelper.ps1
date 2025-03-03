[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '')]
param()
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


<#
.SYNOPSIS
  Compares two strings while normalizing line endings.

.DESCRIPTION
  This function trims both input strings and replaces all variations of line endings (`CRLF`, `LF`, `CR`) with a normalized `LF` (`\n`).
  It then compares the normalized strings for equality.

.PARAMETER InputString1
  The first string to compare.

.PARAMETER InputString2
  The second string to compare.

.OUTPUTS
  [bool]
  Returns `$true` if both strings are equal after normalization; otherwise, returns `$false`.

.EXAMPLE
  Compare-PodeStringRnLn -InputString1 "Hello`r`nWorld" -InputString2 "Hello`nWorld"
  # Returns: $true

.EXAMPLE
  Compare-PodeStringRnLn -InputString1 "Line1`r`nLine2" -InputString2 "Line1`rLine2"
  # Returns: $true

.NOTES
  This function ensures that strings with different line-ending formats are treated as equal if their content is otherwise identical.
#>
function Compare-PodeStringRnLn {
    param (
        [string]$InputString1,
        [string]$InputString2
    )
    return ($InputString1.Trim() -replace "`r`n|`n|`r", "`n") -eq ($InputString2.Trim() -replace "`r`n|`n|`r", "`n")
}

<#
.SYNOPSIS
  Converts a PSCustomObject into an ordered hashtable.

.DESCRIPTION
  This function recursively converts a PSCustomObject, including nested objects and collections, into an ordered hashtable.
  It ensures that all properties are retained while maintaining their original structure.

.PARAMETER InputObject
  The PSCustomObject to be converted into an ordered hashtable.

.OUTPUTS
  [System.Collections.Specialized.OrderedDictionary]
  Returns an ordered hashtable representation of the input PSCustomObject.

.EXAMPLE
  $object = [PSCustomObject]@{ Name = "Pode"; Version = "2.0"; Config = [PSCustomObject]@{ Debug = $true } }
  Convert-PodePsCustomObjectToOrderedHashtable -InputObject $object
  # Returns: An ordered hashtable representation of $object.

.EXAMPLE
  $object = [PSCustomObject]@{ Users = @([PSCustomObject]@{ Name = "Alice" }, [PSCustomObject]@{ Name = "Bob" }) }
  Convert-PodePsCustomObjectToOrderedHashtable -InputObject $object
  # Returns: An ordered hashtable where 'Users' is an array of ordered hashtables.

.NOTES
  This function preserves key order and supports recursive conversion of nested objects and collections.
#>
function Convert-PodePsCustomObjectToOrderedHashtable {
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

<#
.SYNOPSIS
  Compares two hashtables to determine if they are equal.

.DESCRIPTION
  This function recursively compares two hashtables, checking whether they contain the same keys and values.
  It also handles nested hashtables and arrays, ensuring deep comparison of all elements.

.PARAMETER Hashtable1
  The first hashtable to compare.

.PARAMETER Hashtable2
  The second hashtable to compare.

.OUTPUTS
  [bool]
  Returns `$true` if both hashtables are equal, otherwise returns `$false`.

.EXAMPLE
  $hash1 = @{ Name = "Pode"; Version = "2.0"; Config = @{ Debug = $true } }
  $hash2 = @{ Name = "Pode"; Version = "2.0"; Config = @{ Debug = $true } }
  Compare-PodeHashtable -Hashtable1 $hash1 -Hashtable2 $hash2
  # Returns: $true

.EXAMPLE
  $hash1 = @{ Name = "Pode"; Version = "2.0" }
  $hash2 = @{ Name = "Pode"; Version = "2.1" }
  Compare-PodeHashtable -Hashtable1 $hash1 -Hashtable2 $hash2
  # Returns: $false

#>
function Compare-PodeHashtable {
    param (
        [object]$Hashtable1,
        [object]$Hashtable2
    )

    # Function to compare two hashtable values
    function Compare-Value($value1, $value2) {
        # Check if both values are hashtables
        if ((($value1 -is [hashtable] -or $value1 -is [System.Collections.Specialized.OrderedDictionary]) -and
    ($value2 -is [hashtable] -or $value2 -is [System.Collections.Specialized.OrderedDictionary]))) {
            return Compare-PodeHashtable -Hashtable1 $value1 -Hashtable2 $value2
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
                return  Compare-PodeStringRnLn $value1 $value2
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
            if (! (Compare-PodeHashtable -Hashtable1 $Hashtable1[$key] -Hashtable2 $Hashtable2[$key])) {
                return $false
            }
        }
        elseif (!(Compare-Value $Hashtable1[$key] $Hashtable2[$key])) {
            return $false
        }
    }

    return $true
}


<#
.SYNOPSIS
  Waits for a web server to become available at a specified URI or port.

.DESCRIPTION
  This function continuously checks if a web server is online by sending an HTTP request.
  It retries until the server responds with a 200 status code or a timeout is reached.

.PARAMETER Uri
  The full URI to check (e.g., "http://127.0.0.1:5000"). If not provided, defaults to "http://localhost:$Port".

.PARAMETER Port
  The port on which the web server is expected to be available. If no URI is provided, the function constructs a default URI using "http://localhost:$Port".

.PARAMETER Timeout
  The maximum number of seconds to wait before timing out. Default is 60 seconds.

.PARAMETER Interval
  The number of seconds to wait between retries. Default is 2 seconds.

.OUTPUTS
  Boolean - Returns $true if the server is online, otherwise $false.

.EXAMPLE
  Wait-PodeForWebServer -Port 8080 -Timeout 30 -Interval 2

  Waits up to 30 seconds for the web server on port 8080 to come online.

.EXAMPLE
  Wait-PodeForWebServer -Uri "http://127.0.0.1:5000" -Timeout 45

  Waits up to 45 seconds for the web server at "http://127.0.0.1:5000" to respond.

.NOTES
  Author: ChatGPT
  This function ensures that the web server is fully responding, not just that the port is open.
#>
function Wait-PodeForWebServer {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Position = 0)]
        [string]$Uri,

        [Parameter(Position = 1)]
        [int]$Port,

        [Parameter()]
        [int]$Timeout = 60,

        [Parameter()]
        [int]$Interval = 2
    )

    # Determine the final URI: If no URI is provided, use "http://localhost:$Port"
    if (-not $Uri) {
        if ($Port -gt 0) {
            $Uri = "http://localhost:$Port"
        }
        else {
            return $false
        }
    }

    $MaxRetries = [math]::Ceiling($Timeout / $Interval)
    $RetryCount = 0

    while ($RetryCount -lt $MaxRetries) {
        try {
            # Send a request but ignore status codes (any response means the server is online)
            $null = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 3
            Write-Host "Webserver is online at $Uri"
            return $true
        }
        catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 404) {
                return $true
            }
            else {
                Write-Host "Waiting for webserver to come online at $Uri... (Attempt $($RetryCount+1)/$MaxRetries)"
            }
        }

        Start-Sleep -Seconds $Interval
        $RetryCount++
    }

    return $false
}




function Compare-PodeHashtable {
    param (
        [object]$Hashtable1,
        [object]$Hashtable2
    )

    # Function to compare two hashtable values
    function Compare-Value($value1, $value2) {
        # Check if both values are hashtables
        if ((($value1 -is [hashtable] -or $value1 -is [System.Collections.Specialized.OrderedDictionary]) -and
    ($value2 -is [hashtable] -or $value2 -is [System.Collections.Specialized.OrderedDictionary]))) {
            return Compare-PodeHashtable -Hashtable1 $value1 -Hashtable2 $value2
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
                return  Compare-PodeStringRnLn $value1 $value2
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
            if (! (Compare-PodeHashtable -Hashtable1 $Hashtable1[$key] -Hashtable2 $Hashtable2[$key])) {
                return $false
            }
        }
        elseif (!(Compare-Value $Hashtable1[$key] $Hashtable2[$key])) {
            return $false
        }
    }

    return $true
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