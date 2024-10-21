@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = '스키마 유효성 검사는 PowerShell 버전 6.1.0 이상이 필요합니다.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = '사용자 지정 액세스 값을 소싱하기 위해 경로 또는 ScriptBlock이 필요합니다.'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID: {0}은(는) 고유해야 하며 배열에 적용될 수 없습니다.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "리디렉션을 위해 이름이 '{0}'인 엔드포인트가 정의되지 않았습니다."
    filesHaveChangedMessage                                           = '다음 파일이 변경되었습니다:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'IIS ASPNETCORE_TOKEN이 누락되었습니다.'
    minValueGreaterThanMaxExceptionMessage                            = '{0}의 최소 값은 최대 값보다 클 수 없습니다.'
    noLogicPassedForRouteExceptionMessage                             = '경로에 대한 논리가 전달되지 않았습니다: {0}'
    scriptPathDoesNotExistExceptionMessage                            = '스크립트 경로가 존재하지 않습니다: {0}'
    mutexAlreadyExistsExceptionMessage                                = "이름이 '{0}'인 뮤텍스가 이미 존재합니다."
    listeningOnEndpointsMessage                                       = '다음 {0} 엔드포인트에서 수신 중 [{1} 스레드]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = '{0} 함수는 서버리스 컨텍스트에서 지원되지 않습니다.'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = 'JWT 서명이 제공되지 않을 것으로 예상되었습니다.'
    secretAlreadyMountedExceptionMessage                              = "이름이 '{0}'인 시크릿이 이미 마운트되었습니다."
    failedToAcquireLockExceptionMessage                               = '개체에 대한 잠금을 획득하지 못했습니다.'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: 정적 경로에 대한 경로가 제공되지 않았습니다.'
    invalidHostnameSuppliedExceptionMessage                           = '제공된 호스트 이름이 잘못되었습니다: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = '인증 방법이 이미 정의되었습니다: {0}'
    csrfCookieRequiresSecretExceptionMessage                          = "CSRF에 대해 쿠키를 사용할 때, 비밀이 필요합니다. 비밀을 제공하거나 전역 비밀 쿠키를 설정하십시오 - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = '페이지 경로를 생성하려면 비어 있지 않은 ScriptBlock이 필요합니다.'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "매개변수 'NoProperties'는 'Properties', 'MinProperties' 및 'MaxProperties'와 상호 배타적입니다."
    incompatiblePodeDllExceptionMessage                               = '기존의 호환되지 않는 Pode.DLL 버전 {0}이 로드되었습니다. 버전 {1}이 필요합니다. 새로운 Powershell/pwsh 세션을 열고 다시 시도하세요.'
    accessMethodDoesNotExistExceptionMessage                          = '접근 방법이 존재하지 않습니다: {0}.'
    scheduleAlreadyDefinedExceptionMessage                            = '[스케줄] {0}: 스케줄이 이미 정의되어 있습니다.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = '{0}에 대한 초 값은 0 이하일 수 없습니다.'
    pathToLoadNotFoundExceptionMessage                                = '로드할 경로 {0}을(를) 찾을 수 없습니다: {1}'
    failedToImportModuleExceptionMessage                              = '모듈을 가져오지 못했습니다: {0}'
    endpointNotExistExceptionMessage                                  = "프로토콜 '{0}' 및 주소 '{1}' 또는 로컬 주소 '{2}'가 있는 엔드포인트가 존재하지 않습니다."
    terminatingMessage                                                = '종료 중...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = '경로로 변환할 명령이 제공되지 않았습니다.'
    invalidTaskTypeExceptionMessage                                   = '작업 유형이 유효하지 않습니다. 예상된 유형: [System.Threading.Tasks.Task] 또는 [hashtable]'
    alreadyConnectedToWebSocketExceptionMessage                       = "이름이 '{0}'인 WebSocket에 이미 연결되어 있습니다."
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'CRLF 메시지 끝 검사는 TCP 엔드포인트에서만 지원됩니다.'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema'는 'Enable-PodeOpenApi -EnableSchemaValidation'을 사용하여 활성화해야 합니다."
    adModuleNotInstalledExceptionMessage                              = 'Active Directory 모듈이 설치되지 않았습니다.'
    cronExpressionInvalidExceptionMessage                             = 'Cron 표현식은 5개의 부분으로만 구성되어야 합니다: {0}'
    noSessionToSetOnResponseExceptionMessage                          = '응답에 설정할 세션이 없습니다.'
    valueOutOfRangeExceptionMessage                                   = "{1}의 값 '{0}'이(가) 유효하지 않습니다. {2}와 {3} 사이여야 합니다."
    loggingMethodAlreadyDefinedExceptionMessage                       = '로깅 방법이 이미 정의되었습니다: {0}'
    noSecretForHmac256ExceptionMessage                                = 'HMAC256 해시를 위한 비밀이 제공되지 않았습니다.'
    eolPowerShellWarningMessage                                       = '[경고] Pode {0}은 EOL 상태인 PowerShell {1}에서 테스트되지 않았습니다.'
    runspacePoolFailedToLoadExceptionMessage                          = '{0} RunspacePool 로드 실패.'
    noEventRegisteredExceptionMessage                                 = '등록된 {0} 이벤트가 없습니다: {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[스케줄] {0}: 음수 한도를 가질 수 없습니다.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'OpenApi 요청 스타일은 {1} 매개변수에 대해 {0}일 수 없습니다.'
    openApiDocumentNotCompliantExceptionMessage                       = 'OpenAPI 문서는 준수하지 않습니다.'
    taskDoesNotExistExceptionMessage                                  = "작업 '{0}'이(가) 존재하지 않습니다."
    scopedVariableNotFoundExceptionMessage                            = '범위 변수 {0}을(를) 찾을 수 없습니다.'
    sessionsRequiredForCsrfExceptionMessage                           = '쿠키를 사용하지 않으려면 CSRF 사용을 위해 세션이 필요합니다.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = '로깅 방법에는 비어 있지 않은 ScriptBlock이 필요합니다.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = '자격 증명이 전달되면, 헤더에 대한 * 와일드카드는 와일드카드가 아닌 리터럴 문자열로 취급됩니다.'
    podeNotInitializedExceptionMessage                                = 'Pode가 초기화되지 않았습니다.'
    multipleEndpointsForGuiMessage                                    = '여러 엔드포인트가 정의되었으며, GUI에는 첫 번째만 사용됩니다.'
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID: {0}은(는) 고유해야 합니다.'
    invalidJsonJwtExceptionMessage                                    = 'JWT에서 잘못된 JSON 값이 발견되었습니다.'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'JWT 헤더에 제공된 알고리즘이 없습니다.'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'OpenApi 버전 속성은 필수입니다.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = '{0}에 대한 제한 값은 0 이하일 수 없습니다.'
    timerDoesNotExistExceptionMessage                                 = "타이머 '{0}'이(가) 존재하지 않습니다."
    openApiGenerationDocumentErrorMessage                             = 'OpenAPI 생성 문서 오류:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "경로 '[{0}] {1}'에 '{2}' 이름의 사용자 지정 액세스가 이미 포함되어 있습니다."
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = '최대 동시 WebSocket 스레드는 최소값 {0}보다 작을 수 없지만 받은 값: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: 미들웨어가 이미 정의되었습니다.'
    invalidAtomCharacterExceptionMessage                              = '잘못된 원자 문자: {0}'
    invalidCronAtomFormatExceptionMessage                             = '잘못된 크론 원자 형식이 발견되었습니다: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "캐시된 항목 '{1}'을(를) 검색하려고 할 때 이름이 '{0}'인 캐시 스토리지를 찾을 수 없습니다."
    headerMustHaveNameInEncodingContextExceptionMessage               = '인코딩 컨텍스트에서 사용될 때 헤더는 이름이 있어야 합니다.'
    moduleDoesNotContainFunctionExceptionMessage                      = '모듈 {0}에 경로로 변환할 함수 {1}이(가) 포함되어 있지 않습니다.'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'GUI용 아이콘의 경로가 존재하지 않습니다: {0}'
    noTitleSuppliedForPageExceptionMessage                            = '{0} 페이지에 대한 제목이 제공되지 않았습니다.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'HTTPS/WSS가 아닌 엔드포인트에 제공된 인증서입니다.'
    cannotLockNullObjectExceptionMessage                              = 'null 개체를 잠글 수 없습니다.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui는 현재 Windows PowerShell 및 Windows의 PowerShell 7+에서만 사용할 수 있습니다.'
    unlockSecretButNoScriptBlockExceptionMessage                      = '사용자 정의 비밀 금고 유형에 대해 제공된 Unlock 비밀이지만, Unlock ScriptBlock이 제공되지 않았습니다.'
    invalidIpAddressExceptionMessage                                  = '제공된 IP 주소가 유효하지 않습니다: {0}'
    maxDaysInvalidExceptionMessage                                    = 'MaxDays는 0 이상이어야 하지만, 받은 값: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "금고 '{0}'에서 비밀을 제거하기 위한 Remove ScriptBlock이 제공되지 않았습니다."
    noSecretExpectedForNoSignatureExceptionMessage                    = '서명이 없는 경우 비밀이 제공되지 않아야 합니다.'
    noCertificateFoundExceptionMessage                                = "'{2}'에 대한 {0}{1}에서 인증서를 찾을 수 없습니다."
    minValueInvalidExceptionMessage                                   = "{1}의 최소 값 '{0}'이(가) 유효하지 않습니다. {2} 이상이어야 합니다."
    accessRequiresAuthenticationOnRoutesExceptionMessage              = '경로에 대한 접근은 인증이 필요합니다.'
    noSecretForHmac384ExceptionMessage                                = 'HMAC384 해시를 위한 비밀이 제공되지 않았습니다.'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'Windows 로컬 인증 지원은 Windows 전용입니다.'
    definitionTagNotDefinedExceptionMessage                           = '정의 태그 {0}이(가) 정의되지 않았습니다.'
    noComponentInDefinitionExceptionMessage                           = '{2} 정의에서 {0} 유형의 {1} 이름의 구성 요소가 없습니다.'
    noSmtpHandlersDefinedExceptionMessage                             = '정의된 SMTP 핸들러가 없습니다.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = '세션 미들웨어가 이미 초기화되었습니다.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "OpenAPI v3.0에서는 재사용 가능한 구성 요소 기능 'pathItems'를 사용할 수 없습니다."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = '헤더에 대한 * 와일드카드는 AutoHeaders 스위치와 호환되지 않습니다.'
    noDataForFileUploadedExceptionMessage                             = "요청에서 업로드된 파일 '{0}'에 대한 데이터가 없습니다."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSE는 Accept 헤더 값이 text/event-stream인 요청에서만 구성할 수 있습니다.'
    noSessionAvailableToSaveExceptionMessage                          = '저장할 수 있는 세션이 없습니다.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "매개변수 위치가 'Path'인 경우 'Required' 스위치 매개변수가 필수입니다."
    noOpenApiUrlSuppliedExceptionMessage                              = '{0}에 대한 OpenAPI URL이 제공되지 않았습니다.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = '최대 동시 스케줄 수는 1 이상이어야 하지만 받은 값: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Snapins는 Windows PowerShell에서만 지원됩니다.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = '이벤트 뷰어 로깅은 Windows에서만 지원됩니다.'
    parametersMutuallyExclusiveExceptionMessage                       = "매개변수 '{0}'와(과) '{1}'는 상호 배타적입니다."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = 'PathItems 기능은 OpenAPI v3.0.x에서 지원되지 않습니다.'
    openApiParameterRequiresNameExceptionMessage                      = 'OpenApi 매개변수에는 이름이 필요합니다.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = '최대 동시 작업 수는 최소값 {0}보다 작을 수 없지만 받은 값: {1}'
    noSemaphoreFoundExceptionMessage                                  = "이름이 '{0}'인 세마포어를 찾을 수 없습니다."
    singleValueForIntervalExceptionMessage                            = '간격을 사용할 때는 단일 {0} 값을 제공할 수 있습니다.'
    jwtNotYetValidExceptionMessage                                    = 'JWT가 아직 유효하지 않습니다.'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[동사] {0}: {1}에 대해 이미 정의되었습니다.'
    noSecretNamedMountedExceptionMessage                              = "이름이 '{0}'인 시크릿이 마운트되지 않았습니다."
    moduleOrVersionNotFoundExceptionMessage                           = '{0}에서 모듈 또는 버전을 찾을 수 없습니다: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'ScriptBlock이 제공되지 않았습니다.'
    noSecretVaultRegisteredExceptionMessage                           = "이름이 '{0}'인 비밀 금고가 등록되지 않았습니다."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'RedirectTo 매개변수가 제공된 경우 엔드포인트에 이름이 필요합니다.'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "OpenAPI 객체 'license'는 'name' 속성이 필요합니다. -LicenseName 매개변수를 사용하십시오."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: 정적 경로에 대한 제공된 소스 경로가 존재하지 않습니다: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = '연결을 끊을 WebSocket의 이름이 제공되지 않았습니다.'
    certificateExpiredExceptionMessage                                = "인증서 '{0}'이(가) 만료되었습니다: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = '시크릿 금고의 잠금 해제 만료 날짜가 과거입니다 (UTC): {0}'
    invalidWebExceptionTypeExceptionMessage                           = '예외가 잘못된 유형입니다. WebException 또는 HttpRequestException이어야 하지만, 얻은 것은: {0}'
    invalidSecretValueTypeExceptionMessage                            = '비밀 값이 잘못된 유형입니다. 예상되는 유형: String, SecureString, HashTable, Byte[] 또는 PSCredential. 그러나 얻은 것은: {0}'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = '명시적 TLS 모드는 SMTPS 및 TCPS 엔드포인트에서만 지원됩니다.'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "매개변수 'DiscriminatorMapping'은 'DiscriminatorProperty'가 있을 때만 사용할 수 있습니다."
    scriptErrorExceptionMessage                                       = "스크립트 {1} {2} (라인 {3}) 문자 {4}에서 {5}을(를) 실행하는 중에 스크립트 {0} 오류가 발생했습니다. 개체 '{7}' 클래스: {8} 기본 클래스: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = '분기별 간격 값을 제공할 수 없습니다.'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[스케줄] {0}: 종료 시간 값은 미래에 있어야 합니다.'
    invalidJwtSignatureSuppliedExceptionMessage                       = '제공된 JWT 서명이 유효하지 않습니다.'
    noSetScriptBlockForVaultExceptionMessage                          = "금고 '{0}'에서 비밀을 업데이트/생성하기 위한 Set ScriptBlock이 제공되지 않았습니다."
    accessMethodNotExistForMergingExceptionMessage                    = '병합을 위한 액세스 방법이 존재하지 않습니다: {0}'
    defaultAuthNotInListExceptionMessage                              = "기본 인증 '{0}'이(가) 제공된 인증 목록에 없습니다."
    parameterHasNoNameExceptionMessage                                = "매개변수에 이름이 없습니다. 'Name' 매개변수를 사용하여 이 구성 요소에 이름을 지정하십시오."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: {2}에 대해 이미 정의되었습니다.'
    fileWatcherAlreadyDefinedExceptionMessage                         = "'{0}'라는 이름의 파일 감시자가 이미 정의되었습니다."
    noServiceHandlersDefinedExceptionMessage                          = '정의된 서비스 핸들러가 없습니다.'
    secretRequiredForCustomSessionStorageExceptionMessage             = '사용자 정의 세션 저장소를 사용할 때는 비밀이 필요합니다.'
    secretManagementModuleNotInstalledExceptionMessage                = 'Microsoft.PowerShell.SecretManagement 모듈이 설치되지 않았습니다.'
    noPathSuppliedForRouteExceptionMessage                            = '경로에 대해 제공된 경로가 없습니다.'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "'anyof'을 포함하는 스키마의 유효성 검사는 지원되지 않습니다."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'IIS 인증 지원은 Windows 전용입니다.'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'OAuth2 InnerScheme은 Basic 또는 Form 인증 중 하나여야 합니다, 그러나 받은 값: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = '{0} 페이지에 대한 경로가 제공되지 않았습니다.'
    cacheStorageNotFoundForExistsExceptionMessage                     = "캐시된 항목 '{1}'이(가) 존재하는지 확인하려고 할 때 이름이 '{0}'인 캐시 스토리지를 찾을 수 없습니다."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: 핸들러가 이미 정의되었습니다.'
    sessionsNotConfiguredExceptionMessage                             = '세션이 구성되지 않았습니다.'
    propertiesTypeObjectAssociationExceptionMessage                   = 'Object 유형의 속성만 {0}와(과) 연결될 수 있습니다.'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = '세션 지속 인증을 사용하려면 세션이 필요합니다.'
    invalidPathWildcardOrDirectoryExceptionMessage                    = '제공된 경로는 와일드카드 또는 디렉터리가 될 수 없습니다: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = '액세스 방법이 이미 정의되었습니다: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "매개변수 'Value' 또는 'ExternalValue'는 필수입니다."
    maximumConcurrentTasksInvalidExceptionMessage                     = '최대 동시 작업 수는 >=1이어야 하지만 받은 값: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = '유형이 정의되지 않았기 때문에 속성을 생성할 수 없습니다.'
    authMethodNotExistForMergingExceptionMessage                      = '병합을 위한 인증 방법이 존재하지 않습니다: {0}'
    maxValueInvalidExceptionMessage                                   = "{1}의 최대 값 '{0}'이(가) 유효하지 않습니다. {2} 이하여야 합니다."
    endpointAlreadyDefinedExceptionMessage                            = "이름이 '{0}'인 엔드포인트가 이미 정의되어 있습니다."
    eventAlreadyRegisteredExceptionMessage                            = '{0} 이벤트가 이미 등록되었습니다: {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "요청에 '{0}'라는 이름의 매개변수가 제공되지 않았거나 데이터가 없습니다."
    cacheStorageNotFoundForSetExceptionMessage                        = "캐시된 항목 '{1}'을(를) 설정하려고 할 때 이름이 '{0}'인 캐시 스토리지를 찾을 수 없습니다."
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: 이미 정의되었습니다.'
    errorLoggingAlreadyEnabledExceptionMessage                        = '오류 로깅이 이미 활성화되었습니다.'
    valueForUsingVariableNotFoundExceptionMessage                     = "'`$using:{0}'에 대한 값을 찾을 수 없습니다."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = '문서 도구 RapidPdf는 OpenAPI 3.1을 지원하지 않습니다.'
    oauth2ClientSecretRequiredExceptionMessage                        = 'PKCE를 사용하지 않을 때 OAuth2에는 클라이언트 비밀이 필요합니다.'
    invalidBase64JwtExceptionMessage                                  = 'JWT에서 잘못된 Base64 인코딩 값이 발견되었습니다.'
    noSessionToCalculateDataHashExceptionMessage                      = '데이터 해시를 계산할 세션이 없습니다.'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "캐시된 항목 '{1}'을(를) 제거하려고 할 때 이름이 '{0}'인 캐시 스토리지를 찾을 수 없습니다."
    csrfMiddlewareNotInitializedExceptionMessage                      = 'CSRF 미들웨어가 초기화되지 않았습니다.'
    infoTitleMandatoryMessage                                         = 'info.title은 필수 항목입니다.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = '유형 {0}는 객체와만 연관될 수 있습니다.'
    userFileDoesNotExistExceptionMessage                              = '사용자 파일이 존재하지 않습니다: {0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = '경로 매개변수에는 유효하고 비어 있지 않은 ScriptBlock이 필요합니다.'
    nextTriggerCalculationErrorExceptionMessage                       = '다음 트리거 날짜 및 시간을 계산하는 중에 문제가 발생한 것 같습니다: {0}'
    cannotLockValueTypeExceptionMessage                               = '[ValueType]를 잠글 수 없습니다.'
    failedToCreateOpenSslCertExceptionMessage                         = 'OpenSSL 인증서 생성 실패: {0}'
    jwtExpiredExceptionMessage                                        = 'JWT가 만료되었습니다.'
    openingGuiMessage                                                 = 'GUI 열기.'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = '다중 유형 속성은 OpenApi 버전 3.1 이상이 필요합니다.'
    noNameForWebSocketRemoveExceptionMessage                          = '제거할 WebSocket의 이름이 제공되지 않았습니다.'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize는 0 이상이어야 하지만, 받은 값: {0}'
    iisShutdownMessage                                                = '(IIS 종료)'
    cannotUnlockValueTypeExceptionMessage                             = '[ValueType]를 잠금 해제할 수 없습니다.'
    noJwtSignatureForAlgorithmExceptionMessage                        = '{0}에 대한 JWT 서명이 제공되지 않았습니다.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = '최대 동시 WebSocket 스레드는 >=1이어야 하지만 받은 값: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = '확인 메시지는 SMTP 및 TCP 엔드포인트에서만 지원됩니다.'
    failedToConnectToUrlExceptionMessage                              = 'URL에 연결하지 못했습니다: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = '뮤텍스 소유권을 획득하지 못했습니다. 뮤텍스 이름: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'PKCE를 사용하는 OAuth2에는 세션이 필요합니다.'
    failedToConnectToWebSocketExceptionMessage                        = 'WebSocket에 연결하지 못했습니다: {0}'
    unsupportedObjectExceptionMessage                                 = '지원되지 않는 개체'
    failedToParseAddressExceptionMessage                              = "'{0}'을(를) 유효한 IP/호스트:포트 주소로 구문 분석하지 못했습니다."
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = '관리자 권한으로 실행되어야 비로소 로컬호스트 주소가 아닌 주소를 청취할 수 있습니다.'
    specificationMessage                                              = '사양'
    cacheStorageNotFoundForClearExceptionMessage                      = "캐시를 지우려고 할 때 이름이 '{0}'인 캐시 스토리지를 찾을 수 없습니다."
    restartingServerMessage                                           = '서버를 재시작 중...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "매개변수 'Every'가 None으로 설정된 경우 간격을 제공할 수 없습니다."
    unsupportedJwtAlgorithmExceptionMessage                           = 'JWT 알고리즘은 현재 지원되지 않습니다: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'WebSockets가 신호 메시지를 보내도록 구성되지 않았습니다.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = '제공된 Hashtable 미들웨어에 잘못된 논리 유형이 있습니다. 예상된 유형은 ScriptBlock이지만, 얻은 것은: {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = '최대 동시 스케줄 수는 최소 {0}보다 작을 수 없지만 받은 값: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = '세마포어 소유권을 획득하지 못했습니다. 세마포어 이름: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = '속성에 이름이 없으면 Properties 매개변수를 사용할 수 없습니다.'
    customSessionStorageMethodNotImplementedExceptionMessage          = "사용자 정의 세션 저장소가 필요한 메서드 '{0}()'를 구현하지 않았습니다."
    authenticationMethodDoesNotExistExceptionMessage                  = '인증 방법이 존재하지 않습니다: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'Webhooks 기능은 OpenAPI v3.0.x에서 지원되지 않습니다.'
    invalidContentTypeForSchemaExceptionMessage                       = "스키마에 대해 잘못된 'content-type'이 발견되었습니다: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "금고 '{0}'을(를) 해제하는 Unlock ScriptBlock이 제공되지 않았습니다."
    definitionTagMessage                                              = '정의 {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'RunspacePool을 여는 데 실패했습니다: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'RunspacePool을(를) 닫지 못했습니다: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[동사] {0}: 전달된 로직 없음'
    noMutexFoundExceptionMessage                                      = "이름이 '{0}'인 뮤텍스를 찾을 수 없습니다."
    documentationMessage                                              = '문서'
    timerAlreadyDefinedExceptionMessage                               = '[타이머] {0}: 타이머가 이미 정의되어 있습니다.'
    invalidPortExceptionMessage                                       = '포트는 음수일 수 없습니다: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = '뷰 폴더 이름이 이미 존재합니다: {0}'
    noNameForWebSocketResetExceptionMessage                           = '재설정할 WebSocket의 이름이 제공되지 않았습니다.'
    mergeDefaultAuthNotInListExceptionMessage                         = "병합 기본 인증 '{0}'이(가) 제공된 인증 목록에 없습니다."
    descriptionRequiredExceptionMessage                               = '경로:{0} 응답:{1} 에 대한 설명이 필요합니다'
    pageNameShouldBeAlphaNumericExceptionMessage                      = '페이지 이름은 유효한 알파벳 숫자 값이어야 합니다: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = '기본값이 boolean이 아니며 enum에 속하지 않습니다.'
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'OpenApi 구성 요소 스키마 {0}이(가) 존재하지 않습니다.'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[타이머] {0}: {1}은(는) 0보다 커야 합니다.'
    taskTimedOutExceptionMessage                                      = '작업이 {0}ms 후에 시간 초과되었습니다.'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[스케줄] {0}: 'StartTime'이 'EndTime' 이후일 수 없습니다."
    infoVersionMandatoryMessage                                       = 'info.version은 필수 항목입니다.'
    cannotUnlockNullObjectExceptionMessage                            = 'null 개체를 잠금 해제할 수 없습니다.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = '사용자 정의 인증 스킴에는 비어 있지 않은 ScriptBlock이 필요합니다.'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = '인증 방법에 대해 비어 있지 않은 ScriptBlock이 필요합니다.'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "'oneof'을 포함하는 스키마의 유효성 검사는 지원되지 않습니다."
    routeParameterCannotBeNullExceptionMessage                        = "'Route' 매개변수는 null일 수 없습니다."
    cacheStorageAlreadyExistsExceptionMessage                         = "이름이 '{0}'인 캐시 스토리지가 이미 존재합니다."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "'{0}' 로깅 방법에 대한 제공된 출력 방법은 유효한 ScriptBlock이 필요합니다."
    scopedVariableAlreadyDefinedExceptionMessage                      = '범위 지정 변수가 이미 정의되었습니다: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = 'OAuth2에는 권한 부여 URL이 필요합니다.'
    pathNotExistExceptionMessage                                      = '경로가 존재하지 않습니다: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = 'Windows AD 인증을 위한 도메인 서버 이름이 제공되지 않았습니다.'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = '제공된 날짜가 스케줄 종료 시간 {0} 이후입니다.'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = '메서드에 대한 * 와일드카드는 AutoMethods 스위치와 호환되지 않습니다.'
    cannotSupplyIntervalForYearExceptionMessage                       = '매년 간격 값을 제공할 수 없습니다.'
    missingComponentsMessage                                          = '누락된 구성 요소'
    invalidStrictTransportSecurityDurationExceptionMessage            = '잘못된 Strict-Transport-Security 기간이 제공되었습니다: {0}. 0보다 커야 합니다.'
    noSecretForHmac512ExceptionMessage                                = 'HMAC512 해시를 위한 비밀이 제공되지 않았습니다.'
    daysInMonthExceededExceptionMessage                               = '{0}에는 {1}일밖에 없지만 {2}일이 제공되었습니다.'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = '사용자 정의 로깅 출력 방법에는 비어 있지 않은 ScriptBlock이 필요합니다.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = '인코딩 속성은 multipart 및 application/x-www-form-urlencoded 요청 본문에만 적용됩니다.'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = '제공된 날짜가 스케줄 시작 시간 {0} 이전입니다.'
    unlockSecretRequiredExceptionMessage                              = "Microsoft.PowerShell.SecretStore를 사용할 때 'UnlockSecret' 속성이 필요합니다."
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: 논리가 전달되지 않았습니다.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = '{0} 콘텐츠 유형에 대한 바디 파서가 이미 정의되어 있습니다.'
    invalidJwtSuppliedExceptionMessage                                = '제공된 JWT가 유효하지 않습니다.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = '플래시 메시지를 사용하려면 세션이 필요합니다.'
    semaphoreAlreadyExistsExceptionMessage                            = "이름이 '{0}'인 세마포어가 이미 존재합니다."
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = '제공된 JWT 헤더 알고리즘이 유효하지 않습니다.'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "OAuth2 공급자는 InnerScheme을 사용하는 데 필요한 'password' 부여 유형을 지원하지 않습니다."
    invalidAliasFoundExceptionMessage                                 = '잘못된 {0} 별칭이 발견되었습니다: {1}'
    scheduleDoesNotExistExceptionMessage                              = "스케줄 '{0}'이(가) 존재하지 않습니다."
    accessMethodNotExistExceptionMessage                              = '액세스 방법이 존재하지 않습니다: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "OAuth2 공급자는 'code' 응답 유형을 지원하지 않습니다."
    untestedPowerShellVersionWarningMessage                           = '[경고] Pode {0}은 출시 당시 사용 가능하지 않았기 때문에 PowerShell {1}에서 테스트되지 않았습니다.'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "이름이 '{0}'인 비밀 금고가 이미 자동으로 가져오는 동안 등록되었습니다."
    schemeRequiresValidScriptBlockExceptionMessage                    = "'{0}' 인증 검증기에 제공된 스킴에는 유효한 ScriptBlock이 필요합니다."
    serverLoopingMessage                                              = '서버 루핑 간격 {0}초'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = '인증서 지문/이름은 Windows에서만 지원됩니다.'
    sseConnectionNameRequiredExceptionMessage                         = "-Name 또는 `$WebEvent.Sse.Name에서 SSE 연결 이름이 필요합니다."
    invalidMiddlewareTypeExceptionMessage                             = '제공된 미들웨어 중 하나가 잘못된 유형입니다. 예상된 유형은 ScriptBlock 또는 Hashtable이지만, 얻은 것은: {0}'
    noSecretForJwtSignatureExceptionMessage                           = 'JWT 서명을 위한 비밀이 제공되지 않았습니다.'
    modulePathDoesNotExistExceptionMessage                            = '모듈 경로가 존재하지 않습니다: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[작업] {0}: 작업이 이미 정의되었습니다.'
    verbAlreadyDefinedExceptionMessage                                = '[동사] {0}: 이미 정의되었습니다.'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = '클라이언트 인증서는 HTTPS 엔드포인트에서만 지원됩니다.'
    endpointNameNotExistExceptionMessage                              = "이름이 '{0}'인 엔드포인트가 존재하지 않습니다."
    middlewareNoLogicSuppliedExceptionMessage                         = '[미들웨어]: ScriptBlock에 로직이 제공되지 않았습니다.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'Valid가 All일 때 여러 인증된 사용자를 하나의 객체로 병합하려면 ScriptBlock이 필요합니다.'
    secretVaultAlreadyRegisteredExceptionMessage                      = "이름이 '{0}'인 시크릿 금고가 이미 등록되었습니다{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "경고: 'Enable-PodeOpenApi'의 제목, 버전 및 설명이 더 이상 사용되지 않습니다. 대신 'Add-PodeOAInfo'를 사용하십시오."
    undefinedOpenApiReferencesMessage                                 = '정의되지 않은 OpenAPI 참조:'
    doneMessage                                                       = '완료'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = '이 버전의 Swagger-Editor는 OpenAPI 3.1을 지원하지 않습니다.'
    durationMustBeZeroOrGreaterExceptionMessage                       = '기간은 0 이상이어야 하지만 받은 값: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = '뷰 경로가 존재하지 않습니다: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "매개변수 'Discriminator'는 'allOf'와 호환되지 않습니다."
    noNameForWebSocketSendMessageExceptionMessage                     = '메시지를 보낼 WebSocket의 이름이 제공되지 않았습니다.'
    hashtableMiddlewareNoLogicExceptionMessage                        = '제공된 Hashtable 미들웨어에는 정의된 논리가 없습니다.'
    openApiInfoMessage                                                = 'OpenAPI 정보:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "'{1}' 인증 검증기에 제공된 '{0}' 스킴에는 유효한 ScriptBlock이 필요합니다."
    sseFailedToBroadcastExceptionMessage                              = '{0}에 대해 정의된 SSE 브로드캐스트 수준으로 인해 SSE 브로드캐스트에 실패했습니다: {1}'
    adModuleWindowsOnlyExceptionMessage                               = 'Active Directory 모듈은 Windows에서만 사용할 수 있습니다.'
    requestLoggingAlreadyEnabledExceptionMessage                      = '요청 로깅이 이미 활성화되었습니다.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = '잘못된 Access-Control-Max-Age 기간이 제공되었습니다: {0}. 0보다 커야 합니다.'
    openApiDefinitionAlreadyExistsExceptionMessage                    = '이름이 {0}인 OpenAPI 정의가 이미 존재합니다.'
    renamePodeOADefinitionTagExceptionMessage                         = "Rename-PodeOADefinitionTag은 Select-PodeOADefinition 'ScriptBlock' 내에서 사용할 수 없습니다."
    taskProcessDoesNotExistExceptionMessage                           = '작업 프로세스가 존재하지 않습니다: {0}'
    scheduleProcessDoesNotExistExceptionMessage                       = '스케줄 프로세스가 존재하지 않습니다: {0}'
    definitionTagChangeNotAllowedExceptionMessage                     = 'Route에 대한 정의 태그는 변경할 수 없습니다.'
    invalidQueryFormatExceptionMessage                                = '제공된 쿼리의 형식이 잘못되었습니다.'
    asyncIdDoesNotExistExceptionMessage                               = 'Async {0} 존재하지 않습니다.'
    asyncRouteOperationDoesNotExistExceptionMessage                   = 'Id {0}의 비동기 경로 작업이 존재하지 않습니다.'
    scriptContainsDisallowedCommandExceptionMessage                   = "스크립트에 '{0}' 명령을 포함할 수 없습니다."
    invalidQueryElementExceptionMessage                               = '제공된 쿼리가 잘못되었습니다. {0} 는 쿼리에 대한 유효한 요소가 아닙니다.'
    setPodeAsyncProgressExceptionMessage                              = 'Set-PodeAsyncProgress는 비동기 경로 스크립트 블록 내에서만 사용할 수 있습니다.'
    progressLimitLowerThanCurrentExceptionMessage                     = '진행 한도는 현재 진행보다 낮을 수 없습니다.'
    openApiDefinitionsMismatchExceptionMessage                        = '{0} 는 서로 다른 OpenAPI 정의 간에 다릅니다.'
    routeNotMarkedAsAsyncExceptionMessage                             = "경로 '{0}' 이(가) 비동기 경로로 표시되지 않았습니다."
    functionCannotBeInvokedMultipleTimesExceptionMessage              = "함수 '{0}' 를 동일한 경로 '{1}' 에 대해 여러 번 호출할 수 없습니다."
    getRequestBodyNotAllowedExceptionMessage                          = '{0} 작업에는 요청 본문이 있을 수 없습니다.'
    fnDoesNotAcceptArrayAsPipelineInputExceptionMessage               = "함수 '{0}'은(는) 배열을 파이프라인 입력으로 받지 않습니다."
    unsupportedStreamCompressionEncodingExceptionMessage              = '지원되지 않는 스트림 압축 인코딩: {0}'
    LocalEndpointConflictExceptionMessage                             = "'{0}' 와 '{1}' 는 OpenAPI 로컬 엔드포인트로 정의되었지만, API 정의당 하나의 로컬 엔드포인트만 허용됩니다."
}