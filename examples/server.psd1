@{
    Web    = @{
        Static      = @{
            Defaults = @(
                'index.html',
                'default.html'
            )
            Cache    = @{
                Enable  = $true
                MaxAge  = 15
                Include = @(
                    '*.jpg'
                )
            }
        }
        ErrorPages  = @{
            ShowExceptions      = $true
            StrictContentTyping = $true
            Default             = 'application/html'
            Routes              = @{
                '/john' = 'application/json'
            }
        }
        Compression = @{
            Enable = $false
        }
        OpenApi     = @{
            UsePodeYamlInternal = $true
        }
    }
    Server = @{
        FileMonitor    = @{
            Enable    = $false
            ShowFiles = $true
        }
        Logging        = @{
            Masking = @{
                Patterns = @(
                    '(?<keep_before>Password=)\w+',
                    '(?<keep_before>AppleWebKit\/)\d+\.\d+(?(<keep_after)\s+\(KHTML)'
                )
                Mask     = '--MASKED--'
            }
        }
        AutoImport     = @{
            Functions    = @{
                ExportOnly = $true
            }
            Modules      = @{
                ExportOnly = $true
            }
            SecretVaults = @{
                SecretManagement = @{
                    ExportOnly = $true
                }
            }
        }
        Request        = @{
            Timeout  = 30
            BodySize = 100MB
        }
        Debug          = @{
            Breakpoints = @{
                Enable = $true
            }
        }
        AllowedActions = @{
            Suspend = $true
            Restart = $true
            Timeout = @{
                Suspend = 30
                Resume  = 30
            }
        }
        Console        = @{
            DisableTermination  = $false
            DisableConsoleInput = $false
            Quiet               = $false
            ClearHost           = $false
            ShowOpenAPI         = $true
            ShowEndpoints       = $true
            ShowHelp            = $false
            ShowDivider         = $true
            DividerLength       = 75
            ShowTimeStamp       = $true
            Colors              = @{
                Header           = 'White'
                EndpointsHeader  = 'Yellow'
                Endpoints        = 'Cyan'
                OpenApiUrls      = 'Cyan'
                OpenApiHeaders   = 'Yellow'
                OpenApiTitles    = 'White'
                OpenApiSubtitles = 'Yellow'
                HelpHeader       = 'Yellow'
                HelpKey          = 'Green'
                HelpDescription  = 'White'
                HelpDivider      = 'Gray'
                Divider          = 'DarkGray'
            }
            KeyBindings         = @{
                Browser   = 'b'
                Help      = 'h'
                OpenAPI   = 'o'
                Endpoints = 'e'
                Clear     = 'l'
                Quiet     = 't'
                Terminate = 'c'
                Restart   = 'r'
                Disable   = 'd'
                Suspend   = 'u'
            }

        }
    }
}