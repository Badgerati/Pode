[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
param()



Describe 'Service Lifecycle' {

    it 'register' {
        . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Register
        $status = . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Stopped'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -Be 0
    }


    it 'start' {
        . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Start
        Start-Sleep 2
        $webRequest = Invoke-WebRequest -uri http://localhost:8080 -ErrorAction SilentlyContinue
        $status = . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Running'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -BeGreaterThan 0
        $webRequest.Content | Should -Be 'Hello, Service!'
    }

    it  'pause' {
        . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Suspend
        Start-Sleep 2
      #  $webRequest = Invoke-WebRequest -uri http://localhost:8080 -ErrorAction SilentlyContinue
        $status = . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Suspended'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -BeGreaterThan 0
       # $webRequest | Should -BeNullOrEmpty
    }

    it  'resume' {
        . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -resume
        Start-Sleep 2
        $webRequest = Invoke-WebRequest -uri http://localhost:8080 -ErrorAction SilentlyContinue
        $status = . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Running'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -BeGreaterThan 0
        $webRequest.Content | Should -Be 'Hello, Service!'
    }
    it 'stop' {
        . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Stop
        Start-Sleep 2


        $status = . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status.Status | Should -Be 'Stopped'
        $status.Name | Should -Be 'Hello Service'
        $status.Pid | Should -Be 0

         {Invoke-WebRequest -uri http://localhost:8080  }| Should -Throw


    }
    it 'unregister' {
        . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Unregister
        $status = . "$($PSScriptRoot)\..\..\examples\HelloService\HelloService.ps1" -Query
        $status | Should -BeNullOrEmpty
    }

}