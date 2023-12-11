
$users = @{}

function Initialize-Users {
    $Script:users=@{}

    Add-User -Id 1 -Username  'user1' -FirstName 'first name 1' -LastName 'last name 1' -Email 'email1@test.com' -Phone '123-456-7890' -UserStatus 1

    Add-User -Id 2 -Username  'user1' -FirstName 'first name 2' -LastName 'last name 2' -Email 'email2@test.com' -Phone '123-456-7890' -UserStatus 2

    Add-User -Id 3 -Username  'user1' -FirstName 'first name 3' -LastName 'last name 3' -Email 'email3@test.com' -Phone '123-456-7890' -UserStatus 3

    Add-User -Id 4 -Username  'user1' -FirstName 'first name 4' -LastName 'last name 4' -Email 'email4@test.com' -Phone '123-456-7890' -UserStatus 1

    Add-User -Id 5 -Username  'user1' -FirstName 'first name 5' -LastName 'last name 5' -Email 'email5@test.com' -Phone '123-456-7890' -UserStatus 2

    Add-User -Id 6 -Username  'user1' -FirstName 'first name 6' -LastName 'last name 6' -Email 'email6@test.com' -Phone '123-456-7890' -UserStatus 3

    Add-User -Id 7 -Username  'user1' -FirstName 'first name 7' -LastName 'last name 7' -Email 'email7@test.com' -Phone '123-456-7890' -UserStatus 1

    Add-User -Id 8 -Username  'user1' -FirstName 'first name 8' -LastName 'last name 8' -Email 'email8@test.com' -Phone '123-456-7890' -UserStatus 2

    Add-User -Id 9 -Username  'user1' -FirstName 'first name 9' -LastName 'last name 9' -Email 'email9@test.com' -Phone '123-456-7890' -UserStatus 3

    Add-User -Id 10 -Username  'user10' -FirstName 'first name 10' -LastName 'last name 10' -Email 'email10@test.com' -Phone '123-456-7890' -UserStatus 1

    Add-User -Id 11 -Username  'user?10' -FirstName 'first name ?10' -LastName 'last name ?10' -Email 'email101@test.com' -Phone '123-456-7890' -UserStatus 1

}
function Add-User {

    param (
        [Parameter(Mandatory )]
        [long]
        $Id,
        [Parameter(Mandatory )]
        [String]
        $Username,
        [Parameter(Mandatory )]
        [String]
        $FirstName,
        [Parameter(Mandatory )]
        [String]
        $LastName,
        [Parameter(Mandatory )]
        [String]
        $Email,
        [Parameter(Mandatory )]
        [String]
        $Phone,
        [Parameter(Mandatory )]
        [int]
        $UserStatus
    )
    $users[$Id] = @{
        id         = $Id
        username   = $Username
        firstName  = $FirstName
        lastName   = $LastName
        email      = $Email
        password   = 'XXXXXXXXXXX'
        phone      = $Phone
        userStatus = $UserStatus
    }

}


function Remove-User {
    param (
        [Parameter(Mandatory )]
        [String]
        $Username
    )
    foreach ($u in $users.Values) {
        if ($u.username -eq $Username) {
            $id = $u.id
            break
        }
    }
    if ($id) {
        $users.Remove($id)
    }
}

function Find-User {
    param (
        [Parameter(Mandatory )]
        [String]
        $Username
    )
    foreach ($u in $users.Values) {
        if ($u.username -eq $Username) {
            return $u
        }
    }
}