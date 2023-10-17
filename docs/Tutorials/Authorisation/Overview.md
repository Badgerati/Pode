# Overview

Authorisation can either be used in conjunction with [Authentication](../../Authentication/Overview) and [Routes](../../Routes/Overview), or on it's own for custom scenarios.

When used with Authentication, Pode can automatically authorise access to Routes based on Roles; Groups; Scopes; Users; or custom validation logic for you, using the currently authenticated User's details. When authorisation fails Pode will respond with an HTTP 403 status code.

With authentication, Pode will set the following properties on the `$WebEvent.Auth` object:

| Name | Description |
| ---- | ----------- |
| IsAuthorised | This value will be `$true` or `$false` depending on whether or not the authenticated user is authorised to access the Route |

## Create an Access Method

To validate authorisation in Pode you'll first need to create an Access scheme using [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme), and then an Access method using [`Add-PodeAccess`](../../../Functions/Authentication/Add-PodeAccess). At its most simple you'll just need a Name, Type and possibly a Match type.

For example, you can create a simple Access method for any of the inbuilt types as follows:

```powershell
New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'RoleExample'
New-PodeAccessScheme -Type Group | Add-PodeAccess -Name 'GroupExample'
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'ScopeExample'
New-PodeAccessScheme -Type User | Add-PodeAccess -Name 'UserExample'
```

### Match Type

Pode supports 3 inbuilt "Match" types for validating access to resources: One, All and None. The default Match type is One; each of them are applied as follows:

| Type | Description |
| ---- | ----------- |
| One | If the Source's (ie: User's) access values contain at least one of the Destination's (ie: Route's) access values, then authorisation is granted. |
| All | The Source's access values must contain all of the Destination's access values for authorisation to be granted. |
| None | The Source's access values must contain none of the Destination's access values for authorisation to be granted. |

For example, to setup an Access method where a User must be in every Group that a Route specifies:

```powershell
New-PodeAccessScheme -Type Group | Add-PodeAccess -Name 'GroupExample' -Match All
```

### User Access Lookup

When using Access methods with Authentication and Routes, Pode will lookup the User's "access values" from the `$WebEvent.Auth.User` object. The property within this object that Pode uses depends on the `-Type` supplied to [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme):

| Type | Property |
| ---- | -------- |
| Role | Roles |
| Group | Groups |
| Scope | Scopes |
| User | Username |
| Custom | n/a - you must supply a `-Path` or `-ScriptBlock` to [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme) |

You can override this default lookup in one of two ways, by either supplying a custom property `-Path` or a `-ScriptBlock` for more a more advanced lookup (ie: external sources).

!!! note
    If you're using Access methods in a more adhoc manner via [`Test-PodeAccess`](../../../Functions/Authentication/Test-PodeAccess), the `-Path` property does nothing. However, if you don't supply a `-Source` to this function then the `-ScriptBlock` will be invoked.

#### Lookup Path

The `-Path` property on [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme) allows you to specify a custom property path within the `$WebEvent.Auth.User` object, which will be used to retrieve the access values for the User.

For example, if you have Roles for the User set in a `Roles` property within a `Metadata` property, then you'd use:

```powershell
New-PodeAccessScheme -Type Role -Path 'Metadata.Roles' | Add-PodeAccess -Name 'RoleExample'

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

If the source access values you require are not stored in the `$WebEvent.Auth.User` object but else where (ie: external source), then you can supply a `-ScriptBlock` on [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme). When Pode attempts to retrieve access values for the User, or another Source, this scriptblock will be invoked.

!!! note
    When using this scriptblock with Authentication the currently authenticated User will be supplied as the first parameter, followed by the `-ArgumentList` values. When using the Access methods in a more adhoc manner via [`Test-PodeAccess`](../../../Functions/Authentication/Test-PodeAccess), just the `-ArgumentList` values are supplied.

For example, if the Role values you need to retrieve are stored in some SQL database:

```powershell
$scheme = New-PodeAccessScheme -Type Role -ScriptBlock {
    param($user)
    return Invoke-Sqlcmd -Query "SELECT Roles FROM UserRoles WHERE Username = '$($user.Username)'" -ServerInstance '(local)'
}

$scheme | Add-PodeAccess -Name 'RoleExample'
```

Or if you need to get the Groups from AD:

```powershell
$scheme = New-PodeAccessScheme -Type Group -ScriptBlock {
    param($user)
    return Get-ADPrincipalGroupMembership $user.Username | select name
}

$scheme | Add-PodeAccess -Name 'GroupExample'
```

### Custom Validator

By default Pode will perform basic array contains checks, to see if the Source/Destination access values meet the `-Match` type required which was set on [`Add-PodeAccess`](../../../Functions/Access/Add-PodeAccess).

For example, if the User has just the Role value `Developer`, and Route has `-Role` values of `Developer` and `QA` supplied, and the `-Match` type is left as `One`, then "if the User Role is contained within the Routes Roles" access is authorised.

However, if you require a more custom/advanced validation logic to be applied, you can supply a `-ScriptBlock` to [`Add-PodeAccess`](../../../Functions/Authentication/Add-PodeAccess). The scriptblock will be supplied with the "Source" access values as the first parameter; the "Destination" access values as the second parameter; and then followed by the `-ArgumentList` values. This scriptblock should return a boolean value: true if authorisation granted, or false otherwise.

!!! note
    Supplying a `-ScriptBlock` will override the `-Match` type supplied, as this scriptblock will be used for validation instead of Pode's inbuilt Match logic.

For example, if you want to validate that the User's Scopes definitely contains a Route's first Scope value and then at least any 1 of the other Scope values:

```powershell
New-PodeAccessScheme -Type Scope | Add-PodeAccess -Name 'ScopeExample' -ScriptBlock {
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

## Using with Routes

The Access methods will most commonly be used in conjunction with [Authentication](../../Authentication/Overview) and [Routes](../../Routes/Overview). When used together, Pode will automatically validate Route Authorisation for after the Authentication flow. If authorisation fails, an HTTP 403 status code will be returned.

After creating an Access method as outlined above, you can supply the Access method Name to [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute), and other Route functions, using the `-Access` parameter.

On [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute) and [`Add-PodeRouteGroup`](../../../Functions/Routes/Add-PodeRouteGroup) there are also the following parameters: `-Role`, `-Group`, `-Scope`, and `-User`. You can supply one ore more string values to these parameters, depending on which Access method type you're using.

For example, to verify access to a Route to authorise only Developer role users:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # create a simple role access method
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'RoleExample'

    # setup Basic authentication
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'AuthExample' -Sessionless -ScriptBlock {
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
    Add-PodeRoute -Method Get -Path '/route1' -Role 'Developer' -Authentication 'AuthExample' -Access 'RoleExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hello!' }
    }

    # create a route which only admins can access
    Add-PodeRoute -Method Get -Path '/route2' -Role 'Admin' -Authentication 'AuthExample' -Access 'RoleExample' -ScriptBlock {
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

## Merging

Similar to Authentication methods, you can also merge Access methods using [`Merge-PodeAccess`](../../../Functions/Authentication/Merge-PodeAccess). This allows you to have an access strategy where multiple authorisations are required to pass for a user to be fully authorised, or just one of several possible methods.

When you merge access methods together, it becomes a new access method which you can supply to `-Access` on [`Add-PodeRoute`](../../../Functions/Routes/Add-PodeRoute). By default the merged access method expects just one to pass, but you can state that you require all to pass via the `-Valid` parameter on [`Merge-PodeAccess`](../../../Functions/Authentication/Merge-PodeAccess).

Using the same example above, we could add Group authorisation to this as well so the Developers have to be in a Software Group, and the Admins in a Operations Group:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # create simple role and group access methods
    New-PodeAccessScheme -Type Role | Add-PodeAccess -Name 'RoleExample'
    New-PodeAccessScheme -Type Group | Add-PodeAccess -Name 'GroupExample'

    # setup a merged access
    Merge-PodeAccess -Name 'MergedExample' -Access 'RoleExample', 'GroupExample' -Valid All

    # setup Basic authentication
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'AuthExample' -Sessionless -ScriptBlock {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if (($username -eq 'morty') -and ($password -eq 'pickle')) {
            return @{
                User = @{
                    Username = 'Morty'
                    Roles = @('Developer')
                    Groups = @('Software')
                }
            }
        }

        # authentication failed
        return $null
    }

    # create a route which only developers can access
    Add-PodeRoute -Method Get -Path '/route1' -Role 'Developer' -Group 'Software' -Authentication 'AuthExample' -Access 'MergedExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hello!' }
    }

    # create a route which only admins can access
    Add-PodeRoute -Method Get -Path '/route2' -Role 'Admin' -Group 'Operations' -Authentication 'AuthExample' -Access 'MergedExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hi!' }
    }
}
```

## Custom Access

Pode has inbuilt support for Roles, Groups, Scopes, and Users authorisation on Routes. However, if you need to setup a more Custom authorisation policy on Routes you can create a custom Access scheme by supplying `-Custom` to [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme), and add custom access values to a Route using [`Add-PodeAccessCustom`](../../../Functions/Authentication/Add-PodeAccessCustom).

Custom access values for a User won't be automatically loaded from the authenticated User object, and a `-Path` or `-ScriptBlock` on [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme) will be required.

For example, if you wanted to authorise access from a set of user attributes, and based on favourite colour, you could do the following:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # create a simple role access method
    New-PodeAccessScheme -Custom -Path 'Metadata.Attributes' | Add-PodeAccess -Name 'CustomExample' -ScriptBlock {
        param($userAttrs, $routeAttrs)
        return ($userAttrs.Colour -ieq $routeAttrs.Colour)
    }

    # setup Basic authentication
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'AuthExample' -Sessionless -ScriptBlock {
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
    Add-PodeRoute -Method Get -Path '/blue' -Authentication 'AuthExample' -Access 'CustomExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hello!' }
    } -PassThru |
        Add-PodeAccessCustom -Name 'CustomExample' -Value @{ Colour = 'Blue' }

    # create a route which only users who like the colour red can access
    Add-PodeRoute -Method Get -Path '/red' -Authentication 'AuthExample' -Access 'CustomExample' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ 'Value' = 'Hi!' }
    } -PassThru |
        Add-PodeAccessCustom -Name 'CustomExample' -Value @{ Colour = 'Red' }
}
```

## Using Adhoc

It is possible to invoke the Access method validation in an adhoc manner, without (or while) using Authentication, using [`Test-PodeAccess`](../../../Functions/Authentication/Test-PodeAccess).

When using the Access methods outside of Authentication/Routes, the `-Type` doesn't really have any bearing.

For example, you could create a Roles Access method and verify some Users Roles within a TCP Verb:

```powershell
Start-PodeServer {
    Add-PodeEndpoint -Address * -Port 9000 -Protocol Tcp -CRLFMessageEnd

    # create a role access method get retrieves roles from a database
    $scheme = New-PodeAccessScheme -Type Role -ScriptBlock {
        param($username)
        return Invoke-Sqlcmd -Query "SELECT Roles FROM UserRoles WHERE Username = '$($username)'" -ServerInstance '(local)'
    }
    $scheme | Add-PodeAccess -Name 'RoleExample'

    # setup a Verb that only allows Developers
    Add-PodeVerb -Verb 'EXAMPLE :username' -ScriptBlock {
        if (!(Test-PodeAccess -Name 'RoleExample' -Destination 'Developer' -ArgumentList $TcpEvent.Parameters.username)) {
            Write-PodeTcpClient -Message "Forbidden Access"
            return
        }

        Write-PodeTcpClient -Message "Hello, there!"
    }
}
```

The `-ArgumentList`, on [`Test-PodeAccess`](../../../Functions/Authentication/Test-PodeAccess), will supply values as the first set of parameters to the `-ScriptBlock` defined on [`New-PodeAccessScheme`](../../../Functions/Access/New-PodeAccessScheme).
