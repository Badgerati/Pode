@{
    Web    = @{
        Static      = @{
            Defaults               = @(
                'index.html',
                'default.html'
            )
            Cache                  = @{
                Enable  = $true
                MaxAge  = 15
                Include = @(
                    '*.jpg'
                )
            }
            ContentDeliveryNetwork = 'https://cdn.jsdelivr.net/npm'
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
                Patterns   = @(
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
            Suspend         = $true       # Enable or disable the suspend operation
            Restart         = $true       # Enable or disable the restart operation
            Disable         = $true       # Enable or disable the disable operation
            DisableSettings = @{
                RetryAfter    = 3600                        # Default retry time (in seconds) for Disable-PodeServer
                LimitRuleName = '__Pode_Disable_Code_503__' # Name of the rate limit rule
            }
            Timeout         = @{
                Suspend = 30       # Maximum seconds to wait before suspending
                Resume  = 30       # Maximum seconds to wait before resuming
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
                Header            = 'White'      # The server's header section, including the Pode version and timestamp.
                EndpointsHeader   = 'Yellow'     # The header for the endpoints list.
                Endpoints         = 'Cyan'       # The endpoints URLs.
                EndpointsProtocol = 'White'      # The endpoints protocol.
                EndpointsFlag     = 'Gray'       # The endpoints flags.
                EndpointsName     = 'Magenta'    # The endpoints name.
                OpenApiUrls       = 'Cyan'       # URLs listed under the OpenAPI information section.
                OpenApiHeaders    = 'Yellow'     # Section headers for OpenAPI information.
                OpenApiTitles     = 'White'      # The OpenAPI "default" title.
                OpenApiSubtitles  = 'Yellow'     # Subtitles under OpenAPI (e.g., Specification, Documentation).
                HelpHeader        = 'Yellow'     # Header for the Help section.
                HelpKey           = 'Green'      # Key bindings listed in the Help section (e.g., Ctrl+c).
                HelpDescription   = 'White'      # Descriptions for each Help section key binding.
                HelpDivider       = 'Gray'       # Dividers used in the Help section.
                Divider           = 'DarkGray'   # Dividers between console sections.
                MetricsHeader     = 'Yellow'     # Header for the Metric section.
                MetricsLabel      = 'White'      # Labels for values displayed in the Metrics section.
                MetricsValue      = 'Green'      # The actual values displayed in the Metrics section.
            }
            KeyBindings         = @{        # Define custom key bindings for controls. Refer to https://learn.microsoft.com/en-us/dotnet/api/system.consolekey?view=net-9.0
                Browser   = 'B'             # Open the default browser.
                Help      = 'H'             # Show/hide help instructions.
                OpenAPI   = 'O'             # Show/hide OpenAPI information.
                Endpoints = 'E'             # Show/hide endpoints.
                Clear     = 'L'             # Clear the console output.
                Quiet     = 'Q'             # Toggle quiet mode.
                Terminate = 'C'             # Terminate the server.
                Restart   = 'R'             # Restart the server.
                Disable   = 'D'             # Disable the server.
                Suspend   = 'P'             # Suspend the server.
                Metrics   = 'M'             # Show Metrics.
            }
        }
    }
}