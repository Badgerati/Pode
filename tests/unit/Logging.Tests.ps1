[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

InModuleScope -ModuleName 'Pode' {
    Describe 'Get-PodeLogType' {
        It 'Returns null as the logger does not exist' {
            $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Types' = @{}; } }; }
            Get-PodeLogType -Name 'test' | Should -Be $null
        }

        It 'Returns terminal logger for name' {
            $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Types' = @{ 'test' = $null }; } }; }
            $result = (Get-PodeLogType -Name 'test')

            $result | Should -Be $null
        }

        It 'Returns custom logger for name' {
            $PodeContext = @{ 'Server' = @{ 'Logging' = @{ 'Types' = @{ 'test' = { Write-Host 'hello' } }; } }; }
            $result = (Get-PodeLogType -Name 'test')

            $result | Should -Not -Be $null
            $result.ToString() | Should -Be ({ Write-Host 'hello' }).ToString()
        }
    }

    Describe 'Write-PodeLog' {
        BeforeEach {
            $PodeContext = @{
                Server = @{
                    Logging = @{
                        Logger = [Pode.Utilities.Logging.PodeLogger]::new()
                    }
                }
            }
        }

        AfterEach {
            $PodeContext.Server.Logging.Logger.Dispose()
        }

        It 'Does nothing when logging disabled' {
            $PodeContext.Server.Logging.Logger.IsEnabled = $false
            Write-PodeLog -Name 'test' -InputObject 'test'

            $PodeContext.Server.Logging.Logger.Count | Should -Be 0
        }

        It 'Adds a log item' {
            $logType = [Pode.Utilities.Logging.PodeLogType]::new('test', @('Informational'))
            $PodeContext.Server.Logging.Logger.RegisterType($logType)

            Write-PodeLog -Name 'test' -InputObject 'test'

            $PodeContext.Server.Logging.Logger.Count | Should -Be 1

            $logItem = $null
            $PodeContext.Server.Logging.Logger.TryTake([ref]$logItem, [System.Threading.CancellationToken]::None) | Should -Be $true
            $logItem.Name | Should -Be 'test'
            $logItem.Item | Should -Be 'test'
        }
    }

    Describe 'Write-PodeErrorLog' {
        BeforeEach {
            $PodeContext = @{
                Server = @{
                    Logging = @{
                        Logger = [Pode.Utilities.Logging.PodeLogger]::new()
                    }
                }
            }
        }

        AfterEach {
            $PodeContext.Server.Logging.Logger.Dispose()
        }

        It 'Does nothing when logging disabled' {
            $PodeContext.Server.Logging.Logger.IsEnabled = $false

            try { throw 'some error' }
            catch {
                Write-PodeErrorLog -ErrorRecord $_
            }

            $PodeContext.Server.Logging.Logger.Count | Should -Be 0
        }

        It 'Adds an error log item' {
            $logType = [Pode.Utilities.Logging.PodeLogType]::new([Pode.Utilities.Logging.PodeLogger]::ERROR_LOG_TYPE_NAME, @('Error'))
            $PodeContext.Server.Logging.Logger.RegisterType($logType)

            try { throw 'some error' }
            catch {
                Write-PodeErrorLog -ErrorRecord $_
            }

            $PodeContext.Server.Logging.Logger.Count | Should -Be 1

            $logItem = $null
            $PodeContext.Server.Logging.Logger.TryTake([ref]$logItem, [System.Threading.CancellationToken]::None) | Should -Be $true
            $logItem.Item.Message | Should -Be 'some error'
        }

        It 'Adds an exception log item' {
            $logType = [Pode.Utilities.Logging.PodeLogType]::new([Pode.Utilities.Logging.PodeLogger]::ERROR_LOG_TYPE_NAME, @('Error'))
            $PodeContext.Server.Logging.Logger.RegisterType($logType)

            $exp = [exception]::new('some error')
            Write-PodeErrorLog -Exception $exp

            $logItem = $null
            $PodeContext.Server.Logging.Logger.TryTake([ref]$logItem, [System.Threading.CancellationToken]::None) | Should -Be $true
            $logItem.Item.Message | Should -Be 'some error'
        }

        It 'Does not log as Verbose not allowed' {
            $logType = [Pode.Utilities.Logging.PodeLogType]::new([Pode.Utilities.Logging.PodeLogger]::ERROR_LOG_TYPE_NAME, @('Error'))
            $PodeContext.Server.Logging.Logger.RegisterType($logType)

            $exp = [exception]::new('some error')
            Write-PodeErrorLog -Exception $exp -Level Verbose

            $PodeContext.Server.Logging.Logger.Count | Should -Be 0
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
}