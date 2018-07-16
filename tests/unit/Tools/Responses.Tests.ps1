$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '\\tests\\unit\\', '\src\'
Get-ChildItem "$($src)\*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Status' {
    Context 'Valid values supplied' {
        It 'Sets StatusCode only' {
            $WebSession = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Status -Code 418

            $WebSession.Response.StatusCode | Should Be 418
            $WebSession.Response.StatusDescription | Should Be ''
        }

        It 'Sets StatusCode and StatusDescription' {
            $WebSession = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Status -Code 418 -Description 'I am a Teapot'

            $WebSession.Response.StatusCode | Should Be 418
            $WebSession.Response.StatusDescription | Should Be 'I am a Teapot'
        }
    }
}

Describe 'Response' {
    Context 'Invalid parameters supplied' {
        It 'Throw null url parameter error' {
            { Redirect -Url $null } | Should Throw 'The argument is null or empty'
        }

        It 'Throw empty url parameter error' {
            { Redirect -Url ([string]::Empty) } | Should Throw 'The argument is null or empty'
        }
    }

    Context 'Valid values supplied' {
        It 'Sets response for redirect' {
            $WebSession = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' } }
            Redirect -Url 'https://google.com'

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'https://google.com'
        }

        It 'Sets response for moved' {
            $WebSession = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' } }
            Redirect -Moved -Url 'https://google.com'

            $WebSession.Response.StatusCode | Should Be 301
            $WebSession.Response.StatusDescription | Should Be 'Moved'
            $WebSession.Response.RedirectLocation | Should Be 'https://google.com'
        }
    }
}