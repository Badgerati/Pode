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
            DisableTermination  = $false    # Prevent Ctrl+C from terminating the server.
            DisableConsoleInput = $false    # Disable all console input controls.
            Quiet               = $false    # Suppress console output.
            ClearHost           = $false    # Clear the console output at startup.
            ShowOpenAPI         = $true     # Display OpenAPI information.
            ShowEndpoints       = $true     # Display listening endpoints.
            ShowHelp            = $false    # Show help instructions in the console.
            ShowDivider         = $true     # Display dividers between sections.
            DividerLength       = 75        # Length of dividers in the console.
            ShowTimeStamp       = $true     # Display timestamp in the header.
            Colors              = @{        # Customize console colors.
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
            KeyBindings         = @{        # Define custom key bindings for controls.
                Browser   = 'b'             # Open the default browser.
                Help      = 'h'             # Show/hide help instructions.
                OpenAPI   = 'o'             # Show/hide OpenAPI information.
                Endpoints = 'e'             # Show/hide endpoints.
                Clear     = 'l'             # Clear the console output.
                Quiet     = 't'             # Toggle quiet mode.
                Terminate = 'c'             # Terminate the server.
                Restart   = 'r'             # Restart the server.
                Disable   = 'd'             # Disable the server.
                Suspend   = 'u'             # Suspend the server.
            }
        }
    }
}