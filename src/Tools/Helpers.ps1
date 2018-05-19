
# read in the content from a dynamic pode file and invoke its content
function ConvertFrom-PodeFile
{
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        $Content,

        [Parameter()]
        $Data = @{}
    )

    # if we have data, then setup the data param
    if (!(Test-Empty $Data)) {
        $Content = "param(`$data)`nreturn `"$($Content -replace '"', '``"')`""
    }
    else {
        $Content = "return `"$($Content -replace '"', '``"')`""
    }

    # invoke the content as a script to generate the dynamic content
    $Content = (Invoke-Command -ScriptBlock ([scriptblock]::Create($Content)) -ArgumentList $Data)
    return $Content
}

function Test-Empty
{
    param (
        [Parameter()]
        $Value
    )

    if ($Value -eq $null) {
        return $true
    }

    if ($Value.GetType().Name -ieq 'string') {
        return [string]::IsNullOrWhiteSpace($Value)
    }

    if ($Value.GetType().Name -ieq 'hashtable') {
        return $Value.Count -eq 0
    }

    $type = $Value.GetType().BaseType.Name.ToLowerInvariant()
    switch ($type) {
        'valuetype' {
            return $false
        }

        'array' {
            return (($Value | Measure-Object).Count -eq 0 -or $Value.Count -eq 0)
        }
    }

    return ([string]::IsNullOrWhiteSpace($Value) -or ($Value | Measure-Object).Count -eq 0 -or $Value.Count -eq 0)
}

function Get-DynamicContentType
{
    param (
        [Parameter()]
        [string]
        $Path
    )

    # default content type
    $ctype = 'text/plain'

    # if no path, return default
    if (Test-Empty $Path) {
        return $ctype
    }

    # get secondary extension (like style.css.pode would be css)
    $ext = [System.IO.Path]::GetExtension([System.IO.Path]::GetFileNameWithoutExtension($Path)).Trim('.')

    # get content type from secondary extension
    switch ($ext.ToLowerInvariant()) {
        'css' { $ctype = 'text/css' }
        'js' { $ctype = 'text/javascript' }
    }

    return $ctype
}

function Test-CtrlCPressed
{
    if ([Console]::IsInputRedirected -or ![Console]::KeyAvailable) {
        return
    }

    $key = [Console]::ReadKey($true)

    if ($key.Key -ieq 'c' -and $key.Modifiers -band [ConsoleModifiers]::Control) {
        Write-Host 'Terminating...' -NoNewline

        $PodeSession.Runspaces | ForEach-Object {
            $_.Runspace.Dispose()
        }

        $PodeSession.RunspacePool.Close()
        $PodeSession.RunspacePool.Dispose()

        Write-Host " Done" -ForegroundColor Green
        exit 0
    }
}