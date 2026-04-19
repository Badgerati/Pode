InModuleScope -ModuleName 'Pode' {
    Describe 'Get-PodeRandomName' {
        It 'Returns correct name' {
            Mock 'Get-Random' { return 0 }
            Get-PodeRandomName | Should -Be 'admiring_almeida'
        }
    }
}