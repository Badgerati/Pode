[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()

Describe 'OpenAPI integration tests' {

    BeforeAll {
        $mindyCommonHeaders = @{
            'accept'        = 'application/json'
            'X-API-KEY'     = 'test2-api-key'
            'Authorization' = 'Basic bWluZHk6cGlja2xl'
        }

        $mortyCommonHeaders = @{
            'accept'        = 'application/json'
            'X-API-KEY'     = 'test-api-key'
            'Authorization' = 'Basic bW9ydHk6cGlja2xl'
        }
        $PortV3 = 8080
        $PortV3_1 = 8081
        $Endpoint = "http://127.0.0.1:$($PortV3)"
        $scriptPath = "$($PSScriptRoot)\..\..\examples\OpenApi-TuttiFrutti.ps1"
        if ($PSVersionTable.PsVersion -gt [version]'6.0') {
            Start-Process 'pwsh' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -PortV3 $PortV3 -PortV3_1 $PortV3_1 -DisableTermination"   -NoNewWindow
        }
        else {
            Start-Process 'powershell' -ArgumentList "-NoProfile -File `"$scriptPath`" -Quiet -PortV3 $PortV3 -PortV3_1 $PortV3_1 -DisableTermination"  -NoNewWindow
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
                    if($value1 -is [string] -and $value2 -is [string]){
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

        Start-Sleep -Seconds 5
    }

    AfterAll {
        Start-Sleep -Seconds 5
        Invoke-RestMethod -Uri "$($Endpoint)/close" -Method Post | Out-Null

    }

    Describe 'OpenAPI' {
        it 'Open API v3.0.3' {

            Start-Sleep -Seconds 10
            $fileContent = Get-Content -Path "$PSScriptRoot/specs/OpenApi-TuttiFrutti_3.0.3.json"

            $webResponse = Invoke-WebRequest -Uri "http://localhost:$($PortV3)/docs/openapi/v3.0" -Method Get
            $json = $webResponse.Content
            if (   $PSVersionTable.PSEdition -eq 'Desktop') {
                $expected = $fileContent | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
                $response = $json | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
            }
            else {
                $expected = $fileContent | ConvertFrom-Json -AsHashtable
                $response = $json | ConvertFrom-Json -AsHashtable
            }

            Compare-Hashtable $response $expected | Should -BeTrue

        }

        it 'Open API v3.1.0' {
            $fileContent = Get-Content -Path "$PSScriptRoot/specs/OpenApi-TuttiFrutti_3.1.0.json"

            $webResponse = Invoke-WebRequest -Uri "http://localhost:$($PortV3_1)/docs/openapi/v3.1" -Method Get
            $json = $webResponse.Content
            if (  $PSVersionTable.PSEdition -eq 'Desktop') {
                $expected = $fileContent | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
                $response = $json | ConvertFrom-Json | Convert-PsCustomObjectToOrderedHashtable
            }
            else {
                $expected = $fileContent | ConvertFrom-Json -AsHashtable
                $response = $json | ConvertFrom-Json -AsHashtable
            }
            Compare-Hashtable $response $expected | Should -BeTrue
        }
    }

}