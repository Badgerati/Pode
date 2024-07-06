@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'Schema validation requires PowerShell version 6.1.0 or greater.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = 'A Path or ScriptBlock is required for sourcing the Custom access values.'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID: {0} has to be unique and cannot be applied to an array.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "An endpoint named '{0}' has not been defined for redirecting."
    filesHaveChangedMessage                                           = 'The following files have changed:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'IIS ASPNETCORE_TOKEN is missing.'
    minValueGreaterThanMaxExceptionMessage                            = 'Min value for {0} should not be greater than the max value.'
    noLogicPassedForRouteExceptionMessage                             = 'No logic passed for Route: {0}'
    scriptPathDoesNotExistExceptionMessage                            = 'The script path does not exist: {0}'
    mutexAlreadyExistsExceptionMessage                                = 'A mutex with the following name already exists: {0}'
    listeningOnEndpointsMessage                                       = 'Listening on the following {0} endpoint(s) [{1} thread(s)]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = 'The {0} function is not supported in a serverless context.'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = 'Expected no JWT signature to be supplied.'
    secretAlreadyMountedExceptionMessage                              = "A Secret with the name '{0}' has already been mounted."
    failedToAcquireLockExceptionMessage                               = 'Failed to acquire a lock on the object.'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: No Path supplied for Static Route.'
    invalidHostnameSuppliedExceptionMessage                           = 'Invalid hostname supplied: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = 'Authentication method already defined: {0}'
    csrfCookieRequiresSecretExceptionMessage                          = "When using cookies for CSRF, a Secret is required. You can either supply a Secret or set the Cookie global secret - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = 'A non-empty ScriptBlock is required for the authentication method.'
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = 'A non-empty ScriptBlock is required to create a Page Route.'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "The parameter 'NoProperties' is mutually exclusive with 'Properties', 'MinProperties' and 'MaxProperties'"
    incompatiblePodeDllExceptionMessage                               = 'An existing incompatible Pode.DLL version {0} is loaded. Version {1} is required. Open a new PowerShell/pwsh session and retry.'
    accessMethodDoesNotExistExceptionMessage                          = 'Access method does not exist: {0}.'
    scheduleAlreadyDefinedExceptionMessage                            = '[Schedule] {0}: Schedule already defined.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = 'Seconds value cannot be 0 or less for {0}'
    pathToLoadNotFoundExceptionMessage                                = 'Path to load {0} not found: {1}'
    failedToImportModuleExceptionMessage                              = 'Failed to import module: {0}'
    endpointNotExistExceptionMessage                                  = "Endpoint with protocol '{0}' and address '{1}' or local address '{2}' does not exist."
    terminatingMessage                                                = 'Terminating...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = 'No commands supplied to convert to Routes.'
    invalidTaskTypeExceptionMessage                                   = 'Task type is invalid, expected either [System.Threading.Tasks.Task] or [hashtable]'
    alreadyConnectedToWebSocketExceptionMessage                       = "Already connected to WebSocket with name '{0}'"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'The CRLF message end check is only supported on TCP endpoints.'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema' need to be enabled using 'Enable-PodeOpenApi -EnableSchemaValidation'"
    adModuleNotInstalledExceptionMessage                              = 'Active Directory module is not installed.'
    cronExpressionInvalidExceptionMessage                             = 'Cron expression should only consist of 5 parts: {0}'
    noSessionToSetOnResponseExceptionMessage                          = 'There is no session available to set on the response.'
    valueOutOfRangeExceptionMessage                                   = "Value '{0}' for {1} is invalid, should be between {2} and {3}"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'Logging method already defined: {0}'
    noSecretForHmac256ExceptionMessage                                = 'No secret supplied for HMAC256 hash.'
    eolPowerShellWarningMessage                                       = '[WARNING] Pode {0} has not been tested on PowerShell {1}, as it is EOL.'
    runspacePoolFailedToLoadExceptionMessage                          = '{0} RunspacePool failed to load.'
    noEventRegisteredExceptionMessage                                 = 'No {0} event registered: {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[Schedule] {0}: Cannot have a negative limit.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'OpenApi request Style cannot be {0} for a {1} parameter.'
    openApiDocumentNotCompliantExceptionMessage                       = 'OpenAPI document is not compliant.'
    taskDoesNotExistExceptionMessage                                  = "Task '{0}' does not exist."
    scopedVariableNotFoundExceptionMessage                            = 'Scoped Variable not found: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = 'Sessions are required to use CSRF unless you want to use cookies.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'A non-empty ScriptBlock is required for the logging method.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = 'When Credentials is passed, The * wildcard for Headers will be taken as a literal string and not a wildcard.'
    podeNotInitializedExceptionMessage                                = 'Pode has not been initialised.'
    multipleEndpointsForGuiMessage                                    = 'Multiple endpoints defined, only the first will be used for the GUI.'
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID: {0} has to be unique.'
    invalidJsonJwtExceptionMessage                                    = 'Invalid JSON value found in JWT'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'No algorithm supplied in JWT Header.'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'OpenApi Version property is mandatory.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = 'Limit value cannot be 0 or less for {0}'
    timerDoesNotExistExceptionMessage                                 = "Timer '{0}' does not exist."
    openApiGenerationDocumentErrorMessage                             = 'OpenAPI generation document error:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "Route '[{0}] {1}' already contains Custom Access with name '{2}'"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = 'Maximum concurrent WebSocket threads cannot be less than the minimum of {0} but got: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: Middleware already defined.'
    invalidAtomCharacterExceptionMessage                              = 'Invalid atom character: {0}'
    invalidCronAtomFormatExceptionMessage                             = 'Invalid cron atom format found: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "Cache storage with name '{0}' not found when attempting to retrieve cached item '{1}'"
    headerMustHaveNameInEncodingContextExceptionMessage               = 'Header must have a name when used in an encoding context.'
    moduleDoesNotContainFunctionExceptionMessage                      = 'Module {0} does not contain function {1} to convert to a Route.'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'Path to the icon for GUI does not exist: {0}'
    noTitleSuppliedForPageExceptionMessage                            = 'No title supplied for {0} page.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'Certificate supplied for non-HTTPS/WSS endpoint.'
    cannotLockNullObjectExceptionMessage                              = 'Cannot lock an object that is null.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui is currently only available for Windows PowerShell and PowerShell 7+ on Windows OS.'
    unlockSecretButNoScriptBlockExceptionMessage                      = 'Unlock secret supplied for custom Secret Vault type, but not Unlock ScriptBlock supplied.'
    invalidIpAddressExceptionMessage                                  = 'The IP address supplied is invalid: {0}'
    maxDaysInvalidExceptionMessage                                    = 'MaxDays must be 0 or greater, but got: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "No Remove ScriptBlock supplied for removing secrets from the vault '{0}'"
    noSecretExpectedForNoSignatureExceptionMessage                    = 'Expected no secret to be supplied for no signature.'
    noCertificateFoundExceptionMessage                                = "No certificate could be found in {0}{1} for '{2}'"
    minValueInvalidExceptionMessage                                   = "Min value '{0}' for {1} is invalid, should be greater than/equal to {2}"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = 'Access requires Authentication to be supplied on Routes.'
    noSecretForHmac384ExceptionMessage                                = 'No secret supplied for HMAC384 hash.'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'Windows Local Authentication support is for Windows OS only.'
    definitionTagNotDefinedExceptionMessage                           = 'DefinitionTag {0} does not exist.'
    noComponentInDefinitionExceptionMessage                           = 'No component of type {0} named {1} is available in the {2} definition.'
    noSmtpHandlersDefinedExceptionMessage                             = 'No SMTP handlers have been defined.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'Session Middleware has already been initialised.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "The 'pathItems' reusable component feature is not available in OpenAPI v3.0."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = 'The * wildcard for Headers is incompatible with the AutoHeaders switch.'
    noDataForFileUploadedExceptionMessage                             = "No data for file '{0}' was uploaded in the request."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSE can only be configured on requests with an Accept header value of text/event-stream'
    noSessionAvailableToSaveExceptionMessage                          = 'There is no session available to save.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "If the parameter location is 'Path', the switch parameter 'Required' is mandatory."
    noOpenApiUrlSuppliedExceptionMessage                              = 'No OpenAPI URL supplied for {0}.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = 'Maximum concurrent schedules must be >=1 but got: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Snapins are only supported on Windows PowerShell.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = 'Event Viewer logging only supported on Windows OS.'
    parametersMutuallyExclusiveExceptionMessage                       = "Parameters '{0}' and '{1}' are mutually exclusive."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = 'The PathItems feature is not supported in OpenAPI v3.0.x'
    openApiParameterRequiresNameExceptionMessage                      = 'The OpenApi parameter requires a name to be specified.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = 'Maximum concurrent tasks cannot be less than the minimum of {0} but got: {1}'
    noSemaphoreFoundExceptionMessage                                  = "No semaphore found called '{0}'"
    singleValueForIntervalExceptionMessage                            = 'You can only supply a single {0} value when using intervals.'
    jwtNotYetValidExceptionMessage                                    = 'The JWT is not yet valid for use.'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[Verb] {0}: Already defined for {1}'
    noSecretNamedMountedExceptionMessage                              = "No Secret named '{0}' has been mounted."
    moduleOrVersionNotFoundExceptionMessage                           = 'Module or version not found on {0}: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'No ScriptBlock supplied.'
    noSecretVaultRegisteredExceptionMessage                           = "No Secret Vault with the name '{0}' has been registered."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'A Name is required for the endpoint if the RedirectTo parameter is supplied.'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "The OpenAPI object 'license' required the property 'name'. Use -LicenseName parameter."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: The Source path supplied for Static Route does not exist: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = 'No Name for a WebSocket to disconnect from supplied.'
    certificateExpiredExceptionMessage                                = "The certificate '{0}' has expired: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = 'Secret Vault unlock expiry date is in the past (UTC): {0}'
    invalidWebExceptionTypeExceptionMessage                           = 'Exception is of an invalid type, should be either WebException or HttpRequestException, but got: {0}'
    invalidSecretValueTypeExceptionMessage                            = 'Secret value is of an invalid type. Expected types: String, SecureString, HashTable, Byte[], or PSCredential. But got: {0}'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = 'The Explicit TLS mode is only supported on SMTPS and TCPS endpoints.'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "The parameter 'DiscriminatorMapping' can only be used when 'DiscriminatorProperty' is present."
    scriptErrorExceptionMessage                                       = "Error '{0}' in script {1} {2} (line {3}) char {4} executing {5} on {6} object '{7}' Class: {8} BaseClass: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = 'Cannot supply interval value for every quarter.'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[Schedule] {0}: The EndTime value must be in the future.'
    invalidJwtSignatureSuppliedExceptionMessage                       = 'Invalid JWT signature supplied.'
    noSetScriptBlockForVaultExceptionMessage                          = "No Set ScriptBlock supplied for updating/creating secrets in the vault '{0}'"
    accessMethodNotExistForMergingExceptionMessage                    = 'Access method does not exist for merging: {0}'
    defaultAuthNotInListExceptionMessage                              = "The Default Authentication '{0}' is not in the Authentication list supplied."
    parameterHasNoNameExceptionMessage                                = "The Parameter has no name. Please give this component a name using the 'Name' parameter."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: Already defined for {2}'
    fileWatcherAlreadyDefinedExceptionMessage                         = "A File Watcher named '{0}' has already been defined."
    noServiceHandlersDefinedExceptionMessage                          = 'No Service handlers have been defined.'
    secretRequiredForCustomSessionStorageExceptionMessage             = 'A Secret is required when using custom session storage.'
    secretManagementModuleNotInstalledExceptionMessage                = 'Microsoft.PowerShell.SecretManagement module not installed.'
    noPathSuppliedForRouteExceptionMessage                            = 'No Path supplied for the Route.'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "Validation of a schema that includes 'anyof' is not supported."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'IIS Authentication support is for Windows OS only.'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'OAuth2 InnerScheme can only be one of either Basic or Form authentication, but got: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = 'No route path supplied for {0} page.'
    cacheStorageNotFoundForExistsExceptionMessage                     = "Cache storage with name '{0}' not found when attempting to check if cached item '{1}' exists."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: Handler already defined.'
    sessionsNotConfiguredExceptionMessage                             = 'Sessions have not been configured.'
    propertiesTypeObjectAssociationExceptionMessage                   = 'Only properties of type Object can be associated with {0}.'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = 'Sessions are required to use session persistent authentication.'
    invalidPathWildcardOrDirectoryExceptionMessage                    = 'The Path supplied cannot be a wildcard or a directory: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = 'Access method already defined: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "Parameters 'Value' or 'ExternalValue' are mandatory"
    maximumConcurrentTasksInvalidExceptionMessage                     = 'Maximum concurrent tasks must be >=1 but got: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = 'Cannot create the property because no type is defined.'
    authMethodNotExistForMergingExceptionMessage                      = 'Authentication method does not exist for merging: {0}'
    maxValueInvalidExceptionMessage                                   = "Max value '{0}' for {1} is invalid, should be less than/equal to {2}"
    endpointAlreadyDefinedExceptionMessage                            = "An endpoint named '{0}' has already been defined."
    eventAlreadyRegisteredExceptionMessage                            = '{0} event already registered: {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "A parameter called '{0}' was not supplied in the request or has no data available."
    cacheStorageNotFoundForSetExceptionMessage                        = "Cache storage with name '{0}' not found when attempting to set cached item '{1}'"
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: Already defined.'
    errorLoggingAlreadyEnabledExceptionMessage                        = 'Error Logging has already been enabled.'
    valueForUsingVariableNotFoundExceptionMessage                     = "Value for '`$using:{0}' could not be found."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = "The Document tool RapidPdf doesn't support OpenAPI 3.1"
    oauth2ClientSecretRequiredExceptionMessage                        = 'OAuth2 requires a Client Secret when not using PKCE.'
    invalidBase64JwtExceptionMessage                                  = 'Invalid Base64 encoded value found in JWT'
    noSessionToCalculateDataHashExceptionMessage                      = 'No session available to calculate data hash.'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "Cache storage with name '{0}' not found when attempting to remove cached item '{1}'"
    csrfMiddlewareNotInitializedExceptionMessage                      = 'CSRF Middleware has not been initialised.'
    infoTitleMandatoryMessage                                         = 'info.title is mandatory.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = 'Type {0} can only be associated with an Object.'
    userFileDoesNotExistExceptionMessage                              = 'The user file does not exist: {0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = 'The Route parameter needs a valid, not empty, scriptblock.'
    nextTriggerCalculationErrorExceptionMessage                       = 'Looks like something went wrong trying to calculate the next trigger datetime: {0}'
    cannotLockValueTypeExceptionMessage                               = 'Cannot lock a [ValueType]'
    failedToCreateOpenSslCertExceptionMessage                         = 'Failed to create OpenSSL cert: {0}'
    jwtExpiredExceptionMessage                                        = 'The JWT has expired.'
    openingGuiMessage                                                 = 'Opening the GUI.'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = 'Multi-type properties require OpenApi Version 3.1 or above.'
    noNameForWebSocketRemoveExceptionMessage                          = 'No Name for a WebSocket to remove supplied.'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize must be 0 or greater, but got: {0}'
    iisShutdownMessage                                                = '(IIS Shutdown)'
    cannotUnlockValueTypeExceptionMessage                             = 'Cannot unlock a [ValueType]'
    noJwtSignatureForAlgorithmExceptionMessage                        = 'No JWT signature supplied for {0}.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = 'Maximum concurrent WebSocket threads must be >=1 but got: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = 'The Acknowledge message is only supported on SMTP and TCP endpoints.'
    failedToConnectToUrlExceptionMessage                              = 'Failed to connect to URL: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = 'Failed to acquire mutex ownership. Mutex name: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'Sessions are required to use OAuth2 with PKCE'
    failedToConnectToWebSocketExceptionMessage                        = 'Failed to connect to WebSocket: {0}'
    unsupportedObjectExceptionMessage                                 = 'Unsupported object'
    failedToParseAddressExceptionMessage                              = "Failed to parse '{0}' as a valid IP/Host:Port address"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'Must be running with administrator privileges to listen on non-localhost addresses.'
    specificationMessage                                              = 'Specification'
    cacheStorageNotFoundForClearExceptionMessage                      = "Cache storage with name '{0}' not found when attempting to clear the cache."
    restartingServerMessage                                           = 'Restarting server...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "Cannot supply an interval when the parameter 'Every' is set to None."
    unsupportedJwtAlgorithmExceptionMessage                           = 'The JWT algorithm is not currently supported: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'WebSockets have not been configured to send signal messages.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = 'A Hashtable Middleware supplied has an invalid Logic type. Expected ScriptBlock, but got: {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = 'Maximum concurrent schedules cannot be less than the minimum of {0} but got: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = 'Failed to acquire semaphore ownership. Semaphore name: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = 'The Properties parameters cannot be used if the Property has no name.'
    customSessionStorageMethodNotImplementedExceptionMessage          = "The custom session storage does not implement the required '{0}()' method."
    authenticationMethodDoesNotExistExceptionMessage                  = 'Authentication method does not exist: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'The Webhooks feature is not supported in OpenAPI v3.0.x'
    invalidContentTypeForSchemaExceptionMessage                       = "Invalid 'content-type' found for schema: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "No Unlock ScriptBlock supplied for unlocking the vault '{0}'"
    definitionTagMessage                                              = 'Definition {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'Failed to open RunspacePool: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'Failed to close RunspacePool: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[Verb] {0}: No logic passed'
    noMutexFoundExceptionMessage                                      = "No mutex found called '{0}'"
    documentationMessage                                              = 'Documentation'
    timerAlreadyDefinedExceptionMessage                               = '[Timer] {0}: Timer already defined.'
    invalidPortExceptionMessage                                       = 'The port cannot be negative: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = 'The Views folder name already exists: {0}'
    noNameForWebSocketResetExceptionMessage                           = 'No Name for a WebSocket to reset supplied.'
    mergeDefaultAuthNotInListExceptionMessage                         = "The MergeDefault Authentication '{0}' is not in the Authentication list supplied."
    descriptionRequiredExceptionMessage                               = 'A Description is required.'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'The Page name should be a valid Alphanumeric value: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = 'The default value is not a boolean and is not part of the enum.'
    openApiComponentSchemaDoesNotExistExceptionMessage                = "The OpenApi component schema {0} doesn't exist."
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[Timer] {0}: {1} must be greater than 0.'
    taskTimedOutExceptionMessage                                      = 'Task has timed out after {0}ms.'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = '[Schedule] {0}: Cannot have a StartTime after the EndTime'
    infoVersionMandatoryMessage                                       = 'info.version is mandatory.'
    cannotUnlockNullObjectExceptionMessage                            = 'Cannot unlock an object that is null.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = 'A non-empty ScriptBlock is required for the Custom authentication scheme.'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "Validation of a schema that includes 'oneof' is not supported."
    routeParameterCannotBeNullExceptionMessage                        = "The parameter 'Route' cannot be null."
    cacheStorageAlreadyExistsExceptionMessage                         = "Cache Storage with name '{0}' already exists."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "The supplied output Method for the '{0}' Logging method requires a valid ScriptBlock."
    scopedVariableAlreadyDefinedExceptionMessage                      = 'Scoped Variable already defined: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = "OAuth2 requires an 'AuthoriseUrl' property to be supplied."
    pathNotExistExceptionMessage                                      = 'Path does not exist: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = 'No domain server name has been supplied for Windows AD authentication'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = 'Supplied date is after the end time of the schedule at {0}'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = 'The * wildcard for Methods is incompatible with the AutoMethods switch.'
    cannotSupplyIntervalForYearExceptionMessage                       = 'Cannot supply interval value for every year.'
    missingComponentsMessage                                          = 'Missing component(s)'
    invalidStrictTransportSecurityDurationExceptionMessage            = 'Invalid Strict-Transport-Security duration supplied: {0}. It should be greater than 0.'
    noSecretForHmac512ExceptionMessage                                = 'No secret supplied for HMAC512 hash.'
    daysInMonthExceededExceptionMessage                               = '{0} only has {1} days, but {2} was supplied.'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'A non-empty ScriptBlock is required for the Custom logging output method.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = 'The encoding attribute only applies to multipart and application/x-www-form-urlencoded request bodies.'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = 'Supplied date is before the start time of the schedule at {0}'
    unlockSecretRequiredExceptionMessage                              = "An 'UnlockSecret' property is required when using Microsoft.PowerShell.SecretStore"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: No logic passed.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = 'A body-parser is already defined for the {0} content-type.'
    invalidJwtSuppliedExceptionMessage                                = 'Invalid JWT supplied.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'Sessions are required to use Flash messages.'
    semaphoreAlreadyExistsExceptionMessage                            = 'A semaphore with the following name already exists: {0}'
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = 'Invalid JWT header algorithm supplied.'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "The OAuth2 provider does not support the 'password' grant_type required by using an InnerScheme."
    invalidAliasFoundExceptionMessage                                 = 'Invalid {0} alias found: {1}'
    scheduleDoesNotExistExceptionMessage                              = "Schedule '{0}' does not exist."
    accessMethodNotExistExceptionMessage                              = 'Access method does not exist: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "The OAuth2 provider does not support the 'code' response_type."
    untestedPowerShellVersionWarningMessage                           = '[WARNING] Pode {0} has not been tested on PowerShell {1}, as it was not available when Pode was released.'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "A Secret Vault with the name '{0}' has already been registered while auto-importing Secret Vaults."
    schemeRequiresValidScriptBlockExceptionMessage                    = "The supplied scheme for the '{0}' authentication validator requires a valid ScriptBlock."
    serverLoopingMessage                                              = 'Server looping every {0}secs'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'Certificate Thumbprints/Name are only supported on Windows OS.'
    sseConnectionNameRequiredExceptionMessage                         = "An SSE connection Name is required, either from -Name or `$WebEvent.Sse.Name"
    invalidMiddlewareTypeExceptionMessage                             = 'One of the Middlewares supplied is an invalid type. Expected either a ScriptBlock or Hashtable, but got: {0}'
    noSecretForJwtSignatureExceptionMessage                           = 'No secret supplied for JWT signature.'
    modulePathDoesNotExistExceptionMessage                            = 'The module path does not exist: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[Task] {0}: Task already defined.'
    verbAlreadyDefinedExceptionMessage                                = '[Verb] {0}: Already defined'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'Client certificates are only supported on HTTPS endpoints.'
    endpointNameNotExistExceptionMessage                              = "Endpoint with name '{0}' does not exist."
    middlewareNoLogicSuppliedExceptionMessage                         = '[Middleware]: No logic supplied in ScriptBlock.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'A Scriptblock for merging multiple authenticated users into 1 object is required When Valid is All.'
    secretVaultAlreadyRegisteredExceptionMessage                      = "A Secret Vault with the name '{0}' has already been registered{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "WARNING: Title, Version, and Description on 'Enable-PodeOpenApi' are deprecated. Please use 'Add-PodeOAInfo' instead."
    undefinedOpenApiReferencesMessage                                 = 'Undefined OpenAPI References:'
    doneMessage                                                       = 'Done'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = "This version on Swagger-Editor doesn't support OpenAPI 3.1"
    durationMustBeZeroOrGreaterExceptionMessage                       = 'Duration must be 0 or greater, but got: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = 'The Views path does not exist: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "The parameter 'Discriminator' is incompatible with 'allOf'."
    noNameForWebSocketSendMessageExceptionMessage                     = 'No Name for a WebSocket to send message to supplied.'
    hashtableMiddlewareNoLogicExceptionMessage                        = 'A Hashtable Middleware supplied has no Logic defined.'
    openApiInfoMessage                                                = 'OpenAPI Info:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "The supplied '{0}' Scheme for the '{1}' authentication validator requires a valid ScriptBlock."
    sseFailedToBroadcastExceptionMessage                              = 'SSE failed to broadcast due to defined SSE broadcast level for {0}: {1}'
    adModuleWindowsOnlyExceptionMessage                               = 'Active Directory module only available on Windows OS.'
    requestLoggingAlreadyEnabledExceptionMessage                      = 'Request Logging has already been enabled.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = 'Invalid Access-Control-Max-Age duration supplied: {0}. Should be greater than 0.'
    UnsupportedSerializationTypeExceptionMessage                      = 'Unsupported serialization type: {0}'
    GetRequestBodyNotAllowedExceptionMessage                          = 'GET operations cannot have a Request Body.'
    InvalidQueryFormatExceptionMessage                                = 'The query provided has an invalid format.'
}

