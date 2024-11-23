[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ } 
}


Describe 'Register-PodeService' {
    BeforeAll {
        Mock -CommandName Confirm-PodeAdminPrivilege
        Mock -CommandName Register-PodeMonitorWindowsService { return  $true }
        Mock -CommandName Register-PodeLinuxService { return  $true }
        Mock -CommandName Register-PodeMacService { return  $true }
        Mock -CommandName Start-PodeService { return  $true }
        Mock -CommandName New-Item
        Mock -CommandName ConvertTo-Json
        Mock -CommandName Set-Content
        Mock -CommandName Get-Process
        Mock -CommandName Get-Module { return @{ModuleBase = $pwd } }
    }


    Context 'With valid parameters' {


        It 'Registers a Windows service successfully'  -Skip:(!$IsWindows) {

            # Arrange
            $params = @{
                Name               = 'TestService'
                Description        = 'Test Description'
                DisplayName        = 'Test Service Display Name'
                StartupType        = 'Automatic'
                ParameterString    = '-Verbose'
                LogServicePodeHost = $true
                Start              = $true
            }
            #  Mock -CommandName (Get-Process -Id $PID).Path -MockWith { 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' }

            # Act
            Register-PodeService @params

            # Assert
            Assert-MockCalled -CommandName Confirm-PodeAdminPrivilege -Exactly 1
            Assert-MockCalled -CommandName Register-PodeMonitorWindowsService -Exactly 1
            Assert-MockCalled -CommandName Start-PodeService -Exactly 1
        }

        It 'Registers a Linux service successfully' -Skip:(!$IsLinux) {

            $params = @{
                Name        = 'LinuxTestService'
                Description = 'Linux Test Service'
                Start       = $true
            }

            # Act
            Register-PodeService @params

            # Assert
            Assert-MockCalled -CommandName Register-PodeLinuxService -Exactly 1
            Assert-MockCalled -CommandName Start-PodeService -Exactly 1
        }

        It 'Registers a macOS service successfully' -Skip:(!$IsMacOS) {
            # Arrange
            $params = @{
                Name        = 'MacTestService'
                Description = 'macOS Test Service'
                Start       = $true
            }

            # Act
            Register-PodeService @params

            # Assert
            Assert-MockCalled -CommandName Register-PodeMacService -Exactly 1
            Assert-MockCalled -CommandName Start-PodeService -Exactly 1
        }
    }

    Context 'With invalid parameters' {
        It 'Throws an error if Name is missing' {
            # Act & Assert
            { Register-PodeService -Name $null -Description 'Missing Name' } | Should -Throw
        }

        It 'Throws an error if Password is missing for a specified WindowsUser' -Skip:(!$IsWindows) {
            # Arrange
            $params = @{
                Name        = 'TestService'
                WindowsUser = 'TestUser'
            }

            # Act & Assert
            Register-PodeService @params -ErrorAction SilentlyContinue | Should -BeFalse
        }
    }

}
Describe 'Start-PodeService' {
    BeforeAll {
        # Mock the required commands
        Mock -CommandName Confirm-PodeAdminPrivilege
        Mock -CommandName Invoke-PodeWinElevatedCommand
        Mock -CommandName Test-PodeLinuxServiceIsRegistered
        Mock -CommandName Test-PodeLinuxServiceIsActive
        Mock -CommandName Start-PodeLinuxService
        Mock -CommandName Test-PodeMacOsServiceIsRegistered
        Mock -CommandName Test-PodeMacOsServiceIsActive
        Mock -CommandName Start-PodeMacOsService
        Mock -CommandName Write-PodeErrorLog
        Mock -CommandName Write-Error
    }

    Context 'On Windows platform' {
        It 'Starts a stopped service successfully' -Skip:(!$IsWindows) {
            # Mock a stopped service and simulate it starting
            $script:status = 'none'
            Mock -CommandName Get-Service -MockWith {
                if ($script:status -eq 'none') {
                    $script:status = 'Stopped'
                }
                else {
                    $script:status = 'Running'
                }
                [pscustomobject]@{ Name = 'TestService'; Status = $status }
            }
            Mock -CommandName Invoke-PodeWinElevatedCommand -MockWith { $null }

            # Act
            Start-PodeService -Name 'TestService' | Should -Be $true

            # Assert
            Assert-MockCalled -CommandName Invoke-PodeWinElevatedCommand -Exactly 1
        }

        It 'Starts a started service ' -Skip:(!$IsWindows) {
            Mock -CommandName Invoke-PodeWinElevatedCommand -MockWith { $null }
            Mock -CommandName Get-Service -MockWith {
                [pscustomobject]@{ Name = 'TestService'; Status = 'Running' }
            }

            # Act
            Start-PodeService -Name 'TestService' | Should -Be $true

            # Assert
            Assert-MockCalled -CommandName Invoke-PodeWinElevatedCommand -Exactly 0
        }


        It 'Throws an error if the service is not registered' -Skip:(!$IsWindows) {

            Start-PodeService -Name 'NonExistentService' -ErrorAction SilentlyContinue | Should -BeFalse
        }
    }

    Context 'On Linux platform' {
        It 'Starts a stopped service successfully' -Skip:(!$IsLinux) {
            $script:status = $null
            Mock -CommandName Test-PodeLinuxServiceIsActive -MockWith {
                if ($null -eq $script:status ) {
                    $script:status = $false
                }
                else {
                    $script:status = $true
                }
                return  $script:status
            }

            Mock -CommandName Test-PodeLinuxServiceIsRegistered -MockWith { $true }
            Mock -CommandName Start-PodeLinuxService -MockWith { $true }

            # Act
            Start-PodeService -Name 'TestService' | Should -Be $true

            # Assert
            Assert-MockCalled -CommandName Start-PodeLinuxService -Exactly 1
        }

        It 'Starts a started service ' -Skip:(!$IsLinux) {

            Mock -CommandName Test-PodeLinuxServiceIsActive -MockWith { $true }
            Mock -CommandName Test-PodeLinuxServiceIsRegistered -MockWith { $true }
            Mock -CommandName Start-PodeLinuxService -MockWith { $true }

            # Act
            Start-PodeService -Name 'TestService' | Should -Be $true

            # Assert
            Assert-MockCalled -CommandName Start-PodeLinuxService -Exactly 0
        }

        It 'Return false if the service is not registered' -Skip:(!$IsLinux) {
            Mock -CommandName Test-PodeLinuxServiceIsRegistered -MockWith { $false }
            Start-PodeService -Name 'NonExistentService' | Should -BeFalse
        }
    }

    Context 'On macOS platform' {
        It 'Starts a stopped service successfully' -Skip:(!$IsMacOS) {
            Mock -CommandName Test-PodeMacOsServiceIsRegistered -MockWith { $true }
            Mock -CommandName Start-PodeMacOsService -MockWith { $true }

            $script:status = $null
            Mock -CommandName Test-PodeMacOsServiceIsActive -MockWith {
                if ($null -eq $script:status ) {
                    $script:status = $false
                }
                else {
                    $script:status = $true
                }
                return  $script:status
            }

            # Act
            Start-PodeService -Name 'MacService' | Should -Be $true

            # Assert
            Assert-MockCalled -CommandName Start-PodeMacOsService -Exactly 1
        }

        It 'Return false if the service is not registered' -Skip:(!$IsMacOS) {
            Mock -CommandName Test-PodeMacOsServiceIsRegistered -MockWith { $false }

            Start-PodeService -Name 'NonExistentService' | Should -BeFalse
        }
    }
}

