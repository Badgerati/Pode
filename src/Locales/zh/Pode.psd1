@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = '架构验证需要 PowerShell 版本 6.1.0 或更高版本。'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = '对于源自自定义访问值，需要路径或 ScriptBlock。'
    operationIdMustBeUniqueForArrayExceptionMessage                   = '操作ID: {0} 必须唯一，不能应用于数组。'
    endpointNotDefinedForRedirectingExceptionMessage                  = "未定义用于重定向的名为 '{0}' 的端点。"
    filesHaveChangedMessage                                           = '以下文件已更改:'
    iisAspnetcoreTokenMissingExceptionMessage                         = '缺少 IIS ASPNETCORE_TOKEN。'
    minValueGreaterThanMaxExceptionMessage                            = '{0} 的最小值不应大于最大值。'
    noLogicPassedForRouteExceptionMessage                             = '没有为路径传递逻辑: {0}'
    scriptPathDoesNotExistExceptionMessage                            = '脚本路径不存在: {0}'
    mutexAlreadyExistsExceptionMessage                                = "名为 '{0}' 的互斥量已存在。"
    listeningOnEndpointsMessage                                       = '正在监听以下 {0} 个端点 [{1} 个线程]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = '不支持在无服务器上下文中使用 {0} 函数。'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = '预期不提供 JWT 签名。'
    secretAlreadyMountedExceptionMessage                              = "名为'{0}'的秘密已挂载。"
    failedToAcquireLockExceptionMessage                               = '未能获取对象的锁。'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: 没有为静态路径提供路径。'
    invalidHostnameSuppliedExceptionMessage                           = '提供的主机名无效: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = '身份验证方法已定义：{0}'
    csrfCookieRequiresSecretExceptionMessage                          = "使用 CSRF 的 Cookie 时，需要一个密钥。您可以提供一个密钥或设置全局 Cookie 密钥 - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = '创建页面路由需要非空的ScriptBlock。'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "参数'NoProperties'与'Properties'、'MinProperties'和'MaxProperties'互斥。"
    incompatiblePodeDllExceptionMessage                               = '已加载存在不兼容的 Pode.DLL 版本 {0}。需要版本 {1}。请打开新的 Powershell/pwsh 会话并重试。'
    accessMethodDoesNotExistExceptionMessage                          = '访问方法不存在：{0}。'
    scheduleAlreadyDefinedExceptionMessage                            = '[计划] {0}: 计划已定义。'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = '{0} 的秒数值不能为 0 或更小。'
    pathToLoadNotFoundExceptionMessage                                = '未找到要加载的路径 {0}: {1}'
    failedToImportModuleExceptionMessage                              = '导入模块失败: {0}'
    endpointNotExistExceptionMessage                                  = "具有协议 '{0}' 和地址 '{1}' 或本地地址 '{2}' 的端点不存在。"
    terminatingMessage                                                = '正在终止'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = '未提供要转换为路由的命令。'
    invalidTaskTypeExceptionMessage                                   = '任务类型无效，预期类型为[System.Threading.Tasks.Task]或[hashtable]。'
    alreadyConnectedToWebSocketExceptionMessage                       = "已连接到名为 '{0}' 的 WebSocket"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'CRLF消息结束检查仅支持TCP端点。'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "必须使用 'Enable-PodeOpenApi -EnableSchemaValidation' 启用 'Test-PodeOAComponentSchema'。"
    adModuleNotInstalledExceptionMessage                              = '未安装 Active Directory 模块。'
    cronExpressionInvalidExceptionMessage                             = 'Cron 表达式应仅包含 5 个部分: {0}'
    noSessionToSetOnResponseExceptionMessage                          = '没有可用的会话来设置响应。'
    valueOutOfRangeExceptionMessage                                   = "{1} 的值 '{0}' 无效，应在 {2} 和 {3} 之间"
    loggingMethodAlreadyDefinedExceptionMessage                       = '日志记录方法已定义: {0}'
    noSecretForHmac256ExceptionMessage                                = '未提供 HMAC256 哈希的密钥。'
    eolPowerShellWarningMessage                                       = '[警告] Pode {0} 未在 PowerShell {1} 上测试，因为它已达到 EOL。'
    runspacePoolFailedToLoadExceptionMessage                          = '{0} RunspacePool 加载失败。'
    noEventRegisteredExceptionMessage                                 = '没有注册的 {0} 事件：{1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[计划] {0}: 不能有负数限制。'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'OpenApi 请求样式不能为 {0}，适用于 {1} 参数。'
    openApiDocumentNotCompliantExceptionMessage                       = 'OpenAPI 文档不符合规范。'
    taskDoesNotExistExceptionMessage                                  = "任务 '{0}' 不存在。"
    scopedVariableNotFoundExceptionMessage                            = '未找到范围变量: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = '使用CSRF需要会话, 除非您想使用Cookie。'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = '日志记录方法需要非空的ScriptBlock。'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = '传递凭据时，标头的通配符 * 将被视为文字字符串，而不是通配符。'
    podeNotInitializedExceptionMessage                                = 'Pode未初始化。'
    multipleEndpointsForGuiMessage                                    = '定义了多个端点，仅第一个将用于 GUI。'
    operationIdMustBeUniqueExceptionMessage                           = '操作ID: {0} 必须唯一。'
    invalidJsonJwtExceptionMessage                                    = '在 JWT 中找到无效的 JSON 值'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'JWT 头中未提供算法。'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'OpenApi 版本属性是必需的。'
    limitValueCannotBeZeroOrLessExceptionMessage                      = '{0} 的限制值不能为 0 或更小。'
    timerDoesNotExistExceptionMessage                                 = "计时器 '{0}' 不存在。"
    openApiGenerationDocumentErrorMessage                             = 'OpenAPI 生成文档错误:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "路由 '[{0}] {1}' 已经包含名称为 '{2}' 的自定义访问。"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = '最大并发 WebSocket 线程数不能小于最小值 {0}，但获得: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: 中间件已定义。'
    invalidAtomCharacterExceptionMessage                              = '无效的原子字符: {0}'
    invalidCronAtomFormatExceptionMessage                             = '发现无效的 cron 原子格式: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "尝试检索缓存项 '{1}' 时，找不到名为 '{0}' 的缓存存储。"
    headerMustHaveNameInEncodingContextExceptionMessage               = '在编码上下文中使用时，标头必须有名称。'
    moduleDoesNotContainFunctionExceptionMessage                      = '模块 {0} 不包含要转换为路径的函数 {1}。'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'GUI 图标的路径不存在: {0}'
    noTitleSuppliedForPageExceptionMessage                            = '未提供 {0} 页面的标题。'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = '为非HTTPS/WSS端点提供的证书。'
    cannotLockNullObjectExceptionMessage                              = '无法锁定空对象。'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui目前仅适用于Windows PowerShell和Windows上的PowerShell 7+。'
    unlockSecretButNoScriptBlockExceptionMessage                      = '为自定义秘密保险库类型提供了解锁密钥，但未提供解锁 ScriptBlock。'
    invalidIpAddressExceptionMessage                                  = '提供的 IP 地址无效: {0}'
    maxDaysInvalidExceptionMessage                                    = 'MaxDays 必须大于或等于 0, 但得到: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "未为从保险库 '{0}' 中删除秘密提供删除 ScriptBlock。"
    noSecretExpectedForNoSignatureExceptionMessage                    = '预期未提供签名的密钥。'
    noCertificateFoundExceptionMessage                                = "在 {0}{1} 中找不到证书 '{2}'。"
    minValueInvalidExceptionMessage                                   = "{1} 的最小值 '{0}' 无效，应大于或等于 {2}"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = '访问需要在路由上进行身份验证。'
    noSecretForHmac384ExceptionMessage                                = '未提供 HMAC384 哈希的密钥。'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'Windows 本地身份验证支持仅适用于 Windows。'
    definitionTagNotDefinedExceptionMessage                           = '定义标签 {0} 未定义。'
    noComponentInDefinitionExceptionMessage                           = '定义中没有类型为 {0} 名称为 {1} 的组件。'
    noSmtpHandlersDefinedExceptionMessage                             = '未定义 SMTP 处理程序。'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = '会话中间件已初始化。'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "OpenAPI v3.0中不支持可重用组件功能'pathItems'。"
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = '标头的通配符 * 与 AutoHeaders 开关不兼容。'
    noDataForFileUploadedExceptionMessage                             = "请求中未上传文件 '{0}' 的数据。"
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSE只能在Accept标头值为text/event-stream的请求上配置。'
    noSessionAvailableToSaveExceptionMessage                          = '没有可保存的会话。'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "如果参数位置是 'Path'，则 'Required' 开关参数是必需的。"
    noOpenApiUrlSuppliedExceptionMessage                              = '未提供 {0} 的 OpenAPI URL。'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = '最大并发计划数必须 >=1, 但得到: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Snapins 仅支持 Windows PowerShell。'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = '事件查看器日志记录仅支持Windows。'
    parametersMutuallyExclusiveExceptionMessage                       = "参数 '{0}' 和 '{1}' 是互斥的。"
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = '在 OpenAPI v3.0.x 中不支持 PathItems 功能。'
    openApiParameterRequiresNameExceptionMessage                      = 'OpenApi 参数需要指定名称。'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = '最大并发任务数不能小于最小值 {0}，但获得: {1}'
    noSemaphoreFoundExceptionMessage                                  = "找不到名为 '{0}' 的信号量"
    singleValueForIntervalExceptionMessage                            = '当使用间隔时，只能提供单个 {0} 值。'
    jwtNotYetValidExceptionMessage                                    = 'JWT 尚未有效。'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[Verb] {0}: 已经为 {1} 定义'
    noSecretNamedMountedExceptionMessage                              = "没有挂载名为'{0}'的秘密。"
    moduleOrVersionNotFoundExceptionMessage                           = '在 {0} 上找不到模块或版本: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = '未提供脚本块。'
    noSecretVaultRegisteredExceptionMessage                           = "未注册名为 '{0}' 的秘密保险库。"
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = '如果提供了RedirectTo参数, 则需要为端点指定名称。'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "OpenAPI 对象 'license' 需要属性 'name'。请使用 -LicenseName 参数。"
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: 为静态路径提供的源路径不存在: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = '没有提供断开连接的 WebSocket 的名称。'
    certificateExpiredExceptionMessage                                = "证书 '{0}' 已过期: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = '秘密保险库的解锁到期日期已过 (UTC) :{0}'
    invalidWebExceptionTypeExceptionMessage                           = '异常类型无效，应为 WebException 或 HttpRequestException, 但得到了: {0}'
    invalidSecretValueTypeExceptionMessage                            = '密钥值是无效的类型。期望类型: 字符串、SecureString、HashTable、Byte[] 或 PSCredential。但得到了: {0}'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = '显式TLS模式仅支持SMTPS和TCPS端点。'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "参数'DiscriminatorMapping'只能在存在'DiscriminatorProperty'时使用。"
    scriptErrorExceptionMessage                                       = "脚本 '{0}' 在 {1} {2} (第 {3} 行) 第 {4} 个字符处执行 {5} 对象 '{7}' 的错误。类: {8} 基类: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = '无法为每季度提供间隔值。'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[计划] {0}: EndTime 值必须在将来。'
    invalidJwtSignatureSuppliedExceptionMessage                       = '提供的 JWT 签名无效。'
    noSetScriptBlockForVaultExceptionMessage                          = "未为更新/创建保险库 '{0}' 中的秘密提供设置 ScriptBlock。"
    accessMethodNotExistForMergingExceptionMessage                    = '合并时访问方法不存在: {0}'
    defaultAuthNotInListExceptionMessage                              = "默认身份验证 '{0}' 不在提供的身份验证列表中。"
    parameterHasNoNameExceptionMessage                                = "参数没有名称。请使用'Name'参数为此组件命名。"
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: 已经为 {2} 定义。'
    fileWatcherAlreadyDefinedExceptionMessage                         = "名为 '{0}' 的文件监视器已定义。"
    noServiceHandlersDefinedExceptionMessage                          = '未定义服务处理程序。'
    secretRequiredForCustomSessionStorageExceptionMessage             = '使用自定义会话存储时需要一个密钥。'
    secretManagementModuleNotInstalledExceptionMessage                = '未安装 Microsoft.PowerShell.SecretManagement 模块。'
    noPathSuppliedForRouteExceptionMessage                            = '未为路由提供路径。'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "不支持包含 'anyof' 的模式的验证。"
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'IIS 身份验证支持仅适用于 Windows。'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'OAuth2 InnerScheme 只能是 Basic 或 Form 身份验证，但得到：{0}'
    noRoutePathSuppliedForPageExceptionMessage                        = '未提供 {0} 页面的路由路径。'
    cacheStorageNotFoundForExistsExceptionMessage                     = "尝试检查缓存项 '{1}' 是否存在时，找不到名为 '{0}' 的缓存存储。"
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: 处理程序已定义。'
    sessionsNotConfiguredExceptionMessage                             = '会话尚未配置。'
    propertiesTypeObjectAssociationExceptionMessage                   = '只有 Object 类型的属性可以与 {0} 关联。'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = '使用会话持久性身份验证需要会话。'
    invalidPathWildcardOrDirectoryExceptionMessage                    = '提供的路径不能是通配符或目录: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = '访问方法已经定义: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "参数 'Value' 或 'ExternalValue' 是必需的。"
    maximumConcurrentTasksInvalidExceptionMessage                     = '最大并发任务数必须 >=1, 但获得: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = '无法创建属性，因为未定义类型。'
    authMethodNotExistForMergingExceptionMessage                      = '合并时身份验证方法不存在：{0}'
    maxValueInvalidExceptionMessage                                   = "{1} 的最大值 '{0}' 无效，应小于或等于 {2}"
    endpointAlreadyDefinedExceptionMessage                            = "名为 '{0}' 的端点已定义。"
    eventAlreadyRegisteredExceptionMessage                            = '{0} 事件已注册：{1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "请求中未提供名为 '{0}' 的参数或没有可用数据。"
    cacheStorageNotFoundForSetExceptionMessage                        = "尝试设置缓存项 '{1}' 时，找不到名为 '{0}' 的缓存存储。"
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: 已经定义。'
    errorLoggingAlreadyEnabledExceptionMessage                        = '错误日志记录已启用。'
    valueForUsingVariableNotFoundExceptionMessage                     = "未找到 '`$using:{0}' 的值。"
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = '文档工具 RapidPdf 不支持 OpenAPI 3.1'
    oauth2ClientSecretRequiredExceptionMessage                        = '不使用 PKCE 时, OAuth2 需要一个客户端密钥。'
    invalidBase64JwtExceptionMessage                                  = '在 JWT 中找到无效的 Base64 编码值'
    noSessionToCalculateDataHashExceptionMessage                      = '没有可用的会话来计算数据哈希。'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "尝试删除缓存项 '{1}' 时，找不到名为 '{0}' 的缓存存储。"
    csrfMiddlewareNotInitializedExceptionMessage                      = 'CSRF中间件未初始化。'
    infoTitleMandatoryMessage                                         = 'info.title 是必填项。'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = '类型{0}只能与对象关联。'
    userFileDoesNotExistExceptionMessage                              = '用户文件不存在：{0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = '路由参数需要有效且非空的ScriptBlock。'
    nextTriggerCalculationErrorExceptionMessage                       = '似乎在尝试计算下一个触发器日期时间时出现了问题: {0}'
    cannotLockValueTypeExceptionMessage                               = '无法锁定[ValueType]。'
    failedToCreateOpenSslCertExceptionMessage                         = '创建 OpenSSL 证书失败: {0}'
    jwtExpiredExceptionMessage                                        = 'JWT 已过期。'
    openingGuiMessage                                                 = '正在打开 GUI。'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = '多类型属性需要 OpenApi 版本 3.1 或更高版本。'
    noNameForWebSocketRemoveExceptionMessage                          = '没有提供要删除的 WebSocket 的名称。'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize 必须大于或等于 0,但得到: {0}'
    iisShutdownMessage                                                = '(IIS 关闭)'
    cannotUnlockValueTypeExceptionMessage                             = '无法解锁[ValueType]。'
    noJwtSignatureForAlgorithmExceptionMessage                        = '没有为 {0} 提供 JWT 签名。'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = '最大并发 WebSocket 线程数必须 >=1, 但获得: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = '确认消息仅支持SMTP和TCP端点。'
    failedToConnectToUrlExceptionMessage                              = '连接到 URL 失败: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = '未能获得互斥量的所有权。互斥量名称: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = '使用 PKCE 时需要会话来使用 OAuth2'
    failedToConnectToWebSocketExceptionMessage                        = '连接到 WebSocket 失败: {0}'
    unsupportedObjectExceptionMessage                                 = '不支持的对象'
    failedToParseAddressExceptionMessage                              = "无法将 '{0}' 解析为有效的 IP/主机:端口地址"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = '必须以管理员权限运行才能监听非本地主机地址。'
    specificationMessage                                              = '规格'
    cacheStorageNotFoundForClearExceptionMessage                      = "尝试清除缓存时，找不到名为 '{0}' 的缓存存储。"
    restartingServerMessage                                           = '正在重启服务器...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "当参数'Every'设置为None时, 无法提供间隔。"
    unsupportedJwtAlgorithmExceptionMessage                           = '当前不支持的 JWT 算法: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'WebSockets未配置为发送信号消息。'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = '提供的 Hashtable 中间件具有无效的逻辑类型。期望是 ScriptBlockm, 但得到了: {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = '最大并发计划数不能小于最小值 {0}，但得到: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = '未能获得信号量的所有权。信号量名称: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = '如果属性没有名称，则不能使用 Properties 参数。'
    customSessionStorageMethodNotImplementedExceptionMessage          = "自定义会话存储未实现所需的方法'{0}()'。"
    authenticationMethodDoesNotExistExceptionMessage                  = '认证方法不存在: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = '在 OpenAPI v3.0.x 中不支持 Webhooks 功能'
    invalidContentTypeForSchemaExceptionMessage                       = "架构中发现无效的 'content-type': {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "未为解锁保险库 '{0}' 提供解锁 ScriptBlock。"
    definitionTagMessage                                              = '定义 {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = '打开 RunspacePool 失败: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = '无法关闭RunspacePool: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[动词] {0}: 未传递逻辑'
    noMutexFoundExceptionMessage                                      = "找不到名为 '{0}' 的互斥量"
    documentationMessage                                              = '文档'
    timerAlreadyDefinedExceptionMessage                               = '[计时器] {0}: 计时器已定义。'
    invalidPortExceptionMessage                                       = '端口不能为负数: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = '视图文件夹名称已存在: {0}'
    noNameForWebSocketResetExceptionMessage                           = '没有提供要重置的 WebSocket 的名称。'
    mergeDefaultAuthNotInListExceptionMessage                         = "MergeDefault 身份验证 '{0}' 不在提供的身份验证列表中。"
    descriptionRequiredExceptionMessage                               = '路径:{0} 响应:{1} 需要描述'
    pageNameShouldBeAlphaNumericExceptionMessage                      = '页面名称应为有效的字母数字值: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = '默认值不是布尔值且不属于枚举。'
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'OpenApi 组件架构 {0} 不存在。'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[计时器] {0}: {1} 必须大于 0。'
    taskTimedOutExceptionMessage                                      = '任务在 {0} 毫秒后超时。'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[计划] {0}: 'StartTime' 不能在 'EndTime' 之后"
    infoVersionMandatoryMessage                                       = 'info.version 是必填项。'
    cannotUnlockNullObjectExceptionMessage                            = '无法解锁空对象。'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = '自定义身份验证方案需要一个非空的 ScriptBlock。'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = '身份验证方法需要非空的 ScriptBlock。'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "不支持包含 'oneof' 的模式的验证。"
    routeParameterCannotBeNullExceptionMessage                        = "参数 'Route' 不能为空。"
    cacheStorageAlreadyExistsExceptionMessage                         = "名为 '{0}' 的缓存存储已存在。"
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "为 '{0}' 日志记录方法提供的输出方法需要有效的 ScriptBlock。"
    scopedVariableAlreadyDefinedExceptionMessage                      = '已经定义了作用域变量: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = 'OAuth2 需要提供授权 URL'
    pathNotExistExceptionMessage                                      = '路径不存在: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = '没有为 Windows AD 身份验证提供域服务器名称'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = '提供的日期晚于计划的结束时间 {0}'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = '方法的通配符 * 与 AutoMethods 开关不兼容。'
    cannotSupplyIntervalForYearExceptionMessage                       = '无法为每年提供间隔值。'
    missingComponentsMessage                                          = '缺少的组件'
    invalidStrictTransportSecurityDurationExceptionMessage            = '提供的严格传输安全持续时间无效: {0}。应大于 0。'
    noSecretForHmac512ExceptionMessage                                = '未提供 HMAC512 哈希的密钥。'
    daysInMonthExceededExceptionMessage                               = '{0} 仅有 {1} 天，但提供了 {2} 天。'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = '自定义日志输出方法需要非空的ScriptBlock。'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = '编码属性仅适用于 multipart 和 application/x-www-form-urlencoded 请求体。'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = '提供的日期早于计划的开始时间 {0}'
    unlockSecretRequiredExceptionMessage                              = "使用 Microsoft.PowerShell.SecretStore 时需要 'UnlockSecret' 属性。"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: 没有传递逻辑。'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = '已为 {0} 内容类型定义了一个 body-parser。'
    invalidJwtSuppliedExceptionMessage                                = '提供的 JWT 无效。'
    sessionsRequiredForFlashMessagesExceptionMessage                  = '使用闪存消息需要会话。'
    semaphoreAlreadyExistsExceptionMessage                            = "名为 '{0}' 的信号量已存在。"
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = '提供的 JWT 头算法无效。'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "OAuth2 提供程序不支持使用 InnerScheme 所需的 'password' grant_type。"
    invalidAliasFoundExceptionMessage                                 = '找到了无效的 {0} 别名: {1}'
    scheduleDoesNotExistExceptionMessage                              = "计划 '{0}' 不存在。"
    accessMethodNotExistExceptionMessage                              = '访问方法不存在: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "OAuth2 提供程序不支持 'code' response_type。"
    untestedPowerShellVersionWarningMessage                           = '[警告] Pode {0} 未在 PowerShell {1} 上测试，因为 Pode 发布时该版本不可用。'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "已经注册了名称为 '{0}' 的秘密保险库，同时正在自动导入秘密保险库。"
    schemeRequiresValidScriptBlockExceptionMessage                    = "提供的方案用于 '{0}' 身份验证验证器，需要一个有效的 ScriptBlock。"
    serverLoopingMessage                                              = '服务器每 {0} 秒循环一次'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = '证书指纹/名称仅在 Windows 上受支持。'
    sseConnectionNameRequiredExceptionMessage                         = "需要SSE连接名称, 可以从-Name或`$WebEvent.Sse.Name获取。"
    invalidMiddlewareTypeExceptionMessage                             = '提供的中间件之一是无效的类型。期望是 ScriptBlock 或 Hashtable, 但得到了: {0}'
    modulePathDoesNotExistExceptionMessage                            = '模块路径不存在: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[任务] {0}: 任务已定义。'
    verbAlreadyDefinedExceptionMessage                                = '[Verb] {0}: 已经定义'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = '客户端证书仅支持HTTPS端点。'
    endpointNameNotExistExceptionMessage                              = "名为 '{0}' 的端点不存在。"
    middlewareNoLogicSuppliedExceptionMessage                         = '[中间件]: ScriptBlock中未提供逻辑。'
    scriptBlockRequiredForMergingUsersExceptionMessage                = '当 Valid 是 All 时，需要一个 ScriptBlock 来将多个经过身份验证的用户合并为一个对象。'
    secretVaultAlreadyRegisteredExceptionMessage                      = "名为'{0}'的秘密保险库已注册{1}。"
    deprecatedTitleVersionDescriptionWarningMessage                   = "警告: 'Enable-PodeOpenApi' 的标题、版本和描述已被弃用。请改用 'Add-PodeOAInfo'。"
    undefinedOpenApiReferencesMessage                                 = '未定义的 OpenAPI 引用:'
    doneMessage                                                       = '完成'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = '此版本的 Swagger-Editor 不支持 OpenAPI 3.1'
    durationMustBeZeroOrGreaterExceptionMessage                       = '持续时间必须为 0 或更大，但获得: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = '视图路径不存在: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "参数'Discriminator'与'allOf'不兼容。"
    noNameForWebSocketSendMessageExceptionMessage                     = '没有提供要发送消息的 WebSocket 的名称。'
    hashtableMiddlewareNoLogicExceptionMessage                        = '提供的 Hashtable 中间件没有定义逻辑。'
    openApiInfoMessage                                                = 'OpenAPI 信息:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "提供的 '{0}' 方案用于 '{1}' 身份验证验证器，需要一个有效的 ScriptBlock。"
    sseFailedToBroadcastExceptionMessage                              = '由于为{0}定义的SSE广播级别, SSE广播失败: {1}'
    adModuleWindowsOnlyExceptionMessage                               = '仅支持 Windows 的 Active Directory 模块。'
    requestLoggingAlreadyEnabledExceptionMessage                      = '请求日志记录已启用。'
    invalidAccessControlMaxAgeDurationExceptionMessage                = '提供的 Access-Control-Max-Age 时长无效：{0}。应大于 0。'
    openApiDefinitionAlreadyExistsExceptionMessage                    = '名为 {0} 的 OpenAPI 定义已存在。'
    renamePodeOADefinitionTagExceptionMessage                         = "Rename-PodeOADefinitionTag 不能在 Select-PodeOADefinition 'ScriptBlock' 内使用。"
    taskProcessDoesNotExistExceptionMessage                           = "任务进程 '{0}' 不存在。"
    scheduleProcessDoesNotExistExceptionMessage                       = "计划进程 '{0}' 不存在。"
    definitionTagChangeNotAllowedExceptionMessage                     = 'Route的定义标签无法更改。'
    getRequestBodyNotAllowedExceptionMessage                          = "'{0}' 操作无法包含请求体。使用 -AllowNonStandardBody 以解除此限制。"
    fnDoesNotAcceptArrayAsPipelineInputExceptionMessage               = "函数 '{0}' 不接受数组作为管道输入。"
    unsupportedStreamCompressionEncodingExceptionMessage              = '不支持的流压缩编码: {0}'
    localEndpointConflictExceptionMessage                             = "'{0}' 和 '{1}' 都被定义为 OpenAPI 的本地端点，但每个 API 定义仅允许一个本地端点。"
    suspendingMessage                                                 = '暂停'
    resumingMessage                                                   = '恢复'
    serverControlCommandsTitle                                        = '服务器控制命令:'
    gracefullyTerminateMessage                                        = '正常终止服务器。'
    restartServerMessage                                              = '重启服务器并重新加载配置。'
    resumeServerMessage                                               = '恢复服务器。'
    suspendServerMessage                                              = '暂停服务器。'
    startingMessage                                                   = '启动中'
    restartingMessage                                                 = '正在重启'
    suspendedMessage                                                  = '已暂停'
    runningMessage                                                    = '运行中'
    openHttpEndpointMessage                                           = '在默认浏览器中打开第一个 HTTP 端点。'
    terminatedMessage                                                 = '已终止'
    showMetricsMessage                                                = '显示指标'
    clearConsoleMessage                                               = '清除控制台'
    serverMetricsMessage                                              = '服务器指标'
    totalUptimeMessage                                                = '总运行时间:'
    uptimeSinceLastRestartMessage                                     = '自上次重启后的运行时间:'
    totalRestartMessage                                               = '重启总次数:'
    defaultEndpointAlreadySetExceptionMessage                         = "类型 '{0}' 的默认端点已设置。每种类型只允许一个默认端点。"
    enableHttpServerMessage                                           = '启用HTTP服务器'
    disableHttpServerMessage                                          = '禁用HTTP服务器'
    showHelpMessage                                                   = '显示帮助'
    hideHelpMessage                                                   = '隐藏帮助'
    hideEndpointsMessage                                              = '隐藏端点'
    showEndpointsMessage                                              = '显示端点'
    hideOpenAPIMessage                                                = '隐藏OpenAPI'
    showOpenAPIMessage                                                = '显示OpenAPI'
    enableQuietModeMessage                                            = '启用安静模式'
    disableQuietModeMessage                                           = '禁用安静模式'
    rateLimitRuleAlreadyExistsExceptionMessage                        = '速率限制规则已存在: {0}'
    rateLimitRuleDoesNotExistExceptionMessage                         = '速率限制规则不存在: {0}'
    accessLimitRuleAlreadyExistsExceptionMessage                      = '访问限制规则已存在: {0}'
    accessLimitRuleDoesNotExistExceptionMessage                       = '访问限制规则不存在: {0}'
    missingKeyForAlgorithmExceptionMessage                            = 'Uma chave {0} é necessária para os algoritmos {1} ({2}).'
    jwtIssuedInFutureExceptionMessage                                 = "JWT 的 'iat' (签发时间) 时间戳设置在未来。该令牌尚未生效。"
    jwtInvalidIssuerExceptionMessage                                  = "JWT 的 'iss' (发行者) 声明无效或缺失。预期发行者: '{0}'。"
    jwtMissingIssuerExceptionMessage                                  = "JWT 缺少必要的 'iss' (发行者) 声明。必须提供有效的发行者。"
    jwtInvalidAudienceExceptionMessage                                = "JWT 的 'aud' (受众) 声明无效或缺失。预期受众: '{0}'。"
    jwtMissingAudienceExceptionMessage                                = "JWT 缺少必要的 'aud' (受众) 声明。必须提供有效的受众。"
    jwtInvalidSubjectExceptionMessage                                 = "JWT 的 'sub' (主题) 声明无效或缺失。必须提供有效的主题。"
    jwtInvalidJtiExceptionMessage                                     = "JWT 的 'jti' (JWT ID) 声明无效或缺失。必须提供有效的唯一标识符。"
    jwtAlgorithmMismatchExceptionMessage                              = 'JWT 算法不匹配: 预期 {0}，实际 {1}。'
    jwtMissingJtiExceptionMessage                                     = "JWT 缺少必要的 'jti' (JWT ID) 声明。"
    deprecatedFunctionWarningMessage                                  = "警告: 函数 '{0}' 已被弃用，并将在未来版本中移除。请改用函数 '{1}'。"
    unknownAlgorithmOrInvalidPfxExceptionMessage                      = '未知算法或无效的 PEM 格式。'
    unknownAlgorithmWithKeySizeExceptionMessage                       = '未知 {0} 算法（密钥大小: {1} 位）。'
    jwtCertificateAuthNotSupportedExceptionMessage                    = 'JWT 证书身份验证仅支持 PowerShell 7.0 或更高版本。'
    jwtNoExpirationExceptionMessage                                   = "JWT 缺少必要的 'exp' (到期时间) 声明。必须提供有效的到期时间。"
    bearerTokenAuthMethodNotSupportedExceptionMessage                 = '使用请求正文进行Bearer令牌认证仅支持HTTP PUT、POST或PATCH方法。'
    certificateNotValidYetExceptionMessage                            = '证书 {0} 仍然无效。有效期开始: {1} (UTC)'
    certificateNotValidForPurposeExceptionMessage                     = "证书对 '{0}' 无效。发现的用途: {1}"
    certificateUnknownEkusStrictModeExceptionMessage                  = '证书包含未知的 EKU。严格模式拒绝它。发现: {0}'
    failedToCreateCertificateRequestExceptionMessage                  = '生成证书请求失败。'
    unsupportedCertificateKeyLengthExceptionMessage                   = '不支持的证书密钥长度: {0} 位。请使用受支持的密钥长度。'
    invalidTypeExceptionMessage                                       = '错误: {0} 的类型无效。期望 {1}，但收到 [{2}]。'
    certificateSignatureInvalidExceptionMessage                       = '证书 {0} 的签名无效。证书可能已被篡改，或未由受信任的机构签署。'
    certificateUntrustedRootExceptionMessage                          = '证书 {0} 由不受信任的根证书颁发。请安装根 CA 证书或使用受信任机构的证书。'
    certificateRevokedExceptionMessage                                = '证书 {0} 已被吊销。原因: {1}。请获取新的有效证书。'
    certificateExpiredIntermediateExceptionMessage                    = '证书 {0} 由 {1} 过期的中间证书签署。证书链已失效。'
    certificateValidationFailedExceptionMessage                       = '证书 {0} 的验证失败。请检查证书链和有效期。'
    certificateWeakAlgorithmExceptionMessage                          = '证书 {0} 使用了弱加密算法: {1}。建议使用 SHA-256 或更强的算法。'
    selfSignedCertificatesNotAllowedExceptionMessage                  = '由于安全限制，不允许使用自签名证书。'
}