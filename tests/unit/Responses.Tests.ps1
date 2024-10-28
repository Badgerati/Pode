[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

BeforeAll {
    $path = $PSCommandPath
    $src = (Split-Path -Parent -Path $path) -ireplace '[\\/]tests[\\/]unit', '/src/'
    Get-ChildItem "$($src)/*.ps1" -Recurse | Resolve-Path | ForEach-Object { . $_ }
    Import-LocalizedData -BindingVariable PodeLocale -BaseDirectory (Join-Path -Path $src -ChildPath 'Locales') -FileName 'Pode'

}

Describe 'Set-PodeResponseStatus' {
    Context 'Valid values supplied' {
        BeforeEach {
            Mock 'Show-PodeErrorPage' { }
        }
        It 'Sets StatusCode only' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Set-PodeResponseStatus -Code 418

            $WebEvent.Response.StatusCode | Should -Be 418
            $WebEvent.Response.StatusDescription | Should -Be "I'm a Teapot"
            Should -Invoke Show-PodeErrorPage -Times 1 -Scope It
            #   Assert-MockCalled 'Show-PodeErrorPage' -Scope It -Times 1
        }

        It 'Sets StatusCode and StatusDescription' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Set-PodeResponseStatus -Code 418 -Description 'I am a Teapot'

            $WebEvent.Response.StatusCode | Should -Be 418
            $WebEvent.Response.StatusDescription | Should -Be 'I am a Teapot'
            Should -Invoke Show-PodeErrorPage -Times 1 -Scope It
            #Assert-MockCalled 'Show-PodeErrorPage' -Scope It -Times 1
        }

        It 'Sets 200 StatusCode' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = '' } }
            Set-PodeResponseStatus -Code 200

            $WebEvent.Response.StatusCode | Should -Be 200
            $WebEvent.Response.StatusDescription | Should -Be 'OK'
            Should -Invoke Show-PodeErrorPage -Times 0 -Scope It
            # Assert-MockCalled 'Show-PodeErrorPage' -Scope It -Times 0
        }
    }
}

Describe 'Move-PodeResponseUrl' {
    Context 'Valid values supplied' {
        BeforeEach {
            Mock Set-PodeHeader { $WebEvent.Response.Headers[$Name] = $Value } }

        It 'Sets URL response for redirect' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} } }

            Move-PodeResponseUrl -Url 'https://google.com'

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'https://google.com'
        }

        It 'Sets URL response for moved' {
            $WebEvent = @{ 'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} } }

            Move-PodeResponseUrl -Moved -Url 'https://google.com'

            $WebEvent.Response.StatusCode | Should -Be 301
            $WebEvent.Response.StatusDescription | Should -Be 'Moved'
            $WebEvent.Response.Headers.Location | Should -Be 'https://google.com'
        }

        It 'Alters only the port' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Port 9001

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'http://localhost:9001/path'
        }

        It 'Alters only the protocol' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'https://localhost:8080/path'
        }

        It 'Alters the port and protocol' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Port 9001 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'https://localhost:9001/path'
        }

        It 'Alters the port and protocol as moved' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Port 9001 -Protocol HTTPS -Moved

            $WebEvent.Response.StatusCode | Should -Be 301
            $WebEvent.Response.StatusDescription | Should -Be 'Moved'
            $WebEvent.Response.Headers.Location | Should -Be 'https://localhost:9001/path'
        }

        It 'Port is 80 so does not get appended' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Port 80 -Protocol Http

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'http://localhost/path'
        }

        It 'Port is 443 so does not get appended' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Port 443 -Protocol HTTPS

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'https://localhost/path'
        }

        It 'Port is 0 so gets set to URI port' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Port 0 -Protocol Http

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'http://localhost:8080/path'
        }

        It 'Port is negative so gets set to URI port' {
            $WebEvent = @{
                'Request'  = @{ 'Url' = @{ 'Scheme' = 'http'; 'Port' = 8080; 'Host' = 'localhost'; 'PathAndQuery' = '/path' } }
                'Response' = @{ 'StatusCode' = 0; 'StatusDescription' = ''; 'Headers' = @{} }
            }

            Move-PodeResponseUrl -Port -10 -Protocol Http

            $WebEvent.Response.StatusCode | Should -Be 302
            $WebEvent.Response.StatusDescription | Should -Be 'Redirect'
            $WebEvent.Response.Headers.Location | Should -Be 'http://localhost:8080/path'
        }
    }
}

Describe 'Write-PodeJsonResponse' {
    BeforeEach {
        Mock Write-PodeTextResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
        $_ContentType = 'application/json' }

    It 'Returns an empty value for an empty value' {
        $r = Write-PodeJsonResponse -Value ([string]::Empty)
        $r.Value | Should -Be '{}'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Write-PodeJsonResponse -Value '{ "name": "bob" }'
        $r.Value | Should -Be '{ "name": "bob" }'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Write-PodeJsonResponse -Value @{ 'name' = 'john' }
        $r.Value | Should -Be '{"name":"john"}'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Write-PodeJsonResponse -Path 'fake-file' | Out-Null
        Should -Invoke Test-PodePath -Times 1 -Scope It
        #  Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return '{ "name": "bob" }' }

        $r = Write-PodeJsonResponse -Path 'file/path'
        $r.Value | Should -Be '{ "name": "bob" }'
        $r.ContentType | Should -Be $_ContentType
    }
}

Describe 'Write-PodeCsvResponse' {
    BeforeEach {
        Mock Write-PodeTextResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
        $_ContentType = 'text/csv' }

    It 'Returns an empty value for an empty value' {
        $r = Write-PodeCsvResponse -Value ([string]::Empty)
        $r.Value | Should -Be ([string]::Empty)
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Write-PodeCsvResponse -Value 'bob, 42'
        $r.Value | Should -Be 'bob, 42'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Write-PodeCsvResponse -Value @{ 'name' = 'john' }
        $r.Value | Should -Be "`"name`"$([environment]::NewLine)`"john`""
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of hashtable' {
        $r = Write-PodeCsvResponse -Value @(@{ Name = 'Rick' }, @{ Name = 'Don' })
        $r.Value | Should -Be "`"Name`"$([environment]::NewLine)`"Rick`"$([environment]::NewLine)`"Don`""
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of hashtable by Pipe' {
        $r = @(@{ Name = 'Rick' }, @{ Name = 'Don' }) | Write-PodeCsvResponse
        $r.Value | Should -Be "`"Name`"$([environment]::NewLine)`"Rick`"$([environment]::NewLine)`"Don`""
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of PSCustomObject' {
        $users = @([PSCustomObject]@{
                Name = 'Rick'
            }, [PSCustomObject]@{
                Name = 'Don'
            }
        )
        $r = Write-PodeCsvResponse -Value $users
        $r.Value | Should -Be "`"Name`"$([environment]::NewLine)`"Rick`"$([environment]::NewLine)`"Don`""
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of PSCustomObject by Pipe' {
        $r = @([PSCustomObject]@{
                Name = 'Rick'
            }, [PSCustomObject]@{
                Name = 'Don'
            }
        ) | Write-PodeCsvResponse
        $r.Value | Should -Be "`"Name`"$([environment]::NewLine)`"Rick`"$([environment]::NewLine)`"Don`""
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Write-PodeCsvResponse -Path 'fake-file' | Out-Null
        Should -Invoke Test-PodePath -Times 1 -Scope It
        # Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return 'bob, 42' }

        $r = Write-PodeCsvResponse -Path 'file/path'
        $r.Value | Should -Be 'bob, 42'
        $r.ContentType | Should -Be $_ContentType
    }
}

Describe 'Write-PodeXmlResponse' {
    BeforeEach {
        Mock Write-PodeTextResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
        $_ContentType = 'application/xml'
    }
    It 'Returns an empty value for an empty value' {
        $r = Write-PodeXmlResponse -Value ([string]::Empty)
        $r.Value | Should -Be ([string]::Empty)
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Write-PodeXmlResponse -Value '<root></root>'
        $r.Value | Should -Be '<root></root>'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Write-PodeXmlResponse -Value @{ 'name' = 'john' }
        ($r.Value -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="name">john</Property></Object></Objects>'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of hashtable by pipe' {
        $r = @(@{ Name = 'Rick' }, @{ Name = 'Don' }) | Write-PodeXmlResponse
        ($r.Value -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of hashtable' {
        $r = Write-PodeXmlResponse -Value @(@{ Name = 'Rick' }, @{ Name = 'Don' })
        ($r.Value -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of PSCustomObject' {
        $users = @([PSCustomObject]@{
                Name = 'Rick'
            }, [PSCustomObject]@{
                Name = 'Don'
            }
        )
        $r = Write-PodeXmlResponse -Value $users
        ($r.Value -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a array of PSCustomObject passed by pipe' {
        $r = @([PSCustomObject]@{
                Name = 'Rick'
            }, [PSCustomObject]@{
                Name = 'Don'
            }
        ) | Write-PodeXmlResponse
        ($r.Value -ireplace '[\r\n ]', '') | Should -Be '<?xmlversion="1.0"encoding="utf-8"?><Objects><Object><PropertyName="Name">Rick</Property></Object><Object><PropertyName="Name">Don</Property></Object></Objects>'
        $r.ContentType | Should -Be $_ContentType
    }


    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Write-PodeXmlResponse -Path 'fake-file' | Out-Null
        Should -Invoke Test-PodePath -Times 1 -Scope It
        #  Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return '<root></root>' }

        $r = Write-PodeXmlResponse -Path 'file/path'
        $r.Value | Should -Be '<root></root>'
        $r.ContentType | Should -Be $_ContentType
    }
}

Describe 'Write-PodeHtmlResponse' {
    BeforeEach {
        Mock Write-PodeTextResponse { return @{ 'Value' = $Value; 'ContentType' = $ContentType; } }
        $_ContentType = 'text/html' }

    It 'Returns an empty value for an empty value' {
        $r = Write-PodeHtmlResponse -Value ([string]::Empty)
        $r.Value | Should -Be ([string]::Empty)
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Returns a raw value' {
        $r = Write-PodeHtmlResponse -Value '<html></html>'
        $r.Value | Should -Be '<html></html>'
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Converts and returns a value from a hashtable' {
        $r = Write-PodeHtmlResponse -Value @{ 'name' = 'john' }
        $r.Value | Should -Be ((@{ 'name' = 'john' } | ConvertTo-Html) -join ([environment]::NewLine))
        $r.ContentType | Should -Be $_ContentType
    }

    It 'Does nothing for an invalid file path' {
        Mock Test-PodePath { return $false }
        Write-PodeHtmlResponse -Path 'fake-file' | Out-Null
        Should -Invoke Test-PodePath -Times 1 -Scope It
        #  Assert-MockCalled -CommandName 'Test-PodePath' -Times 1 -Scope It
    }

    It 'Load the file contents and returns it' {
        Mock Test-PodePath { return $true }
        Mock Get-PodeFileContent { return '<html></html>' }

        $r = Write-PodeHtmlResponse -Path 'file/path'
        $r.Value | Should -Be '<html></html>'
        $r.ContentType | Should -Be $_ContentType
    }
}

Describe 'Write-PodeTextResponse' {
    It 'Does nothing for no value' {
        Write-PodeTextResponse -Value $null | Out-Null
    }

    It 'Does nothing when we have no response' {
        Write-PodeTextResponse -Value 'value' | Out-Null
    }
}

Describe 'Write-PodeFileResponse' {
    It 'Does nothing when the file does not exist' {
        Mock Get-PodeRelativePath { return $Path }
        #  Mock Test-PodePath { return $false }
        Mock Set-PodeResponseStatus {}
        Mock Get-Item { return $null }
        Write-PodeFileResponse -Path './path' | Out-Null
        Should -Invoke Set-PodeResponseStatus -Times 1 -Scope It
        # Assert-MockCalled Test-PodePath -Times 1 -Scope It
    }


    It 'Loads the contents of a dynamic file' {
        Mock Test-PodePath { return @{ PSIsContainer = $false ; extension = '.pode' } }
        Mock Get-PodeRelativePath { return $Path }
        Mock Get-PodeFileContentUsingViewEngine { return 'file contents' }
        Mock Write-PodeTextResponse { return $Value }
        Mock Get-Item { return @{ PSIsContainer = $false } }

        Write-PodeFileResponse -Path './path/file.pode' | Should -Be 'file contents'
        Should -Invoke Get-PodeFileContentUsingViewEngine -Times 1 -Scope It
        #Assert-MockCalled Get-PodeFileContentUsingViewEngine -Times 1 -Scope It
    }

    It 'Loads the contents of a static file' {

        Mock Test-PodePath { return @{ PSIsContainer = $false ; extension = '.pode' } }
        Mock Get-PodeRelativePath { return $Path }
        Mock Get-Content { return 'file contents' }
        Mock Get-PodeFileContentUsingViewEngine { return 'file contents' }
        Mock Write-PodeTextResponse { return $Value }
        Mock Get-Item { return @{ PSIsContainer = $false } }
        Write-PodeFileResponse -Path './path/file.pode' | Should -Be 'file contents'
        Should -Invoke Get-PodeFileContentUsingViewEngine -Times 1 -Scope It
        #   Assert-MockCalled Get-PodeFileContentUsingViewEngine -Times 1 -Scope It
    }
}

Describe 'Use-PodePartialView' {
    BeforeEach {
        $PodeContext = @{
            'Server' = @{
                'InbuiltDrives' = @{ 'views' = '.' }
                'ViewEngine'    = @{ 'Extension' = 'pode' }
            }
        }
        Mock Get-PodeFileContentUsingViewEngine { return 'file contents' }
    }

    It 'Throws an error for a path that does not exist' {
        Mock Test-PodePath { return $false }
        { Use-PodePartialView -Path 'sub-view.pode' } | Should -Throw -ExpectedMessage ($PodeLocale.viewsPathDoesNotExistExceptionMessage -f '*' ) # The Views path does not exist: sub-view.pode'
    }




    It 'Returns file contents, and appends view engine' {
        Mock Test-PodePath { return $true }
        Use-PodePartialView -Path 'sub-view' | Should -Be 'file contents'
    }

    It 'Returns file contents' {
        Mock Test-PodePath { return $true }
        Use-PodePartialView -Path 'sub-view.pode' | Should -Be 'file contents'
    }
}

Describe 'Close-PodeTcpClient' {
    It 'Disposes a stored client' {
        $TcpEvent = @{ 'Request' = @{} }
        $TcpEvent.Request | Add-Member -MemberType ScriptMethod -Name Close -Value { return $true } -Force
        Close-PodeTcpClient
    }
}

Describe 'Show-PodeErrorPage' {
    BeforeEach {
        Mock Write-PodeFileResponse { return $Data }
    }
    It 'Does nothing when it cannot find a page' {
        Mock Find-PodeErrorPage { return $null }
        Show-PodeErrorPage -Code 404 | Out-Null
        Should -Invoke Write-PodeFileResponse -Times 0 -Scope It
        #  Assert-MockCalled Write-PodeFileResponse -Times 0 -Scope It
    }


    It 'Renders a page with no exception' {
        Mock Find-PodeErrorPage { return @{ 'Path' = './path'; 'ContentType' = 'json' } }
        Mock Get-PodeUrl { return 'url' }
        $d = Show-PodeErrorPage -Code 404
        Should -Invoke Write-PodeFileResponse -Times 1 -Scope It
        #Assert-MockCalled Write-PodeFileResponse -Times 1 -Scope It
        $d.Url | Should -Be 'url'
        $d.Exception | Should -Be $null
        $d.ContentType | Should -Be 'json'
        $d.Status.Code | Should -Be 404
    }

    It 'Renders a page with exception' {

        Mock Find-PodeErrorPage { return @{ 'Path' = './path'; 'ContentType' = 'json' } }
        Mock Get-PodeUrl { return 'url' }
        $PodeContext = @{ 'Server' = @{ 'Web' = @{
                    'ErrorPages' = @{ 'ShowExceptions' = $true }
                }
            }
        }

        try {
            $v = $null
            $v.Add()
        }
        catch { $e = $_ }

        $d = Show-PodeErrorPage -Code 404 -Exception $e
        Should -Invoke Write-PodeFileResponse -Times 1 -Scope It
        #Assert-MockCalled Write-PodeFileResponse -Times 1 -Scope It
        $d.Url | Should -Be 'url'
        $d.Exception | Should -Not -Be $null
        $d.Exception.Message | Should -Match 'cannot call a method'
        $d.Exception.Category | Should -Match 'InvalidOperation'
        $d.Exception.StackTrace | Should -Match 'Responses.Tests.ps1'
        $d.Exception.Line | Should -Match 'Responses.Tests.ps1'
        $d.ContentType | Should -Be 'json'
        $d.Status.Code | Should -Be 404
    }
}


Describe 'Write-PodeAttachmentResponseInternal Tests' {
    BeforeAll {
        Mock Set-PodeResponseStatus {}
        Mock Write-PodeDirectoryResponseInternal {}
        Mock Get-Content { return 'testfile' }
        Mock Get-PodeContentType { return 'application/octet-stream' }
        Mock Find-PodePublicRoute {}
        Mock Get-Item {
            return @{
                PSIsContainer = $false
                Name          = 'myfile.txt'
                Extension     = '.txt'
                OpenRead      = { [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes('Test file content')) }
            }
        }
        Mock Set-PodeHeader {}

    }
    BeforeEach {
        $WebEvent = @{Response = @{} }
    }

    It 'Sets response status to 404 if file does not exist' {
        Mock Get-Item { return $null } -Verifiable

        Write-PodeAttachmentResponseInternal -Path 'nonexistent.txt' -ContentType 'text/plain' | Should -BeNullOrEmpty
        Should -Invoke Set-PodeResponseStatus -Times 1 -Scope It -ParameterFilter { $Code -eq 404 }
    }

    It 'Sets correct content type and downloads file' {
        Write-PodeAttachmentResponseInternal -Path 'existing.txt' -ContentType 'text/plain'

        Should -Invoke Set-PodeHeader -Times 1 -Scope It -ParameterFilter {
            $Name -eq 'Content-Disposition' -and $Value -like '*filename=myfile.txt'
        }
        Should -Invoke Get-PodeContentType -Times 0 -Scope It # ContentType is provided, so it should not attempt to get it
    }

    It 'Returns directory listing if FileBrowser is present and path is a directory' {
        Mock Get-Item {
            return @{
                PSIsContainer = $true
                Name          = 'mydirectory'
            }
        }

        Write-PodeAttachmentResponseInternal -Path 'mydirectory' -FileBrowser

        Should -Invoke Write-PodeDirectoryResponseInternal -Times 1 -Scope It
    }

}
