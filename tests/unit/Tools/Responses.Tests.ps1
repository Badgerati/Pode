$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit[\\/]', '/src/'
Get-ChildItem "$($src)/*.ps1" | Resolve-Path | ForEach-Object { . $_ }

Describe 'Status' {
    Context 'Valid values supplied' {
        Mock 'Show-PodeErrorPage' { }

        It 'Sets StatusCode only' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Status -Code 418

            $WebEvent.Response.StatusCode | Should Be 418
            $WebEvent.Response.StatusDescription | Should Be "I'm a Teapot"

            Assert-MockCalled 'Show-PodeErrorPage' -Scope It -Times 1
        }

        It 'Sets StatusCode and StatusDescription' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Status -Code 418 -Description 'I am a Teapot'

            $WebEvent.Response.StatusCode | Should Be 418
            $WebEvent.Response.StatusDescription | Should Be 'I am a Teapot'

            Assert-MockCalled 'Show-PodeErrorPage' -Scope It -Times 1
        }

        It 'Sets 200 StatusCode' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Status -Code 200

            $WebEvent.Response.StatusCode | Should Be 200
            $WebEvent.Response.StatusDescription | Should Be 'OK'

            Assert-MockCalled 'Show-PodeErrorPage' -Scope It -Times 0
        }
    }
}

Describe 'Redirect' {
    Context 'Valid values supplied' {
        It 'Sets URL response for redirect' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' } }
            Redirect -Url 'https://google.com'

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'https://google.com'
        }

        It 'Sets URL response for moved' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' } }
            Redirect -Moved -Url 'https://google.com'

            $WebEvent.Response.StatusCode | Should Be 301
            $WebEvent.Response.StatusDescription | Should Be 'Moved'
            $WebEvent.Response.RedirectLocation | Should Be 'https://google.com'
        }

        It 'Alters only the port' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 9001

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'http://localhost:9001/path'
        }

        It 'Alters only the protocol' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'https://localhost:8080/path'
        }

        It 'Alters the port and protocol' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 9001 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'https://localhost:9001/path'
        }

        It 'Alters the port and protocol as moved' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 9001 -Protocol HTTPS -Moved

            $WebEvent.Response.StatusCode | Should Be 301
            $WebEvent.Response.StatusDescription | Should Be 'Moved'
            $WebEvent.Response.RedirectLocation | Should Be 'https://localhost:9001/path'
        }

        It 'URL overrides the port and protocol' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Url 'https://google.com' -Port 9001 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'https://google.com'
        }

        It 'Port is 80 so does not get appended' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 80 -Protocol HTTP

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'http://localhost/path'
        }

        It 'Port is 443 so does not get appended' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 443 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'https://localhost/path'
        }

        It 'Port is 0 so gets set to URI port' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port 0 -Protocol HTTP

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'http://localhost:8080/path'
        }

        It 'Port is negative so gets set to URI port' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'RedirectLocation' = '' }
            }

            Redirect -Port -10 -Protocol HTTP

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.RedirectLocation | Should Be 'http://localhost:8080/path'
        }
    }
}