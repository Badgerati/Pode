[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()
BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'
    if (!([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Pode' })) {

        # fetch the .net version and the libs path
        $version = [System.Environment]::Version.Major
        $libsPath = Join-Path -Path $src -ChildPath 'Libs'

        # filter .net dll folders based on version above, and get path for latest version found
        if (![string]::IsNullOrWhiteSpace($version)) {
            $netFolder = Get-ChildItem -Path $libsPath -Directory -Force |
                Where-Object { $_.Name -imatch "net[1-$($version)]" } |
                Sort-Object -Property Name -Descending |
                Select-Object -First 1 -ExpandProperty FullName
        }

        # use netstandard if no folder found
        if ([string]::IsNullOrWhiteSpace($netFolder)) {
            $netFolder = "$($libsPath)/netstandard2.0"
        }

        # append Pode.dll and mount
        Add-Type -LiteralPath "$($netFolder)/Pode.dll" -ErrorAction Stop
    }
    [Pode.PodeLogger]::Enabled = $true

}
Describe 'Get-PodeLogger' {
    It 'Returns null as the logger does not exist' {
        $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Type' = @{}; } }; }
        Get-PodeLogger -Name 'test' | Should -Be $null
    }

    It 'Returns terminal logger for name' {
        $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Type' = @{ 'test' = $null }; } }; }
        $result = (Get-PodeLogger -Name 'test')

        $result | Should -Be $null
    }

    It 'Returns custom logger for name' {
        $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Type' = @{ 'test' = { Write-PodeHost 'hello' } }; } }; }
        $result = (Get-PodeLogger -Name 'test')

        $result | Should -Not -Be $null
        $result.ToString() | Should -Be ({ Write-PodeHost 'hello' }).ToString()
    }
}

Describe 'Write-PodeLog' {
    BeforeEach {
        $PodeContext = @{
            Server = @{
                Logging = @{
                    LogsToProcess = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
                    Type          = @{
                        test = @{
                            Standard = $false
                        }
                    }
                }
            }
        }
    }
    It 'Does nothing when logging disabled' {
        Mock Test-PodeLoggerEnabled { return $false }

        Write-PodeLog -Name 'test' -InputObject 'test'

        [Pode.PodeLogger]::Count | Should -Be 0
    }

    It 'Adds a log item' {
        Mock Test-PodeLoggerEnabled { return $true }
        Mock  Get-PodeLoggingLevel { return @('Informational') }
        Write-PodeLog -Name 'test' -InputObject 'test'

        [Pode.PodeLogger]::Count | Should -Be 1
        $item = [Pode.PodeLogger]::Dequeue()
        $item.Name | Should -Be 'test'
        $item.Item | Should -Be 'test'
    }
}

Describe 'Write-PodeErrorLog' {
    BeforeEach {
        $PodeContext = @{
            Server = @{
                Logging = @{
                    Type = @{
                        test = @{
                            Standard = $false
                        }
                    }
                }
            }
        }
    }
    It 'Does nothing when logging disabled' {
        Mock Test-PodeLoggerEnabled { return $false }

        Write-PodeLog -Name 'test' -InputObject 'test'

        [Pode.PodeLogger]::Count | Should -Be 0
    }

    It 'Adds an error log item' {
        Mock Test-PodeLoggerEnabled { return $true }
        Mock Get-PodeLogger { return @{ Arguments = @{
                    Levels = @('Error')
                }
            }
        }


        try { throw 'some error' }
        catch {
            Write-PodeErrorLog -ErrorRecord $Error[0]
        }

        [Pode.PodeLogger]::Count | Should -Be 1
        $item = [Pode.PodeLogger]::Dequeue()
        $item.Item.Message | Should -Be 'some error'
    }

    It 'Adds an exception log item' {
        Mock Test-PodeLoggerEnabled { return $true }
        Mock Get-PodeLogger { return @{ Arguments = @{
                    Levels = @('Error')
                }
            } }

        $exp = [exception]::new('some error')
        Write-PodeErrorLog -Exception $exp

        [Pode.PodeLogger]::Count | Should -Be 1
        $item = [Pode.PodeLogger]::Dequeue()
        $item.Item.Message | Should -Be 'some error'
    }

    It 'Does not log as Verbose not allowed' {
        Mock Test-PodeLoggerEnabled { return $true }
        Mock Get-PodeLogger { return @{ Arguments = @{
                    Levels = @('Error')
                }
            } }

        $exp = [exception]::new('some error')
        Write-PodeErrorLog -Exception $exp -Level Verbose
        $item = [Pode.PodeLogger]::Dequeue()
        [Pode.PodeLogger]::Count | Should -Be 0
    }
}

Describe '[Pode.PodeLogger]::RequestLogName' {
    It 'Returns logger name' {
        [Pode.PodeLogger]::RequestLogName | Should -Be '__pode_log_requests__'
    }
}

Describe '[Pode.PodeLogger]::ErrorLogName' {
    It 'Returns logger name' {
        [Pode.PodeLogger]::ErrorLogName | Should -Be '__pode_log_errors__'
    }
}

Describe 'Protect-PodeLogItem' {
    BeforeEach {
        $item = 'Password=Hunter2, Email'
    }
    It 'Do nothing with no masks' {
        $PodeContext = @{ Server = @{ Logging = @{ Masking = @{
                        Patterns = @()
                    }
                }
            }
        }

        Protect-PodeLogItem -Item $item | Should -Be $item
    }

    It 'Mask whole item' {
        $PodeContext = @{ Server = @{ Logging = @{ Masking = @{
                        Patterns = @('Password\=[a-z0-9]+')
                        Mask     = '********'
                    }
                }
            }
        }

        Protect-PodeLogItem -Item $item | Should -Be '********, Email'
    }

    It 'Mask item but keep before' {
        $PodeContext = @{ Server = @{ Logging = @{ Masking = @{
                        Patterns = @('(?<keep_before>Password\=)[a-z0-9]+')
                        Mask     = '********'
                    }
                }
            }
        }

        Protect-PodeLogItem -Item $item | Should -Be 'Password=********, Email'
    }

    It 'Mask item but keep after' {
        $PodeContext = @{ Server = @{ Logging = @{ Masking = @{
                        Patterns = @('Password\=(?<keep_after>[a-z0-9]+)')
                        Mask     = '********'
                    }
                }
            }
        }

        Protect-PodeLogItem -Item $item | Should -Be '********Hunter2, Email'
    }

    It 'Mask item but keep before and after' {
        $PodeContext = @{ Server = @{ Logging = @{ Masking = @{
                        Patterns = @('(?<keep_before>Password\=)(?<keep_after>[a-z0-9]+)')
                        Mask     = '********'
                    }
                }
            }
        }

        Protect-PodeLogItem -Item $item | Should -Be 'Password=********Hunter2, Email'
    }
}