$path = $MyInvocation.MyCommand.Path
$src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }

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
        Mock Set-PodeHeader { $WebEvent.Response.Headers[$Name] = $Value }

        It 'Sets URL response for redirect' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} } }

            Redirect -Url 'https://google.com'

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'https://google.com'
        }

        It 'Sets URL response for moved' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} } }

            Redirect -Moved -Url 'https://google.com'

            $WebEvent.Response.StatusCode | Should Be 301
            $WebEvent.Response.StatusDescription | Should Be 'Moved'
            $WebEvent.Response.Headers.Location | Should Be 'https://google.com'
        }

        It 'Alters only the port' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Port 9001

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'http://localhost:9001/path'
        }

        It 'Alters only the protocol' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'https://localhost:8080/path'
        }

        It 'Alters the port and protocol' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Port 9001 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'https://localhost:9001/path'
        }

        It 'Alters the port and protocol as moved' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Port 9001 -Protocol HTTPS -Moved

            $WebEvent.Response.StatusCode | Should Be 301
            $WebEvent.Response.StatusDescription | Should Be 'Moved'
            $WebEvent.Response.Headers.Location | Should Be 'https://localhost:9001/path'
        }

        It 'URL overrides the port and protocol' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Url 'https://google.com' -Port 9001 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'https://google.com'
        }

        It 'Port is 80 so does not get appended' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Port 80 -Protocol HTTP

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'http://localhost/path'
        }

        It 'Port is 443 so does not get appended' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Port 443 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'https://localhost/path'
        }

        It 'Port is 0 so gets set to URI port' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Port 0 -Protocol HTTP

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'http://localhost:8080/path'
        }

        It 'Port is negative so gets set to URI port' {
            $WebEvent = @{
                'Request' = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path'} };
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Redirect -Port -10 -Protocol HTTP

            $WebEvent.Response.StatusCode | Should Be 302
            $WebEvent.Response.StatusDescription | Should Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should Be 'http://localhost:8080/path'
        }
    }
}

Describe 'Json' {
    Mock Text { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'application/json'

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
    Mock Text { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'text/csv'

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
    Mock Text { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'text/xml'

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
    Mock Text { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
    $_ContentType = 'text/html'

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

Describe 'Text' {
    It 'Does nothing for no value' {
        Text -Value $null | Out-Null
    }

    It 'Throws an error when value is invalid type' {
        { Text -Value 3 } | Should Throw 'must be a String or Byte[]'
    }

    It 'Does nothing when we have no response' {
        Text -Value 'value' | Out-Null
    }
}

Describe 'File' {
    It 'Does nothing when the file does not exist' {
        Mock Test-PodePath { return $false }
        File -Path './path' | Out-Null
        Assert-MockCalled Test-PodePath -Times 1 -Scope It
    }

    Mock Test-PodePath { return $true }

    It 'Loads the contents of a dynamic file' {
        Mock Get-PodeFileContentUsingViewEngine { return 'file contents' }
        Mock Text { return $Value }

        File -Path './path/file.pode' | Should Be 'file contents'

        Assert-MockCalled Get-PodeFileContentUsingViewEngine -Times 1 -Scope It
    }

    It 'Loads the contents of a static file' {
        Mock Get-Content { return 'file contents' }
        Mock Text { return $Value }

        File -Path './path/file.pode' | Should Be 'file contents'

        Assert-MockCalled Get-PodeFileContentUsingViewEngine -Times 1 -Scope It
    }
}

Describe 'Include' {
    $PodeContext = @{
        'Server' = @{
            'InbuiltDrives' = @{ 'views' = '.' }
            'ViewEngine' = @{ 'Extension' = 'pode' }
        }
    }

    It 'Throws an error for a path that does not exist' {
        Mock Test-PodePath { return $false }
        { Include -Path 'sub-view.pode' } | Should Throw 'File not found'
    }

    Mock Test-PodePath { return $true }
    Mock Get-PodeFileContentUsingViewEngine { return 'file contents' }

    It 'Returns file contents, and appends view engine' {
        Include -Path 'sub-view' | Should Be 'file contents'
    }

    It 'Returns file contents' {
        Include -Path 'sub-view.pode' | Should Be 'file contents'
    }
}

Describe 'Close-PodeTcpConnection' {
    It 'Disposes a passes client' {
        Mock Dispose { }

        try {
            $_client = New-Object System.IO.MemoryStream
            Close-PodeTcpConnection -Client $_client
        }
        finally {
            $_client.Dispose()
        }

        Assert-MockCalled Dispose -Times 1 -Scope It
    }

    It 'Disposes and Quits a passes client' {
        Mock Dispose { }
        Mock Tcp { }

        try {
            $_client = New-Object System.IO.MemoryStream
            $_client | Add-Member -MemberType NoteProperty -Name Connected -Value $true -Force
            Close-PodeTcpConnection -Client $_client -Quit
        }
        finally {
            $_client.Dispose()
        }

        Assert-MockCalled Tcp -Times 1 -Scope It
        Assert-MockCalled Dispose -Times 1 -Scope It
    }

    It 'Disposes a stored client' {
        Mock Dispose { }

        try {
            $TcpEvent = @{ 'Client' = New-Object System.IO.MemoryStream }
            Close-PodeTcpConnection
        }
        finally {
            $TcpEvent.Client.Dispose()
        }

        Assert-MockCalled Dispose -Times 1 -Scope It
    }
}

Describe 'Show-PodeErrorPage' {
    Mock File { return $Data }

    It 'Does nothing when it cannot find a page' {
        Mock Find-PodeErrorPage { return $null }
        Show-PodeErrorPage -Code 404 | Out-Null
        Assert-MockCalled File -Times 0 -Scope It
    }

    Mock Find-PodeErrorPage { return @{ 'Path' = './path'; 'ContentType' = 'json' } }
    Mock Get-PodeUrl { return 'url' }

    It 'Renders a page with no exception' {
        $d = Show-PodeErrorPage -Code 404

        Assert-MockCalled File -Times 1 -Scope It
        $d.Url | Should Be 'url'
        $d.Exception | Should Be $null
        $d.ContentType | Should Be 'json'
        $d.Status.Code | Should Be 404
    }

    It 'Renders a page with exception' {
        $PodeContext = @{ 'Server' = @{ 'Web' = @{
            'ErrorPages' = @{ 'ShowExceptions' = $true }
        } } }

        try {
            $v = $null
            $v.Add()
        }
        catch { $e = $_ }

        $d = Show-PodeErrorPage -Code 404 -Exception $e

        Assert-MockCalled File -Times 1 -Scope It
        $d.Url | Should Be 'url'
        $d.Exception | Should Not Be $null
        $d.Exception.Message | Should Match 'cannot call a method'
        $d.Exception.Category | Should Match 'InvalidOperation'
        $d.Exception.StackTrace | Should Match 'Responses.Tests.ps1'
        $d.Exception.Line | Should Match 'Responses.Tests.ps1'
        $d.ContentType | Should Be 'json'
        $d.Status.Code | Should Be 404
    }
}