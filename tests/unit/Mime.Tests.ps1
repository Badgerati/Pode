[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
    # Import Pode Assembly
    $helperPath = (Split-Path -Parent -Path $path) -ireplace 'unit', 'shared'
    . "$helperPath/TestHelper.ps1"
    Import-PodeAssembly -SrcPath $src
}

Describe 'Add-PodeMimeType' {
    Context 'Valid Parameters' {
        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.testtype') | Out-Null
            [Pode.PodeMimeTypes]::Remove('testtype2') | Out-Null
        }

        It 'Should add a new MIME type with dot prefix' {
            Add-PodeMimeType -Extension '.testtype' -MimeType 'application/test'
            [Pode.PodeMimeTypes]::Contains('.testtype') | Should -Be $true
            [Pode.PodeMimeTypes]::Get('.testtype') | Should -Be 'application/test'
        }

        It 'Should add a new MIME type without dot prefix' {
            Add-PodeMimeType -Extension 'testtype2' -MimeType 'application/test2'
            [Pode.PodeMimeTypes]::Contains('.testtype2') | Should -Be $true
            [Pode.PodeMimeTypes]::Get('.testtype2') | Should -Be 'application/test2'
        }

        It 'Should throw an error when trying to add an existing MIME type' {
            # Add initial mapping
            [Pode.PodeMimeTypes]::AddOrUpdate('.testtype', 'application/initial')

            # Try to add again - should throw
            { Add-PodeMimeType -Extension '.testtype' -MimeType 'application/updated' } | Should -Throw
        }

        It 'Should write verbose message when successful' {
            $verboseOutput = Add-PodeMimeType -Extension '.testtype' -MimeType 'application/test' -Verbose 4>&1
            $verboseOutput | Should -BeLike '*Added MIME type mapping: .testtype -> application/test*'
        }
    }

    Context 'Invalid Parameters' {
        It 'Should throw when Extension is null or empty' {
            { Add-PodeMimeType -Extension '' -MimeType 'application/test' } | Should -Throw
            { Add-PodeMimeType -Extension $null -MimeType 'application/test' } | Should -Throw
        }

        It 'Should throw when MimeType is null or empty' {
            { Add-PodeMimeType -Extension '.test' -MimeType '' } | Should -Throw
            { Add-PodeMimeType -Extension '.test' -MimeType $null } | Should -Throw
        }
    }
}

Describe 'Set-PodeMimeType' {
    Context 'Valid Parameters' {
        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.testtype') | Out-Null
        }

        It 'Should update an existing MIME type' {
            # Add initial mapping
            [Pode.PodeMimeTypes]::AddOrUpdate('.testtype', 'application/initial')

            # Update it
            Set-PodeMimeType -Extension '.testtype' -MimeType 'application/updated'
            [Pode.PodeMimeTypes]::Get('.testtype') | Should -Be 'application/updated'
        }

        It 'Should add a new MIME type if it does not exist' {
            Set-PodeMimeType -Extension '.testtype' -MimeType 'application/new'
            [Pode.PodeMimeTypes]::Contains('.testtype') | Should -Be $true
            [Pode.PodeMimeTypes]::Get('.testtype') | Should -Be 'application/new'
        }

        It 'Should write verbose message when successful' {
            $verboseOutput = Set-PodeMimeType -Extension '.testtype' -MimeType 'application/test' -Verbose 4>&1
            $verboseOutput | Should -BeLike '*Updated MIME type mapping: .testtype -> application/test*'
        }
    }

    Context 'Invalid Parameters' {
        It 'Should throw when Extension is null or empty' {
            { Set-PodeMimeType -Extension '' -MimeType 'application/test' } | Should -Throw
            { Set-PodeMimeType -Extension $null -MimeType 'application/test' } | Should -Throw
        }

        It 'Should throw when MimeType is null or empty' {
            { Set-PodeMimeType -Extension '.test' -MimeType '' } | Should -Throw
            { Set-PodeMimeType -Extension '.test' -MimeType $null } | Should -Throw
        }
    }
}

Describe 'Remove-PodeMimeType' {
    Context 'Valid Parameters' {
        BeforeEach {
            # Add test extension
            [Pode.PodeMimeTypes]::AddOrUpdate('.testtype', 'application/test')
        }

        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.testtype') | Out-Null
        }

        It 'Should remove an existing MIME type and return true' {
            Remove-PodeMimeType -Extension '.testtype'
            [Pode.PodeMimeTypes]::Contains('.testtype') | Should -Be $false
        }

        It 'Should work with extension without dot prefix' {
            [Pode.PodeMimeTypes]::AddOrUpdate('testtype2', 'application/test2')
            $result = Remove-PodeMimeType -Extension 'testtype2'
            [Pode.PodeMimeTypes]::Contains('.testtype2') | Should -Be $false
        }

        It 'Should write verbose message when successful' {
            $verboseOutput = Remove-PodeMimeType -Extension '.testtype' -Verbose 4>&1
            $verboseOutput | Should -BeLike '*Removed MIME type mapping for extension: .testtype*'
        }

        It 'Should write verbose message when not found' {
            $verboseOutput = Remove-PodeMimeType -Extension '.nonexistent' -Verbose 4>&1
            $verboseOutput | Should -BeLike '*No MIME type mapping found for extension: .nonexistent*'
        }
    }

    Context 'Invalid Parameters' {
        It 'Should throw when Extension is null or empty' {
            { Remove-PodeMimeType -Extension '' } | Should -Throw
            { Remove-PodeMimeType -Extension $null } | Should -Throw
        }
    }
}

Describe 'Get-PodeMimeType' {
    Context 'Valid Parameters' {
        BeforeEach {
            # Add test extension
            [Pode.PodeMimeTypes]::AddOrUpdate('.testtype', 'application/test')
        }

        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.testtype') | Out-Null
        }

        It 'Should return correct MIME type for existing extension' {
            $result = Get-PodeMimeType -Extension '.testtype'
            $result | Should -Be 'application/test'
        }

        It 'Should return correct MIME type for known extensions' {
            $result = Get-PodeMimeType -Extension '.json'
            $result | Should -Be 'application/json'
        }

        It 'Should work with extension without dot prefix' {
            $result = Get-PodeMimeType -Extension 'json'
            $result | Should -Be 'application/json'
        }

        It 'Should return default MIME type for unknown extension' {
            $result = Get-PodeMimeType -Extension '.unknown'
            $result | Should -Be 'application/octet-stream'
        }

        It 'Should return custom default MIME type for unknown extension' {
            $result = Get-PodeMimeType -Extension '.unknown' -DefaultMimeType 'text/plain'
            $result | Should -Be 'text/plain'
        }

        It 'Should write verbose message when extension not found' {
            $verboseOutput = Get-PodeMimeType -Extension '.unknown' -Verbose 4>&1
            $verboseOutput[0] | Should -BeLike 'No MIME type found for extension*'
        }

        It 'Should return string type' {
            $result = Get-PodeMimeType -Extension '.json'
            $result | Should -BeOfType [string]
        }
    }

    Context 'Invalid Parameters' {
        It 'Should throw when Extension is null or empty' {
            { Get-PodeMimeType -Extension '' } | Should -Throw
            { Get-PodeMimeType -Extension $null } | Should -Throw
        }
    }
}

Describe 'Test-PodeMimeType' {
    Context 'Valid Parameters' {
        BeforeEach {
            # Add test extension
            [Pode.PodeMimeTypes]::AddOrUpdate('.testtype', 'application/test')
        }

        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.testtype') | Out-Null
        }

        It 'Should return true for existing extension' {
            $result = Test-PodeMimeType -Extension '.testtype'
            $result | Should -Be $true
        }

        It 'Should return true for known extensions' {
            $result = Test-PodeMimeType -Extension '.json'
            $result | Should -Be $true
        }

        It 'Should work with extension without dot prefix' {
            $result = Test-PodeMimeType -Extension 'json'
            $result | Should -Be $true
        }

        It 'Should return false for unknown extension' {
            $result = Test-PodeMimeType -Extension '.unknown'
            $result | Should -Be $false
        }

        It 'Should return boolean type' {
            $result = Test-PodeMimeType -Extension '.json'
            $result | Should -BeOfType [bool]
        }
    }

    Context 'Invalid Parameters' {
        It 'Should throw when Extension is null or empty' {
            { Test-PodeMimeType -Extension '' } | Should -Throw
            { Test-PodeMimeType -Extension $null } | Should -Throw
        }
    }
}

Describe 'Import-PodeMimeTypeFromFile' {
    Context 'Valid File' {
        BeforeAll {
            # Create a test MIME types file
            $testFilePath = Join-Path $TestDrive 'test-mime.types'
            $testContent = @'
# Test MIME types file
application/json json
text/plain txt text
application/pdf pdf
application/custom-type custom1 custom2
'@
            Set-Content -Path $testFilePath -Value $testContent
        }

        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.custom1') | Out-Null
            [Pode.PodeMimeTypes]::Remove('.custom2') | Out-Null
        }

        It 'Should load MIME types from file' {
            Import-PodeMimeTypeFromFile -Path $testFilePath

            # Verify that custom types were loaded
            [Pode.PodeMimeTypes]::Contains('.custom1') | Should -Be $true
            [Pode.PodeMimeTypes]::Contains('.custom2') | Should -Be $true
            [Pode.PodeMimeTypes]::Get('.custom1') | Should -Be 'application/custom-type'
            [Pode.PodeMimeTypes]::Get('.custom2') | Should -Be 'application/custom-type'
        }

        It 'Should write verbose message when successful' {
            $verboseOutput = Import-PodeMimeTypeFromFile -Path $testFilePath -Verbose 4>&1
            $verboseOutput | Should -BeLike '*Loaded MIME type mappings from file:*'
        }
    }

    Context 'Invalid File' {
        It 'Should throw when file does not exist' {
            $nonExistentPath = Join-Path $TestDrive 'nonexistent.types'
            { Import-PodeMimeTypeFromFile -Path $nonExistentPath } | Should -Throw
        }

        It 'Should throw with localized message when file does not exist' {
            $nonExistentPath = Join-Path $TestDrive 'nonexistent.types'
            try {
                Import-PodeMimeTypeFromFile -Path $nonExistentPath
                $false | Should -Be $true # Should not reach here
            }
            catch {
                $_.Exception.Message | Should -BeLike "*$nonExistentPath*"
            }
        }
    }

    Context 'Invalid Parameters' {
        It 'Should throw when Path is null or empty' {
            { Import-PodeMimeTypeFromFile -Path '' } | Should -Throw
            { Import-PodeMimeTypeFromFile -Path $null } | Should -Throw
        }
    }
}

Describe 'Integration Tests' {
    Context 'End-to-End Workflow' {
        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.workflow1') | Out-Null
            [Pode.PodeMimeTypes]::Remove('.workflow2') | Out-Null
        }

        It 'Should support complete add, get, update, remove workflow' {
            # Add a MIME type
            Add-PodeMimeType -Extension '.workflow1' -MimeType 'application/workflow-v1'
            Test-PodeMimeType -Extension '.workflow1' | Should -Be $true
            Get-PodeMimeType -Extension '.workflow1' | Should -Be 'application/workflow-v1'

            # Update the MIME type using Set-PodeMimeType
            Set-PodeMimeType -Extension '.workflow1' -MimeType 'application/workflow-v2'
            Get-PodeMimeType -Extension '.workflow1' | Should -Be 'application/workflow-v2'

            # Remove the MIME type
            Remove-PodeMimeType -Extension '.workflow1'
            Test-PodeMimeType -Extension '.workflow1' | Should -Be $false
        }

        It 'Should handle multiple extensions with same MIME type' {
            Add-PodeMimeType -Extension '.workflow1' -MimeType 'application/workflow'
            Add-PodeMimeType -Extension '.workflow2' -MimeType 'application/workflow'

            Get-PodeMimeType -Extension '.workflow1' | Should -Be 'application/workflow'
            Get-PodeMimeType -Extension '.workflow2' | Should -Be 'application/workflow'

            # Remove one should not affect the other
            Remove-PodeMimeType -Extension '.workflow1'
            Test-PodeMimeType -Extension '.workflow1' | Should -Be $false
            Test-PodeMimeType -Extension '.workflow2' | Should -Be $true
        }
    }

    Context 'Case Sensitivity' {
        AfterEach {
            # Clean up test extensions
            [Pode.PodeMimeTypes]::Remove('.case') | Out-Null
            [Pode.PodeMimeTypes]::Remove('.CASE') | Out-Null
        }

        It 'Should be case-insensitive for extensions' {
            Add-PodeMimeType -Extension '.case' -MimeType 'application/test'

            # Should find with different case
            Test-PodeMimeType -Extension '.CASE' | Should -Be $true
            Get-PodeMimeType -Extension '.Case' | Should -Be 'application/test'

            # Remove with different case should work
            Remove-PodeMimeType -Extension '.CASE'
            Test-PodeMimeType -Extension '.case' | Should -Be $false
        }
    }
}
