# Route Grouping

Instead of adding multiple Routes all with the same path, middleware, authentication and other values; you can instead create these Routes in a Route Group. This will let you specify a shared base path, middleware, authentication, etc. for multiple Routes.

There are Route groupings for normal Routes, Static Routes, and Signal Routes.

## Routes

You can add a new Route Group using [`Add-PodeRouteGroup`](../../../../Functions/Routes/Add-PodeRouteGroup), and passing a any shared details, plus a `-Routes` scriptblock for the routes to be created within the grouping's scope.

For example, the below will add 3 Routes which all share a `/api` base path; some Basic authentication, and some other middleware:

```powershell
$mid = New-PodeMiddleware -ScriptBlock {
    'some middleware being run' | Out-Default
}

Add-PodeRouteGroup -Path '/api' -Authentication Basic -Middleware $mid -Routes {
    Add-PodeRoute -Method Get -Path '/route1' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ ID = 1 }
    }

    Add-PodeRoute -Method Get -Path '/route2' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ ID = 2 }
    }

    Add-PodeRoute -Method Get -Path '/route3' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ ID = 3 }
    }
}
```

When run, you'll have 3 Routes that all need some Basic authentication at `/api/route1`, `/api/route2`, and `/api/route3`.

You can still add custom `-Middleware` on the Routes, and they'll be appended to the shared Middleware from the Group. Other parameters, such as `-ContentType` and `-EndpointName`, if supplied, will override the values passed into the Group.

You can also embed groups within groups. The following is the same as the above, except this time the last 2 Routes will be at `/api/inner/route2`, and `/api/inner/route3`:

```powershell
$mid = New-PodeMiddleware -ScriptBlock {
    'some middleware being run' | Out-Default
}

Add-PodeRouteGroup -Path '/api' -Authentication Basic -Middleware $mid -Routes {
    Add-PodeRoute -Method Get -Path '/route1' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ ID = 1 }
    }

    Add-PodeRouteGroup -Path '/inner' -Routes {
        Add-PodeRoute -Method Get -Path '/route2' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ ID = 2 }
        }

        Add-PodeRoute -Method Get -Path '/route3' -ScriptBlock {
            Write-PodeJsonResponse -Value @{ ID = 3 }
        }
    }

    Add-PodeRouteGroup -Path '/special' -FilePath './routes/specialRoutes.ps1'
}
```



## Static Routes

The Groups for Static Routes work in the same manner as normal Routes, but you'll need to use [`Add-PodeStaticRouteGroup`](../../../../Functions/Routes/Add-PodeStaticRouteGroup) instead:

```powershell
Add-PodeStaticRouteGroup -Path '/assets' -Source './content/assets' -Routes {
    Add-PodeStaticRoute -Path '/images' -Source '/images'
    Add-PodeStaticRoute -Path '/videos' -Source '/videos'
}
```

This will create 2 Static Routes at `/assets/images` and `/assets/videos`, referencing files from the directories `./content/assets/images` and `./content/assets/videos` respectively.

## Signal Routes

Groupings for Signal Routes also work in the same manner as normal Routes, but you'll need to use [`Add-PodeSignalRouteGroup`](../../../../Functions/Routes/Add-PodeSignalRouteGroup) instead:

```powershell
Add-PodeSignalRoute -Path '/ws' -Routes {
    Add-PodeSignalRoute -Path '/messages1' -ScriptBlock {
        Send-PodeSignal -Value $SignalEvent.Data.Message
    }

    Add-PodeSignalRoute -Path '/messages2' -ScriptBlock {
        Send-PodeSignal -Value $SignalEvent.Data.Message
    }
}
```

This will create 2 Signal Routes at `/ws/messages1` and `/ws/messages2`.
