#
# Module manifest for module 'Pode'
#
# Generated by: Matthew Kelly (Badgerati)
#
# Generated on: 28/11/2017
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Pode.psm1'

    # Version number of this module.
    ModuleVersion     = '$version$'

    # ID used to uniquely identify this module
    GUID              = 'e3ea217c-fc3d-406b-95d5-4304ab06c6af'

    # Author of this module
    Author            = 'Matthew Kelly (Badgerati)'

    # Copyright statement for this module
    Copyright         = 'Copyright (c) 2017-$buildyear$ Matthew Kelly (Badgerati), licensed under the MIT License.'

    # Description of the functionality provided by this module
    Description       = 'A Cross-Platform PowerShell framework for creating web servers to host REST APIs and Websites. Pode also has support for being used in Azure Functions and AWS Lambda.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this Module
    FunctionsToExport = @(
        # cookies
        'Get-PodeCookie',
        'Get-PodeCookieSecret',
        'Remove-PodeCookie',
        'Set-PodeCookie',
        'Set-PodeCookieSecret',
        'Test-PodeCookie',
        'Test-PodeCookieSigned',
        'Update-PodeCookieExpiry',
        'Get-PodeCookieValue',

        # flash
        'Add-PodeFlashMessage',
        'Clear-PodeFlashMessages',
        'Get-PodeFlashMessage',
        'Get-PodeFlashMessageNames',
        'Remove-PodeFlashMessage',
        'Test-PodeFlashMessage',

        # headers
        'Add-PodeHeader',
        'Add-PodeHeaderBulk',
        'Test-PodeHeader',
        'Get-PodeHeader',
        'Set-PodeHeader',
        'Set-PodeHeaderBulk',
        'Test-PodeHeaderSigned',

        # state
        'Set-PodeState',
        'Get-PodeState',
        'Remove-PodeState',
        'Save-PodeState',
        'Restore-PodeState',
        'Test-PodeState',
        'Get-PodeStateNames',

        # response helpers
        'Set-PodeResponseAttachment',
        'Write-PodeTextResponse',
        'Write-PodeFileResponse',
        'Write-PodeCsvResponse',
        'Write-PodeHtmlResponse',
        'Write-PodeMarkdownResponse',
        'Write-PodeJsonResponse',
        'Write-PodeYamlResponse',
        'Write-PodeXmlResponse',
        'Write-PodeViewResponse',
        'Write-PodeDirectoryResponse',
        'Set-PodeResponseStatus',
        'Move-PodeResponseUrl',
        'Write-PodeTcpClient',
        'Read-PodeTcpClient',
        'Close-PodeTcpClient',
        'Save-PodeRequestFile',
        'Test-PodeRequestFile',
        'Set-PodeViewEngine',
        'Use-PodePartialView',
        'Send-PodeSignal',
        'Add-PodeViewFolder',
        'Send-PodeResponse',

        # sse
        'ConvertTo-PodeSseConnection',
        'Send-PodeSseEvent',
        'Close-PodeSseConnection',
        'Test-PodeSseClientIdSigned',
        'Test-PodeSseClientIdValid',
        'New-PodeSseClientId',
        'Enable-PodeSseSigning',
        'Disable-PodeSseSigning',
        'Set-PodeSseBroadcastLevel',
        'Get-PodeSseBroadcastLevel',
        'Test-PodeSseBroadcastLevel',
        'Set-PodeSseDefaultScope',
        'Get-PodeSseDefaultScope',
        'Test-PodeSseName',
        'Test-PodeSseClientId',

        # utility helpers
        'Close-PodeDisposable',
        'Get-PodeServerPath',
        'Start-PodeStopwatch',
        'Use-PodeStream',
        'Use-PodeScript',
        'Get-PodeConfig',
        'Add-PodeEndware',
        'Use-PodeEndware',
        'Import-PodeModule',
        'Import-PodeSnapIn',
        'Protect-PodeValue',
        'Resolve-PodeValue',
        'Invoke-PodeScriptBlock',
        'Merge-PodeScriptblockArguments',
        'Test-PodeIsUnix',
        'Test-PodeIsWindows',
        'Test-PodeIsMacOS',
        'Test-PodeIsPSCore',
        'Test-PodeIsEmpty',
        'Out-PodeHost',
        'Write-PodeHost',
        'Test-PodeIsIIS',
        'Test-PodeIsHeroku',
        'Get-PodeIISApplicationPath',
        'Out-PodeVariable',
        'Test-PodeIsHosted',
        'New-PodeCron',
        'Test-PodeInRunspace',
        'ConvertFrom-PodeXml',
        'Set-PodeDefaultFolder',
        'Get-PodeDefaultFolder',
        'Get-PodeBodyData',
        'Get-PodeQueryParameter',
        'Get-PodePathParameter',
        'ConvertFrom-PodeSerializedString',
        'ConvertTo-PodeSerializedString',
        'Invoke-PodeGC',

        # routes
        'Add-PodeRoute',
        'Add-PodeStaticRoute',
        'Add-PodeSignalRoute',
        'Remove-PodeRoute',
        'Remove-PodeStaticRoute',
        'Remove-PodeSignalRoute',
        'Clear-PodeRoutes',
        'Clear-PodeStaticRoutes',
        'Clear-PodeSignalRoutes',
        'ConvertTo-PodeRoute',
        'Add-PodePage',
        'Get-PodeRoute',
        'Get-PodeStaticRoute',
        'Get-PodeSignalRoute',
        'Use-PodeRoutes',
        'Add-PodeRouteGroup',
        'Add-PodeStaticRouteGroup',
        'Add-PodeSignalRouteGroup',
        'Set-PodeRouteIfExistsPreference',
        'Test-PodeRoute',
        'Test-PodeStaticRoute',
        'Test-PodeSignalRoute',

        # handlers
        'Add-PodeHandler',
        'Remove-PodeHandler',
        'Clear-PodeHandlers',
        'Use-PodeHandlers',

        # schedules
        'Add-PodeSchedule',
        'Remove-PodeSchedule',
        'Clear-PodeSchedule',
        'Invoke-PodeSchedule',
        'Edit-PodeSchedule',
        'Set-PodeScheduleConcurrency',
        'Get-PodeSchedule',
        'Get-PodeScheduleNextTrigger',
        'Use-PodeSchedules',
        'Test-PodeSchedule',
        'Clear-PodeSchedules',
        'Get-PodeScheduleProcess',

        # timers
        'Add-PodeTimer',
        'Remove-PodeTimer',
        'Clear-PodeTimers',
        'Invoke-PodeTimer',
        'Edit-PodeTimer',
        'Get-PodeTimer',
        'Use-PodeTimers',
        'Test-PodeTimer',

        # tasks
        'Add-PodeTask',
        'Set-PodeTaskConcurrency',
        'Invoke-PodeTask',
        'Remove-PodeTask',
        'Clear-PodeTasks',
        'Edit-PodeTask',
        'Get-PodeTask',
        'Use-PodeTasks',
        'Close-PodeTask',
        'Test-PodeTaskCompleted',
        'Wait-PodeTask',
        'Get-PodeTaskProcess',

        # middleware
        'Add-PodeMiddleware',
        'Remove-PodeMiddleware',
        'Clear-PodeMiddleware',
        'Add-PodeAccessRule',
        'Add-PodeLimitRule',
        'New-PodeCsrfToken',
        'Get-PodeCsrfMiddleware',
        'Initialize-PodeCsrf',
        'Enable-PodeCsrfMiddleware',
        'Use-PodeMiddleware',
        'New-PodeMiddleware',
        'Add-PodeBodyParser',
        'Remove-PodeBodyParser',

        # sessions
        'Enable-PodeSessionMiddleware',
        'Remove-PodeSession',
        'Save-PodeSession',
        'Get-PodeSessionId',
        'Reset-PodeSessionExpiry',
        'Get-PodeSessionDuration',
        'Get-PodeSessionExpiry',
        'Test-PodeSessionsEnabled',
        'Get-PodeSessionTabId',
        'Get-PodeSessionInfo',
        'Test-PodeSessionScopeIsBrowser',

        # auth
        'New-PodeAuthScheme',
        'New-PodeAuthAzureADScheme',
        'New-PodeAuthTwitterScheme',
        'Add-PodeAuth',
        'Get-PodeAuth',
        'Clear-PodeAuth',
        'Add-PodeAuthWindowsAd',
        'Add-PodeAuthWindowsLocal',
        'Remove-PodeAuth',
        'Add-PodeAuthMiddleware',
        'Add-PodeAuthIIS',
        'Add-PodeAuthUserFile',
        'ConvertTo-PodeJwt',
        'ConvertFrom-PodeJwt',
        'Test-PodeJwt'
        'Use-PodeAuth',
        'ConvertFrom-PodeOIDCDiscovery',
        'Test-PodeAuthUser',
        'Merge-PodeAuth',
        'Test-PodeAuth',
        'Test-PodeAuthExists',
        'Get-PodeAuthUser',
        'Add-PodeAuthSession',

        # access
        'New-PodeAccessScheme',
        'Add-PodeAccess',
        'Add-PodeAccessCustom',
        'Get-PodeAccess',
        'Test-PodeAccessExists',
        'Test-PodeAccess',
        'Test-PodeAccessUser',
        'Test-PodeAccessRoute',
        'Merge-PodeAccess',
        'Remove-PodeAccess',
        'Clear-PodeAccess',
        'Add-PodeAccessMiddleware',
        'Use-PodeAccess',

        # logging
        'New-PodeLoggingMethod',
        'Enable-PodeRequestLogging',
        'Enable-PodeErrorLogging',
        'Disable-PodeRequestLogging',
        'Disable-PodeErrorLogging',
        'Add-PodeLogger',
        'Remove-PodeLogger',
        'Clear-PodeLoggers',
        'Write-PodeErrorLog',
        'Write-PodeLog',
        'Protect-PodeLogItem',
        'Use-PodeLogging',

        # core
        'Start-PodeServer',
        'Close-PodeServer',
        'Restart-PodeServer',
        'Start-PodeStaticServer',
        'Show-PodeGui',
        'Add-PodeEndpoint',
        'Get-PodeEndpoint',
        'Pode',
        'Get-PodeServerDefaultSecret',
        'Wait-PodeDebugger',
        'Get-PodeVersion',

        # openapi
        'Enable-PodeOpenApi',
        'Get-PodeOADefinition',
        'Select-PodeOADefinition',
        'Add-PodeOAResponse',
        'Remove-PodeOAResponse',
        'Set-PodeOARequest',
        'New-PodeOARequestBody',
        'Test-PodeOADefinitionTag',
        'Test-PodeOADefinition',
        'Rename-PodeOADefinitionTag',

        # properties
        'New-PodeOAIntProperty',
        'New-PodeOANumberProperty',
        'New-PodeOAStringProperty',
        'New-PodeOABoolProperty',
        'New-PodeOAObjectProperty',
        'New-PodeOAMultiTypeProperty',
        'Merge-PodeOAProperty',
        'New-PodeOAComponentSchemaProperty',
        'ConvertTo-PodeOAParameter',
        'Set-PodeOARouteInfo',
        'Enable-PodeOAViewer',
        'Test-PodeOAJsonSchemaCompliance',
        'Add-PodeOAInfo',
        'Add-PodeOAExternalDoc',
        'New-PodeOAExternalDoc',
        'Add-PodeOATag',
        'Add-PodeOAServerEndpoint',
        'New-PodeOAExample',
        'New-PodeOAEncodingObject',
        'New-PodeOAResponse',
        'Add-PodeOACallBack',
        'New-PodeOAResponseLink',
        'New-PodeOAContentMediaType',
        'Add-PodeOAExternalRoute',
        'New-PodeOAServerEndpoint',
        'Test-PodeOAVersion',

        # Components
        'Add-PodeOAComponentResponse',
        'Add-PodeOAComponentSchema',
        'Add-PodeOAComponentRequestBody',
        'Add-PodeOAComponentHeader',
        'Add-PodeOAComponentExample',
        'Add-PodeOAComponentParameter',
        'Add-PodeOAComponentResponseLink',
        'Add-PodeOAComponentCallBack',
        'Add-PodeOAComponentPathItem',
        'Add-PodeOAWebhook',
        'Test-PodeOAComponent',
        'Remove-PodeOAComponent',

        # Metrics
        'Get-PodeServerUptime',
        'Get-PodeServerRestartCount',
        'Get-PodeServerRequestMetric',
        'Get-PodeServerSignalMetric',
        'Get-PodeServerActiveRequestMetric',
        'Get-PodeServerActiveSignalMetric',

        # AutoImport
        'Export-PodeModule',
        'Export-PodeSnapin',
        'Export-PodeFunction',
        'Export-PodeSecretVault',

        # Events
        'Register-PodeEvent',
        'Unregister-PodeEvent',
        'Test-PodeEvent',
        'Get-PodeEvent',
        'Clear-PodeEvent',
        'Use-PodeEvents',

        # Security
        'Add-PodeSecurityHeader',
        'Add-PodeSecurityContentSecurityPolicy',
        'Add-PodeSecurityPermissionsPolicy',
        'Remove-PodeSecurity',
        'Remove-PodeSecurityAccessControl',
        'Remove-PodeSecurityContentSecurityPolicy',
        'Remove-PodeSecurityContentTypeOptions',
        'Remove-PodeSecurityCrossOrigin',
        'Remove-PodeSecurityFrameOptions',
        'Remove-PodeSecurityHeader',
        'Remove-PodeSecurityPermissionsPolicy',
        'Remove-PodeSecurityReferrerPolicy',
        'Remove-PodeSecurityStrictTransportSecurity',
        'Set-PodeSecurity',
        'Set-PodeSecurityAccessControl',
        'Set-PodeSecurityContentSecurityPolicy',
        'Set-PodeSecurityContentTypeOptions',
        'Set-PodeSecurityCrossOrigin',
        'Set-PodeSecurityFrameOptions',
        'Set-PodeSecurityPermissionsPolicy',
        'Set-PodeSecurityReferrerPolicy',
        'Set-PodeSecurityStrictTransportSecurity',
        'Hide-PodeSecurityServer',
        'Show-PodeSecurityServer',

        # Verbs
        'Add-PodeVerb',
        'Remove-PodeVerb',
        'Clear-PodeVerbs',
        'Get-PodeVerb',
        'Use-PodeVerbs',

        # WebSockets
        'Set-PodeWebSocketConcurrency',
        'Connect-PodeWebSocket',
        'Disconnect-PodeWebSocket',
        'Remove-PodeWebSocket',
        'Send-PodeWebSocket',
        'Reset-PodeWebSocket',
        'Test-PodeWebSocket'

        # Secrets
        'Register-PodeSecretVault',
        'Unregister-PodeSecretVault',
        'Unlock-PodeSecretVault',
        'Get-PodeSecretVault',
        'Test-PodeSecretVault',
        'Mount-PodeSecret',
        'Dismount-PodeSecret',
        'Get-PodeSecret',
        'Test-PodeSecret',
        'Update-PodeSecret',
        'Remove-PodeSecret',
        'Read-PodeSecret',
        'Set-PodeSecret',

        # File Watchers
        'Add-PodeFileWatcher',
        'Test-PodeFileWatcher',
        'Get-PodeFileWatcher',
        'Remove-PodeFileWatcher',
        'Clear-PodeFileWatchers',
        'Use-PodeFileWatchers',

        # Threading
        'Lock-PodeObject',
        'New-PodeLockable',
        'Remove-PodeLockable',
        'Get-PodeLockable',
        'Test-PodeLockable',
        'Enter-PodeLockable',
        'Exit-PodeLockable',
        'Clear-PodeLockables',
        'New-PodeMutex',
        'Test-PodeMutex',
        'Get-PodeMutex',
        'Remove-PodeMutex',
        'Use-PodeMutex',
        'Enter-PodeMutex',
        'Exit-PodeMutex',
        'Clear-PodeMutexes',
        'New-PodeSemaphore',
        'Test-PodeSemaphore',
        'Get-PodeSemaphore',
        'Remove-PodeSemaphore',
        'Use-PodeSemaphore',
        'Enter-PodeSemaphore',
        'Exit-PodeSemaphore',
        'Clear-PodeSemaphores',

        # caching
        'Get-PodeCache',
        'Set-PodeCache',
        'Test-PodeCache',
        'Remove-PodeCache',
        'Clear-PodeCache',
        'Add-PodeCacheStorage',
        'Remove-PodeCacheStorage',
        'Get-PodeCacheStorage',
        'Test-PodeCacheStorage',
        'Set-PodeCacheDefaultStorage',
        'Get-PodeCacheDefaultStorage',
        'Set-PodeCacheDefaultTtl',
        'Get-PodeCacheDefaultTtl',

        # scoped variables
        'Convert-PodeScopedVariables',
        'Convert-PodeScopedVariable',
        'Add-PodeScopedVariable',
        'Remove-PodeScopedVariable',
        'Test-PodeScopedVariable',
        'Clear-PodeScopedVariables',
        'Get-PodeScopedVariable',
        'Use-PodeScopedVariables'
    )

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = @(
        'Enable-PodeOpenApiViewer',
        'Enable-PodeOA',
        'Get-PodeOpenApiDefinition',
        'New-PodeOASchemaProperty'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{
        PSData       = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @(
                'powershell', 'web', 'server', 'http', 'https', 'listener', 'rest', 'api', 'tcp',
                'smtp', 'websites', 'powershell-core', 'windows', 'unix', 'linux', 'pode', 'PSEdition_Core',
                'cross-platform', 'file-monitoring', 'multithreaded', 'schedule', 'middleware', 'session',
                'authentication', 'authorisation', 'authorization', 'arm', 'raspberry-pi', 'aws-lambda',
                'azure-functions', 'websockets', 'swagger', 'openapi', 'webserver', 'secrets', 'fim'
            )

            # A URL to the license for this module.
            LicenseUri   = 'https://raw.githubusercontent.com/Badgerati/Pode/master/LICENSE.txt'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/Badgerati/Pode'

            # A URL to an icon representing this module.
            IconUri      = 'https://raw.githubusercontent.com/Badgerati/Pode/master/images/icon.png'

            # Release notes for this particular version of the module
            ReleaseNotes = 'https://github.com/Badgerati/Pode/releases/tag/v$version$'
        }
        PwshVersions = @{
            Untested  = '$versionsUntested$'
            Supported = '$versionsSupported$'
        }
    }
}