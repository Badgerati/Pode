
function Initialize-Users {
    param (
        [switch]
        $Reset
    )
    New-PodeLockable -Name 'UserLock'
    if ($Reset.IsPresent) {
        Lock-PodeObject -Name 'UserLock' -ScriptBlock {
            Set-PodeState -Scope 'Users' -Name 'users' -Value @{} | Out-Null
            Add-User -Id 1 -Username  'user1' -FirstName 'first name 1' -LastName 'last name 1' -Email 'email1@test.com' -Phone '123-456-7890' -UserStatus 1

            Add-User -Id 2 -Username  'user2' -FirstName 'first name 2' -LastName 'last name 2' -Email 'email2@test.com' -Phone '123-456-7890' -UserStatus 2

            Add-User -Id 3 -Username  'user3' -FirstName 'first name 3' -LastName 'last name 3' -Email 'email3@test.com' -Phone '123-456-7890' -UserStatus 3

            Add-User -Id 4 -Username  'user4' -FirstName 'first name 4' -LastName 'last name 4' -Email 'email4@test.com' -Phone '123-456-7890' -UserStatus 1

            Add-User -Id 5 -Username  'user5' -FirstName 'first name 5' -LastName 'last name 5' -Email 'email5@test.com' -Phone '123-456-7890' -UserStatus 2

            Add-User -Id 6 -Username  'user6' -FirstName 'first name 6' -LastName 'last name 6' -Email 'email6@test.com' -Phone '123-456-7890' -UserStatus 3

            Add-User -Id 7 -Username  'user7' -FirstName 'first name 7' -LastName 'last name 7' -Email 'email7@test.com' -Phone '123-456-7890' -UserStatus 1

            Add-User -Id 8 -Username  'user8' -FirstName 'first name 8' -LastName 'last name 8' -Email 'email8@test.com' -Phone '123-456-7890' -UserStatus 2

            Add-User -Id 9 -Username  'user9' -FirstName 'first name 9' -LastName 'last name 9' -Email 'email9@test.com' -Phone '123-456-7890' -UserStatus 3

            Add-User -Id 10 -Username  'user10' -FirstName 'first name 10' -LastName 'last name 10' -Email 'email10@test.com' -Phone '123-456-7890' -UserStatus 1

            Add-User -Id 11 -Username  'user?10' -FirstName 'first name ?10' -LastName 'last name ?10' -Email 'email101@test.com' -Phone '123-456-7890' -UserStatus 1
        }
    }
}
function Add-User {

    [CmdletBinding(DefaultParameterSetName = 'Items')]
    param (
        [Parameter(Mandatory , ParameterSetName = 'Items')]
        [long]
        $Id,
        [Parameter(Mandatory , ParameterSetName = 'Items')]
        [String]
        $Username,
        [Parameter(Mandatory , ParameterSetName = 'Items')]
        [String]
        $FirstName,
        [Parameter(Mandatory , ParameterSetName = 'Items')]
        [String]
        $LastName,
        [Parameter(Mandatory , ParameterSetName = 'Items')]
        [String]
        $Email,
        [Parameter(Mandatory , ParameterSetName = 'Items')]
        [String]
        $Phone,
        [Parameter(Mandatory  , ParameterSetName = 'Items')]
        [int]
        $UserStatus,
        [Parameter(Mandatory, ParameterSetName = 'Object')]
        [hashtable]
        $User
    )
    return Lock-PodeObject -Name 'UserLock' -Return -ScriptBlock {
        $users = Get-PodeState -Name 'users'
        switch ($PSCmdlet.ParameterSetName) {
            'Items' {
                $users[$Username] = @{
                    id         = $Id
                    username   = $Username
                    firstName  = $FirstName
                    lastName   = $LastName
                    email      = $Email
                    password   = 'XXXXXXXXXXX'
                    phone      = $Phone
                    userStatus = $UserStatus
                }
                return  $users[$Username]
            }
            'Object' {
                $users[$User.username] = $User
                return  $User
            }
        }
    }
}


function Remove-User {
    param (
        [Parameter(Mandatory )]
        [String]
        $Username
    )
    Lock-PodeObject -Name 'UserLock' -ScriptBlock {
        $users = Get-PodeState -Name 'users'
        $users.Remove( $Username)
    }
}

function Get-User {
    param (
        [Parameter(Mandatory )]
        [String]
        $Username
    )
    return  Lock-PodeObject -Name 'UserLock' -Return -ScriptBlock {
        $users = Get-PodeState -Name 'users'
        return $users[$username]
    }
}

function Test-User {
    param (
        [Parameter(Mandatory )]
        [String]
        $Username
    )
    return  Lock-PodeObject -Name 'UserLock' -Return -ScriptBlock {
        $users = Get-PodeState -Name 'users'
        return $users.containsKey($username)
    }
}


Export-ModuleMember -Function Initialize-Users
Export-ModuleMember -Function Get-User
Export-ModuleMember -Function Add-User
Export-ModuleMember -Function Test-User
Export-ModuleMember -Function Remove-User