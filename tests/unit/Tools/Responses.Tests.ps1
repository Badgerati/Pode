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

Describe 'Json' {
    Mock Write-ToResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'application/json; charset=utf-8'

    It 'Returns an empty value for an empty value' {
        $r = Json -Value ([string]::Empty)
        $r.Value | Should Be '{}'
        $r.ContentType | Should Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Json -Value '{ "name": "bob" }'
        $r.Value | Should Be '{ "name": "bob" }'
        $r.ContentType | Should Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Json -Value @{ 'name' = 'john' }
        $r.Value | Should Be '{"name":"john"}'
        $r.ContentType | Should Be $_ContentType
    }

    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Json -Value 'fake-file' -File | Out-Null
        Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return '{ "name": "bob" }' }

        $r = Json -Value 'file/path' -File
        $r.Value | Should Be '{ "name": "bob" }'
        $r.ContentType | Should Be $_ContentType
    }
}

Describe 'Csv' {
    Mock Write-ToResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'text/csv; charset=utf-8'

    It 'Returns an empty value for an empty value' {
        $r = Csv -Value ([string]::Empty)
        $r.Value | Should Be ([string]::Empty)
        $r.ContentType | Should Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Csv -Value 'bob, 42'
        $r.Value | Should Be 'bob, 42'
        $r.ContentType | Should Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Csv -Value @{ 'name' = 'john' }
        $r.Value | Should Be @('"name"', '"john"')
        $r.ContentType | Should Be $_ContentType
    }

    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Csv -Value 'fake-file' -File | Out-Null
        Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return 'bob, 42' }

        $r = Csv -Value 'file/path' -File
        $r.Value | Should Be 'bob, 42'
        $r.ContentType | Should Be $_ContentType
    }
}

Describe 'Xml' {
    Mock Write-ToResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'application/xml; charset=utf-8'

    It 'Returns an empty value for an empty value' {
        $r = Xml -Value ([string]::Empty)
        $r.Value | Should Be ([string]::Empty)
        $r.ContentType | Should Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Xml -Value '<root></root>'
        $r.Value | Should Be '<root></root>'
        $r.ContentType | Should Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Xml -Value @{ 'name' = 'john' }
        ($r.Value -ireplace '[\r\n ]', '') | Should Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="name">john</Property></Object></Objects>'
        $r.ContentType | Should Be $_ContentType
    }

    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Xml -Value 'fake-file' -File | Out-Null
        Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return '<root></root>' }

        $r = Xml -Value 'file/path' -File
        $r.Value | Should Be '<root></root>'
        $r.ContentType | Should Be $_ContentType
    }
}

Describe 'Html' {
    Mock Write-ToResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'text/html; charset=utf-8'

    It 'Returns an empty value for an empty value' {
        $r = Html -Value ([string]::Empty)
        $r.Value | Should Be ([string]::Empty)
        $r.ContentType | Should Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Html -Value '<html></html>'
        $r.Value | Should Be '<html></html>'
        $r.ContentType | Should Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Html -Value @{ 'name' = 'john' }
        $r.Value | Should Be (@{ 'name' = 'john' } | ConvertTo-Html)
        $r.ContentType | Should Be $_ContentType
    }

    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Html -Value 'fake-file' -File | Out-Null
        Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return '<html></html>' }

        $r = Html -Value 'file/path' -File
        $r.Value | Should Be '<html></html>'
        $r.ContentType | Should Be $_ContentType
    }
}