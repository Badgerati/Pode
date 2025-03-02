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

Start-PodeServer     -ScriptBlock {
    Add-PodeEndpoint -Address localhost -Port $Port -Protocol Http
    Add-PodeRoute -Method Get -Path '/close' -ScriptBlock {
        Close-PodeServer
    }

    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 5 -Extend -UseHeaders

    New-PodeAuthScheme -Basic | Add-PodeAuth -Name 'Auth' -ScriptBlock {
        param($username, $password)

        if (($username -eq 'morty') -and ($password -eq 'pickle')) {
            return @{ User = @{ ID = 'M0R7Y302' } }
        }

        return @{ Message = 'Invalid details supplied' }
    }

    Add-PodeRoute -Method Post -Path '/auth/basic' -Authentication Auth -ScriptBlock {
        $WebEvent.Session.Data.Views++

        Write-PodeJsonResponse -Value @{
            Result   = 'OK'
            Username = $WebEvent.Auth.User.ID
            Views    = $WebEvent.Session.Data.Views
        }
    }
}