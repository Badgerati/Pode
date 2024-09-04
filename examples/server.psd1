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
                '/auth' = 'application/json'
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
        FileMonitor = @{
            Enable    = $false
            ShowFiles = $true
        }
        Logging     = @{
            Masking = @{
                Patterns = @(
                    '(?<keep_before>Password=)\w+',
                    '(?<keep_before>AppleWebKit\/)\d+\.\d+(?(<keep_after)\s+\(KHTML)'
                )
                Mask     = '--MASKED--'
            }
        }
        AutoImport  = @{
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
        Request     = @{
            Timeout  = 30
            BodySize = 100MB
        }
        Debug       = @{
            Breakpoints = @{
                Enable = $true
            }
        }
        AsyncRoutes = @{
            UserFieldIdentifier = 'Id'
            HouseKeeping        = @{
                TimerInterval    = 30
                RetentionMinutes = 10
            }
        }
        Tasks       = @{
            HouseKeeping = @{
                TimerInterval    = 30
                RetentionMinutes = 1
            }
        }
    }
}