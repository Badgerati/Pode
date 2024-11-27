[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()



Describe 'Service Lifecycle' {

    it 'register' {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Register
        $success | Should -BeTrue
        Start-Sleep 10
        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        if ($IsMacOS) {
            $status.Status | Should -Be 'Running'
            $status.Pid | Should -BeGreaterThan 0
        }
        else {
            $status.Status | Should -Be 'Stopped'
            $status.Pid | Should -Be 0
        }

        $status.Name | Should -Be 'Hello Service'

    }


    it 'start' -Skip:( $IsMacOS) {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Start
        $success | Should -BeTrue
        Start-Sleep 2
        $webRequest = Invoke-WebRequest -uri http://localhost:8080 -ErrorAction SilentlyContinue
        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Running'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -BeGreaterThan 0
        $webRequest.Content | Should -Be 'Hello, Service!'
    }

    it  'pause' {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Suspend
        $success | Should -BeTrue
        Start-Sleep 2
        #  $webRequest = Invoke-WebRequest -uri http://localhost:8080 -ErrorAction SilentlyContinue
        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Suspended'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -BeGreaterThan 0
        # $webRequest | Should -BeNullOrEmpty
    }

    it  'resume' {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -resume
        $success | Should -BeTrue
        Start-Sleep 2
        $webRequest = Invoke-WebRequest -uri http://localhost:8080 -ErrorAction SilentlyContinue
        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Running'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -BeGreaterThan 0
        $webRequest.Content | Should -Be 'Hello, Service!'
    }
    it 'stop' {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Stop
        $success | Should -BeTrue
        Start-Sleep 2
        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Stopped'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -Be 0

        { Invoke-WebRequest -uri http://localhost:8080 } | Should -Throw
    }

    it 're-start' {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Start
        $success | Should -BeTrue
        Start-Sleep 2
        $webRequest = Invoke-WebRequest -uri http://localhost:8080 -ErrorAction SilentlyContinue
        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Running'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -BeGreaterThan 0
        $webRequest.Content | Should -Be 'Hello, Service!'
    }


    it 're-stop' {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Stop
        $success | Should -BeTrue
        Start-Sleep 2

        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Stopped'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -Be 0

        { Invoke-WebRequest -uri http://localhost:8080 } | Should -Throw
    }

    it 'unregister' {
        $success = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Unregister
        $success | Should -BeTrue
        Start-Sleep 2
        $status = & "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status | Should -BeNullOrEmpty
    }

}