# User File

Pode's inbuilt user file authentication works cross-platform, relying just on a JSON file with an array of valid users.

This authenticator can only be used with Basic and Form. Custom is also supported, but a username and password must be supplied.

## Usage

To use user file authentication you can use the [`Add-PodeAuthUserFile`](../../../../Functions/Authentication/Add-PodeAuthUserFile) function. The following example will validate a user's credentials, supplied via a web-form, against the default user file at `./users.json` from the server's root:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login'
}
```

### File Format

The default users file is `./users.json` at the root of the server. You can supply a custom file path using the `-FilePath` parameter.

The users file is a JSON array of user objects, each user object must contain the following (metadata is optional):

| Name | Type | Description |
| ---- | ---- | ----------- |
| Username | string | The user's username |
| Name | string | The user's fullname |
| Email | string | The user's email address |
| Password | string | Either a SHA256 or an HMAC SHA256 of the user's password |
| Groups | string[] | An array of groups which the the user is a member |
| Metadata | psobject | Custom metadata for the user |

For example:

```json
[
    {
        "Name": "Joe Bloggs",
        "Username": "j.bloggs",
        "Email": "j.bloggs@company.com",
        "Password": "XohImNooBHFR0OVvjcYpJ3NgPQ1qq73WKhHvch0VQtg=",
        "Groups": [
            "Admin",
            "Developer"
        ],
        "Metadata": {
            "Created": "2001-01-01"
        }
    }
]
```

### HMAC Passwords

The password is normally a standard SHA256 hash, but Pode does support HMAC SHA256 hashes as well. If you use an HMAC hash, you can specify the secret used as follows:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login' -HmacSecret '<some-secret>'
}
```

### User Object

The User object returned, and accessible on Routes, and other functions via the [web event](../../../WebEvent)'s `$WebEvent.Auth.User` property, will contain the following information:

| Name | Type | Description |
| ---- | ---- | ----------- |
| Username | string | The user's username |
| Name | string | The user's fullname |
| Email | string | The user's email address |
| Groups | string[] | An array of groups which the the user is a member |
| Metadata | psobject | Custom metadata for the user |

Such as:

```powershell
Add-PodeRoute -Method Get -Path '/info' -Authentication 'Login' -ScriptBlock {
    Write-Host $WebEvent.Auth.User.Username
}
```

### Groups

You can supply a list of group names to validate that users are a member of them. If you supply multiple group names, the user only needs to be a of one of the groups. You can supply the list of groups to the function's `-Groups` parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login' -Groups @('admins', 'devops')
}
```

If an user being authenticated is not in one of these groups, then a 401 is returned.

### Users

You can supply a list of authorised usernames to validate a user's access, after credentials are validated, and instead of of checking AD groups. You can supply the list of usernames to the function's `-Users` parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login' -Users @('jsnow', 'rsanchez')
}
```

If an user being authenticated is not one of the allowed users, then a 401 is returned.

### Additional Validation

Similar to the normal [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth), [`Add-PodeAuthUserFile`](../../../../Functions/Authentication/Add-PodeAuthUserFile) can be supplied can an optional ScriptBlock parameter. This ScriptBlock is supplied the found User object as a parameter, structured as details above. You can then use this to further check the user, or load additional user information from another storage.

The ScriptBlock has the same return rules as [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth), as can be seen in the [Overview](../../Overview).

For example, to return the user back:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login' -ScriptBlock {
    param($user)

    # check or load extra data

    return @{ User = $user }
}
```

Or to fail authentication with an error message:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthUserFile -Name 'Login' -ScriptBlock {
    param($user)
    return @{ Message = 'Authorisation failed' }
}
```
