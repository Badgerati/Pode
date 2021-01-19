# Windows Local Users

Pode's inbuilt Windows local user authentication works only on Windows.

This authenticator can only be used with the Basic and Form schemes. Custom is also supported, but a username and password must be supplied.

## Usage

To enable Windows local user authentication you can use the [`Add-PodeAuthWindowsLocal`](../../../../Functions/Authentication/Add-PodeAuthWindowsLocal) function. The following example will validate a user's credentials, supplied via a web-form, against the local users:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'Login'
}
```

### User Object

The User object returned, and accessible on Routes, and other functions via `$WebEvent.Auth.User`, will contain the following information:

| Name | Type | Description |
| ---- | ---- | ----------- |
| UserType | string | Value is fixed to Local |
| AuthenticationType | string | Value is fixed to WinNT |
| Username | string | The user's username |
| Name | string | The user's fullname |
| FQDN | string | The Computer Name |
| Domain | string | Value is fixed to localhost |
| Groups | string[] | All groups of which the the user is a member |

Such as:

```powershell
Add-PodeRoute -Method Get -Path '/info' -Authentication 'Login' -ScriptBlock {
    Write-Host $WebEvent.Auth.User.Username
}
```

### Groups

You can supply a list of group names to validate that users are a member of them. If you supply multiple group names, the user only needs to be a member of one of the groups. You can supply the list of groups to the function's `-Groups` parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'Login' -Groups @('admins', 'devops')
}
```

If an user being authenticated is not in one of these groups, then a 401 is returned.

### Users

You can supply a list of authorised usernames to validate a user's access, after credentials are validated, and instead of of checking groups. You can supply the list of usernames to the function's `-Users` parameter as an array - the list is not case-sensitive:

```powershell
Start-PodeServer {
    New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'Login' -Users @('jsnow', 'rsanchez')
}
```

If an user being authenticated is not one of the allowed users, then a 401 is returned.

### Additional Validation

Similar to the normal [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth), [`Add-PodeAuthWindowsLocal`](../../../../Functions/Authentication/Add-PodeAuthWindowsLocal) can be supplied can an optional ScriptBlock parameter. This ScriptBlock is supplied the found User object as a parameter, structured as details above. You can then use this to further check the user, or load additional user information from another storage.

The ScriptBlock has the same return rules as [`Add-PodeAuth`](../../../../Functions/Authentication/Add-PodeAuth), as can be seen in the [Overview](../../Overview).

For example, to return the user back:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'Login' -ScriptBlock {
    param($user)

    # check or load extra data

    return @{ User = $user }
}
```

Or to fail authentication with an error message:

```powershell
New-PodeAuthScheme -Form | Add-PodeAuthWindowsLocal -Name 'Login' -ScriptBlock {
    param($user)
    return @{ Message = 'Authorisation failed' }
}
```
