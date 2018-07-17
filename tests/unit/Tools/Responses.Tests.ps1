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

Describe 'Redirect' {
    Context 'Valid values supplied' {
        It 'Sets URL response for redirect' {
            $WebSession = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' } }
            Redirect -Url 'https://google.com'

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'https://google.com'
        }

        It 'Sets URL response for moved' {
            $WebSession = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' } }
            Redirect -Moved -Url 'https://google.com'

            $WebSession.Response.StatusCode | Should Be 301
            $WebSession.Response.StatusDescription | Should Be 'Moved'
            $WebSession.Response.RedirectLocation | Should Be 'https://google.com'
        }

        It 'Alters only the port' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 9001

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'http://localhost:9001/path'
        }

        It 'Alters only the protocol' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Protocol HTTPS

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'https://localhost:8080/path'
        }

        It 'Alters the port and protocol' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 9001 -Protocol HTTPS

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'https://localhost:9001/path'
        }

        It 'Alters the port and protocol as moved' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 9001 -Protocol HTTPS -Moved

            $WebSession.Response.StatusCode | Should Be 301
            $WebSession.Response.StatusDescription | Should Be 'Moved'
            $WebSession.Response.RedirectLocation | Should Be 'https://localhost:9001/path'
        }

        It 'URL overrides the port and protocol' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Url 'https://google.com' -Port 9001 -Protocol HTTPS

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'https://google.com'
        }

        It 'Port is 80 so does not get appended' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 80 -Protocol HTTP

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'http://localhost/path'
        }

        It 'Port is 443 so does not get appended' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 443 -Protocol HTTPS

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'https://localhost/path'
        }

        It 'Port is 0 so gets set to URI port' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 0 -Protocol HTTP

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'http://localhost:8080/path'
        }

        It 'Port is negative so gets set to URI port' {
            $WebSession = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port -10 -Protocol HTTP

            $WebSession.Response.StatusCode | Should Be 302
            $WebSession.Response.StatusDescription | Should Be 'Redirect'
            $WebSession.Response.RedirectLocation | Should Be 'http://localhost:8080/path'
        }
    }
}