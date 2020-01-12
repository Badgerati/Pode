function Enable-PodeOpenApiRoute
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/openapi',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $SwaggerPath = '/swagger',

        [Parameter()]
        [string]
        $Filter = '/',

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter(Mandatory=$true)]
        [string]
        $Title,

        [Parameter()]
        [string]
        $Version = '0.0.1',

        [Parameter()]
        [string]
        $Description
    )

    # initialise openapi info
    $PodeContext.Server.OpenAPI.Title = $Title
    $PodeContext.Server.OpenAPI.Path = $Path

    $meta = @{
        Title = $Title
        Version = $Version
        Description = $Description
        Filter = $Filter
    }

    # add the OpenAPI route
    Add-PodeRoute -Method Get -Path $Path -ArgumentList $meta -Middleware $Middleware -ScriptBlock {
        param($e, $meta)
        $def = @{
            'openapi' = '3.0.2'
        }

        # metadata
        $def['info'] = @{
            'title' = $meta.Title
            'version' = $meta.Version
            'description' = $meta.Description
        }

        # paths
        $def['paths'] = @{}
        foreach ($method in $PodeContext.Server.Routes.Keys) {
            foreach ($path in $PodeContext.Server.Routes[$method].Keys) {
                # does it match the filter?
                if ($path -inotmatch "^$($meta.Filter)") {
                    continue
                }

                # do nothing if it has no response set

                # add path to defintion
                $def['paths'][$path] = @{
                    "$($method)" = @{
                        'responses' = @{
                            '200' = @{
                                'description' = 'OK'
                            }
                        }
                    }
                }
            }
        }

        # write
        Write-PodeJsonResponse -Value $def
    }
}

function Enable-PodeSwaggerRoute
{
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = '/swagger',

        [Parameter()]
        [string]
        $OpenApiPath,

        [Parameter()]
        [object[]]
        $Middleware,

        [Parameter()]
        [string]
        $Title
    )

    # error if there's no OpenAPI path
    $OpenApiPath = Protect-PodeValue -Value $OpenApiPath -Default $PodeContext.Server.OpenAPI.Path
    if ([string]::IsNullOrWhiteSpace($OpenApiPath)) {
        throw "No OpenAPI path supplied for Swagger to use"
    }

    # fail if no title
    $Title = Protect-PodeValue -Value $Title -Default $PodeContext.Server.OpenAPI.Title
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "No title supplied for Swagger page"
    }

    # add the swagger route
    Add-PodeRoute -Method Get -Path $Path -Middleware $Middleware -ScriptBlock {
        param($e)
        $podeRoot = Get-PodeModuleMiscPath
        Write-PodeFileResponse -Path (Join-Path $podeRoot 'default-swagger.html.pode') -Data @{
            Title = $PodeContext.Server.OpenAPI.Title
            OpenApiPath = $PodeContext.Server.OpenAPI.Path
        }
    }
}


