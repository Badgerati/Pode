# Overview

Authorisation can either be used in conjunction with [Authentication](../../Authentication/Overview) and [Routes](../../Routes/Overview), or on it's own for custom scenarios.

When used with Authentication, Pode can automatically authorise access to Routes based on Roles; Groups; Scopes; Users; or custom validation logic for you. When authorisation fails Pode will respond with an HTTP 403 status code.

With authentication, Pode will set the following properties on the `$WebEvent.Auth` object:

| Name | Description |
| ---- | ----------- |
| IsAuthorised | This value will be `$true` or `$false` depending on whether or not the authenticated user is authorised to access the Route |
| Access | This property will contain the access values for the User per Access method |

## Create an Access Method

To validate authorisation in Pode you'll first need to create an Access method using [`Add-PodeAuthAccess`](../../../Functions/Authentication/Add-PodeAuthAccess). At its most simple you'll just need a Name, Type and possibly a Match type.

For example, you can create a simple Access method for any of the inbuilt types as follows:

```powershell
Add-PodeAuthAccess -Name 'RoleExample' -Type Role
Add-PodeAuthAccess -Name 'GroupExample' -Type Group
Add-PodeAuthAccess -Name 'ScopeExample' -Type Scope
Add-PodeAuthAccess -Name 'UserExample' -Type User
```

!!! note
    These Types mainly apply when using the Access method with Authentication/Routes. If you're going to be using the Access method in a more adhoc manner via [`Test-PodeAuthAccess`](../../../Functions/Authentication/Test-PodeAuthAccess) then the Type doesn't apply.

### Match Type

Pode supports 3 inbuilt "Match" types for validating access to resources: One, All and None. The default Match type is One; each of them are applied as follows:

| Type | Description |
| ---- | ----------- |
| One | If the Source's (ie: User's) access values contain at least one of the Destination's (ie: Route's) access values, then authorisation is granted. |
| All | The Source's access values must contain all of the Destination's access values for authorisation to be granted. |
| None | The Source's access values must contain none of the Destination's access values for authorisation to be granted. |

For example, to setup an Access method where a User must be in every Group that a Route specifies:

```powershell
Add-PodeAuthAccess -Name 'GroupExample' -Type Group -Match All
```

### User Access Lookup

When using Access methods with Authentication, Pode will lookup the User's "access values" from the `$WebEvent.Auth.User` object. The property within this object that Pode uses depends on the `-Type` supplied to [`Add-PodeAuthAccess`](../../../Functions/Authentication/Add-PodeAuthAccess):

| Type | Property |
| ---- | -------- |
| Role | Roles |
| Group | Groups |
| Scope | Scopes |
| User | Username |
| Custom | Custom.[Name] |

You can override this default lookup in one of two ways, by either supplying a custom property `-Path` or a `-ScriptBlock` for more a more advanced lookup (ie: external sources).

!!! note
    If you're using Access methods in a more adhoc manner via [`Test-PodeAuthAccess`](../../../Functions/Authentication/Test-PodeAuthAccess), the `-Path` property does nothing. However, if you don't supply a `-Source` to this function then the `-ScriptBlock` will be invoked.

#### Lookup Path

The `-Path` property on [`Add-PodeAuthAccess`](../../../Functions/Authentication/Add-PodeAuthAccess) allows you to specify a custom property path within the `$WebEvent.Auth.User` object, which will be used to retrieve the access values for the User.

For example, if you have Roles for the User set in a `Roles` property within a `Metadata` property, then you'd use:

```powershell
Add-PodeAuthAccess -Name 'RoleExample' -Type Role -Path 'Metadata.Roles'

<#
$User = @{
    Username = 'joe.bloggs'
    Metadata = @{
        Roles = @('Developer')
    }
}
#>
```

And Pode will retrieve the appropriate data for you.

#### Lookup ScriptBlock

If the access values you require are not stored in the `$WebEvent.Auth.User` object but else where (ie: external source), then you can supply a `-ScriptBlock` on [`Add-PodeAuthAccess`](../../../Functions/Authentication/Add-PodeAuthAccess). When Pode attempts to retrieve access values for the User, or another Source, this scriptblock will be invoked.

!!! note
    When using this scriptblock with Authentication the currently authenticated User will be supplied as the first parameter, followed by the `-ArgumentList` values. When using the Access methods in a more adhoc manner via [`Test-PodeAuthAccess`](../../../Functions/Authentication/Test-PodeAuthAccess), just the `-ArgumentList` values are supplied.

For example, if the Role values you need to retrieve are stored in some SQL database:

```powershell
Add-PodeAuthAccess -Name 'RoleExample' -Type Role -ScriptBlock {
    param($user)
    return Invoke-Sqlcmd -Query "SELECT Roles FROM UserRoles WHERE Username = '$($user.Username)'" -ServerInstance '(local)'
}
```

Or if you need to get the Groups from AD:

```powershell
Add-PodeAuthAccess -Name 'GroupExample' -Type Group -ScriptBlock {
    param($user)
    return Get-ADPrincipalGroupMembership $user.Username | select name
}
```

### Custom Validator

By default Pode will perform basic array contains checks, to see if the Source/Destination access values meet the `-Match` type required.

For example, if the User has just the Role value `Developer`, and Route has `-Role` values of `Developer` and `QA` supplied, and the `-Match` type is left as `One`, then "if the User Role is contained within the Routes Roles" access is authorised.

However, if you require a more custom/advanced validation logic to be applied, you can supply a custom `-Validator` scriptblock to [`Add-PodeAuthAccess`](../../../Functions/Authentication/Add-PodeAuthAccess). The scriptblock will be supplied with the "Source" access values as the first parameter; the "Destination" access values as the second parameter; then followed by the `-ArgumentList` values. This scriptblock should return a boolean value: true if authorisation granted, or false otherwise.

!!! note
    Supplying a `-Validator` scriptblock will override the `-Match` type supplied, as this scriptblock will be used for validation instead of Pode's inbuilt Match logic.

For example, if you want to validate that the User's Scopes definitely contains a Route's first Scope value and then at least any 1 of the other Scope values:

```powershell
Add-PodeAuthAccess -Name 'ScopeExample' -Type Scope -ScriptBlock {
    param($userScopes, $routeScopes)

    if ($routeScopes[0] -inotin $userScopes) {
        return $false
    }

    foreach ($scope in $routeScopes[1..($routeScopes.Length - 1)]) {
        if ($scope -iin $userScopes) {
            return $true
        }
    }

    return $false
}
```

## Using with Authentication

The Access methods will mostly commonly be used in conjunction with [Authentication](../../Authentication/Overview) and [Routes](../../Routes/Overview). When used together, Pode will automatically validate Route authorised for you as a part of the Authentication flow. If authorisation fails, an HTTP 403 status code will be returned.

After creating an Access method as outlined above, you can supply one or more Access method Names to [`Add-PodeAuth`](../../../Functions/Authentication/Add-PodeAuth) using the `-Access` property. This allows you to check authorisation based on multiple types of Access methods - ie, Roles and Groups, etc.

On [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute) and [`Add-PodeRouteGroup`](../../../Functions/Routes/Add-PodeRouteGroup) there are the following parameters: `-Role`, `-Group`, `-Scope`, and `-User`. You can supply one ore more string values to these parameters, depending on which Access method type you're using.

For example, to verify access to a Route to authorise only Developer accounts:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # create a simple role access method
    Add-PodeAuthAccess -Name 'RoleExample' -Type Role

    # setup Basic authentication
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'AuthExample' -Sessionless -Access 'RoleExample' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if (($username -eq 'morty') -and ($password -eq 'pickle')) {
            return @{
                User = @{
                    Username = 'Morty'
                    Roles = @('Developer')
                }
            }
        }

        # authentication failed
        return $null
    }

    # create a route which only developers can access
    Add-PodeRoute -Method Get -Path '/route1' -Role 'Developer' -Authentication 'AuthExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hello!' }
    }

    # create a route which only admins can access
    Add-PodeRoute -Method Get -Path '/route2' -Role 'Admin' -Authentication 'AuthExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hi!' }
    }
}
```

Calling the following will succeed:

```powershell
Invoke-RestMethod -Uri http://localhost:8080/route1 -Method Get -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
```

But calling the following will fail with a 403:

```powershell
Invoke-RestMethod -Uri http://localhost:8080/route2 -Method Get -Headers @{ Authorization = 'Basic bW9ydHk6cGlja2xl' }
```

## Custom Access

Pode has inbuilt support for Roles, Groups, Scopes, and Users authorisation on Routes. However, if you need to setup a more Custom authorisation policy on Routes you can create an Access method with `-Type` "Custom", and add custom access values to a Route using [`Add-PodeAuthCustomAccess`](../../../Functions/Authentication/Add-PodeAuthCustomAccess).

Custom access values on a User won't be automatically loaded from the User object, and a `-Path` or `-ScriptBlock` on [`Add-PodeAuthAccess`](../../../Functions/Authentication/Add-PodeAuthAccess) will be required.

For example, if you wanted to authorise access from a set of user attributes, and based on favourite colour, you could do the following:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # create a simple role access method
    Add-PodeAuthAccess -Name 'CustomExample' -Type Custom -Path 'Metadata.Attributes' -Validator {
        param($userAttrs, $routeAttrs)
        return ($userAttrs.Colour -ieq $routeAttrs.Colour)
    }

    # setup Basic authentication
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'AuthExample' -Sessionless -Access 'CustomExample' -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if (($username -eq 'morty') -and ($password -eq 'pickle')) {
            return @{
                User = @{
                    Username = 'Morty'
                    Metadata = @{
                        Attributes = @{
                            Country = 'UK'
                            Colour = 'Blue'
                        }
                    }
                }
            }
        }

        # authentication failed
        return $null
    }

    # create a route which only users who like the colour blue can access
    Add-PodeRoute -Method Get -Path '/blue' -Authentication 'AuthExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hello!' }
    } -PassThru |
        Add-PodeAuthCustomAccess -Name 'CustomExample' -Value @{ Colour = 'Blue' }

    # create a route which only users who like the colour red can access
    Add-PodeRoute -Method Get -Path '/red' -Authentication 'AuthExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hi!' }
    } -PassThru |
        Add-PodeAuthCustomAccess -Name 'CustomExample' -Value @{ Colour = 'Red' }
}
```

## Using Adhoc

It is possible to invoke the Access method validation in an adhoc manner, without (or while) using Authentication, using [`Test-PodeAuthAccess`](../../../Functions/Authentication/Test-PodeAuthAccess).

When using the Access methods outside of Authentication/Routes, the `-Type` doesn't really having any bearing.

For example, you could create a Roles Access method and verify some Users Roles within a TCP Verb:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 9000 -Protocol Tcp -CRLFMessageEnd

    # create a role access method get retrieves roles from a database
    Add-PodeAuthAccess -Name 'RoleExample' -Type Role -ScriptBlock {
        param($username)
        return Invoke-Sqlcmd -Query "SELECT Roles FROM UserRoles WHERE Username = '$($username)'" -ServerInstance '(local)'
    }

    # setup a Verb that only allows Developers
    Add-PodeVerb -Verb 'EXAMPLE :username' -ScriptBlock {
        if (!(Test-PodeAuthAccess -Name 'RoleExample' -Destination 'Developer' -ArgumentList $TcpEvent.Parameters.username)) {
            Write-PodeTcpClient -Message "Forbidden Access"
            return
        }

        Write-PodeTcpClient -Message "Hello, there!"
    }
}
```

The `-ArgumentList`, on [`Test-PodeAuthAccess`](../../../Functions/Authentication/Test-PodeAuthAccess), will supply values as the first set of parameters to the `-ScriptBlock` defined on [`Add-PodeAuthAccess`](../../../Functions/Authentication/Add-PodeAuthAccess).
