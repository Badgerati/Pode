
try {
    # Determine the script path and Pode module path
    $ScriptPath = (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
    $podePath = Split-Path -Parent -Path $ScriptPath

    # Import the Pode module from the source path if it exists, otherwise from installed modules
    if (Test-Path -Path "$($podePath)/src/Pode.psm1" -PathType Leaf) {
        Import-Module "$($podePath)/src/Pode.psm1" -Force -ErrorAction Stop
    }
    else {
        Import-Module -Name 'Pode' -MaximumVersion 2.99 -ErrorAction Stop
    }
}
catch { throw }


Start-PodeServer   -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port 8080 -Protocol Http

    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging
    Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
        Close-PodeServer
    }

    # BASIC
    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'BasicAuth' -Sessionless -ScriptBlock {
        param($username, $password)

        if (($username -eq 'morty') -and ($password -eq 'pickle')) {
            return @{ User = @{ ID = 'M0R7Y302' } }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    Add-PodeRoute -Method Post -Path '/auth/basic' -Authentication 'BasicAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 'OK' }
    }

    # BEARER
    New-PodeAuthScheme -Bearer -Scope write | Add-PodeAuth -Name 'BearerAuth' -Sessionless -ScriptBlock {
        param($token)

        if ($token -ieq 'test-token') {
            return @{
                User  = @{ ID = 'M0R7Y302' }
                Scope = 'write'
            }
        }

        return $null
    }

    Add-PodeRoute -Method Get -Path '/auth/bearer' -Authentication 'BearerAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 'OK' }
    }

    # API KEY
    New-PodeAuthScheme -ApiKey | Add-PodeAuth -Name 'ApiKeyAuth' -Sessionless -ScriptBlock {
        param($key)

        if ($key -ieq 'test-key') {
            return @{
                User = @{ ID = 'M0R7Y302' }
            }
        }

        return $null
    }

    Add-PodeRoute -Method Get -Path '/auth/apikey' -Authentication 'ApiKeyAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 'OK' }
    }

    # API KEY - JWT (not signed)
    New-PodeAuthScheme -ApiKey -AsJWT | Add-PodeAuth -Name 'ApiKeyNotSignedJwtAuth' -Sessionless -ScriptBlock {
        param($jwt)
write-podehost $jwt -Explode

        if ($jwt.username -ieq 'morty') {
            return @{
                User = @{ ID = 'M0R7Y302' }
            }
        }

        return $null
    }

    Add-PodeRoute -Method Get -Path '/auth/apikey/jwt/notsigned' -Authentication 'ApiKeyNotSignedJwtAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 'OK' }
    }

    # API KEY - JWT (signed)
    New-PodeAuthScheme -ApiKey -AsJWT -Secret 'secret' | Add-PodeAuth -Name 'ApiKeySignedJwtAuth' -Sessionless -ScriptBlock {
        param($jwt)

        if ($jwt.username -ieq 'morty') {
            return @{
                User = @{ ID = 'M0R7Y302' }
            }
        }

        return $null
    }

    Add-PodeRoute -Method Get -Path '/auth/apikey/jwt/signed' -Authentication 'ApiKeySignedJwtAuth' -ScriptBlock {
        Write-PodeJsonResponse -Value @{ Result = 'OK' }
    }

    # FORM (Monocle?)
}