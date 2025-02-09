@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'スキーマ検証には PowerShell バージョン 6.1.0 以上が必要です。'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = 'カスタムアクセス値のソース化には、パスまたはスクリプトブロックが必要です。'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID: {0} は一意でなければならず、配列に適用できません。'
    endpointNotDefinedForRedirectingExceptionMessage                  = "リダイレクトのために名前 '{0}' のエンドポイントが定義されていません。"
    filesHaveChangedMessage                                           = '次のファイルが変更されました:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'IIS ASPNETCORE_TOKENがありません。'
    minValueGreaterThanMaxExceptionMessage                            = '{0}の最小値は最大値を超えることはできません。'
    noLogicPassedForRouteExceptionMessage                             = 'ルートに対してロジックが渡されませんでした: {0}'
    scriptPathDoesNotExistExceptionMessage                            = 'スクリプトパスが存在しません: {0}'
    mutexAlreadyExistsExceptionMessage                                = '次の名前のミューテックスはすでに存在します: {0}'
    listeningOnEndpointsMessage                                       = '次の {0} エンドポイントでリッスンしています [{1} スレッド]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = 'サーバーレスコンテキストではサポートされていない関数です: {0}'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = '提供されるべきではないJWT署名が予期されました。'
    secretAlreadyMountedExceptionMessage                              = "名前 '{0}' のシークレットは既にマウントされています。"
    failedToAcquireLockExceptionMessage                               = 'オブジェクトのロックを取得できませんでした。'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: 静的ルートに対して提供されたパスがありません。'
    invalidHostnameSuppliedExceptionMessage                           = '無効なホスト名が指定されました: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = '認証方法はすでに定義されています：{0}'
    csrfCookieRequiresSecretExceptionMessage                          = "CSRFのためにクッキーを使用する場合、秘密が必要です。秘密を提供するか、クッキーのグローバル秘密を設定してください - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = 'ページルートを作成するには空でないScriptBlockが必要です。'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "パラメーター'NoProperties'は'Properties'、'MinProperties'、および'MaxProperties'と相互排他的です。"
    incompatiblePodeDllExceptionMessage                               = '既存の互換性のないPode.DLLバージョン{0}がロードされています。バージョン{1}が必要です。新しいPowerShell/pwshセッションを開いて再試行してください。'
    accessMethodDoesNotExistExceptionMessage                          = 'アクセスメソッドが存在しません：{0}。'
    scheduleAlreadyDefinedExceptionMessage                            = '[スケジュール] {0}: スケジュールはすでに定義されています。'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = '{0}の秒数値は0またはそれ以下にすることはできません。'
    pathToLoadNotFoundExceptionMessage                                = '読み込むパス{0}が見つかりません: {1}'
    failedToImportModuleExceptionMessage                              = 'モジュールのインポートに失敗しました: {0}'
    endpointNotExistExceptionMessage                                  = "プロトコル'{0}'、アドレス'{1}'またはローカルアドレス'{2}'のエンドポイントが存在しません。"
    terminatingMessage                                                = '終了中'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = 'ルートに変換するためのコマンドが提供されていません。'
    invalidTaskTypeExceptionMessage                                   = 'タスクタイプが無効です。予期されるタイプ：[System.Threading.Tasks.Task]または[hashtable]'
    alreadyConnectedToWebSocketExceptionMessage                       = "名前 '{0}' の WebSocket に既に接続されています"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'CRLFメッセージ終了チェックはTCPエンドポイントでのみサポートされています。'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema' は 'Enable-PodeOpenApi -EnableSchemaValidation' を使用して有効にする必要があります。"
    adModuleNotInstalledExceptionMessage                              = 'Active Directoryモジュールがインストールされていません。'
    cronExpressionInvalidExceptionMessage                             = 'Cron式は5つの部分で構成される必要があります: {0}'
    noSessionToSetOnResponseExceptionMessage                          = 'レスポンスに設定するセッションがありません。'
    valueOutOfRangeExceptionMessage                                   = "{1}の値'{0}'は無効です。{2}から{3}の間でなければなりません。"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'ログ記録方法は既に定義されています: {0}'
    noSecretForHmac256ExceptionMessage                                = 'HMAC256ハッシュに対する秘密が提供されていません。'
    eolPowerShellWarningMessage                                       = '[警告] Pode {0} は、EOLであるPowerShell {1} でテストされていません。'
    runspacePoolFailedToLoadExceptionMessage                          = '{0} RunspacePoolの読み込みに失敗しました。'
    noEventRegisteredExceptionMessage                                 = '登録された{0}イベントはありません：{1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[スケジュール] {0}: 負の制限を持つことはできません。'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'OpenApi リクエストのスタイルは {1} パラメータに対して {0} であってはなりません。'
    openApiDocumentNotCompliantExceptionMessage                       = 'OpenAPIドキュメントが準拠していません。'
    taskDoesNotExistExceptionMessage                                  = "タスク '{0}' は存在しません。"
    scopedVariableNotFoundExceptionMessage                            = 'スコープ変数が見つかりません: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = 'クッキーを使用しない場合は、CSRFを使用するためにセッションが必要です。'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'ロギングメソッドには空でないScriptBlockが必要です。'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = '資格情報が渡されると、ヘッダーのワイルドカード * はワイルドカードとしてではなく、リテラル文字列として解釈されます。'
    podeNotInitializedExceptionMessage                                = 'Podeが初期化されていません。'
    multipleEndpointsForGuiMessage                                    = '複数のエンドポイントが定義されていますが、GUIには最初のエンドポイントのみが使用されます。'
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID: {0} は一意でなければなりません。'
    invalidJsonJwtExceptionMessage                                    = 'JWTに無効なJSON値が見つかりました。'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'JWTヘッダーにアルゴリズムが提供されていません。'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'OpenApiバージョンプロパティは必須です。'
    limitValueCannotBeZeroOrLessExceptionMessage                      = '{0}の制限値は0またはそれ以下にすることはできません。'
    timerDoesNotExistExceptionMessage                                 = "タイマー '{0}' は存在しません。"
    openApiGenerationDocumentErrorMessage                             = 'OpenAPI生成ドキュメントエラー:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "ルート '[{0}] {1}' はすでに名前 '{2}' のカスタムアクセスを含んでいます"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = '最大同時 WebSocket スレッド数は最小値 {0} より小さくてはいけませんが、取得した値は: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: ミドルウェアは既に定義されています。'
    invalidAtomCharacterExceptionMessage                              = '無効なアトム文字: {0}'
    invalidCronAtomFormatExceptionMessage                             = '無効な cron アトム形式が見つかりました: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "キャッシュされたアイテム '{1}' を取得しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。"
    headerMustHaveNameInEncodingContextExceptionMessage               = 'エンコーディングコンテキストで使用される場合、ヘッダーには名前が必要です。'
    moduleDoesNotContainFunctionExceptionMessage                      = 'モジュール {0} にはルートに変換する関数 {1} が含まれていません。'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'GUI用アイコンのパスが存在しません: {0}'
    noTitleSuppliedForPageExceptionMessage                            = '{0} ページのタイトルが提供されていません。'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'HTTPS/WSS以外のエンドポイントに提供された証明書。'
    cannotLockNullObjectExceptionMessage                              = 'nullオブジェクトをロックできません。'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGuiは現在、Windows PowerShellおよびWindows上のPowerShell 7+でのみ利用可能です。'
    unlockSecretButNoScriptBlockExceptionMessage                      = 'カスタムシークレットボールトタイプに対してアンロックシークレットが提供されましたが、アンロックスクリプトブロックが提供されていません。'
    invalidIpAddressExceptionMessage                                  = '提供されたIPアドレスは無効です: {0}'
    maxDaysInvalidExceptionMessage                                    = 'MaxDaysは0以上でなければなりませんが、受け取った値は: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "ボールト'{0}'のシークレットを削除するためのスクリプトブロックが提供されていません。"
    noSecretExpectedForNoSignatureExceptionMessage                    = '署名なしのための秘密が提供されることを期待していませんでした。'
    noCertificateFoundExceptionMessage                                = "'{2}'用の{0}{1}に証明書が見つかりませんでした。"
    minValueInvalidExceptionMessage                                   = "{1}の最小値'{0}'は無効です。{2}以上でなければなりません。"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = 'アクセスにはルート上の認証が必要です。'
    noSecretForHmac384ExceptionMessage                                = 'HMAC384ハッシュに対する秘密が提供されていません。'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'Windowsローカル認証のサポートはWindowsのみです。'
    definitionTagNotDefinedExceptionMessage                           = '定義タグ {0} が定義されていません。'
    noComponentInDefinitionExceptionMessage                           = '{2}定義に{0}タイプの名前{1}コンポーネントが利用できません。'
    noSmtpHandlersDefinedExceptionMessage                             = 'SMTPハンドラが定義されていません。'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'セッションミドルウェアは既に初期化されています。'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "OpenAPI v3.0では再利用可能なコンポーネント機能'pathItems'は使用できません。"
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = 'ヘッダーのワイルドカード * は AutoHeaders スイッチと互換性がありません。'
    noDataForFileUploadedExceptionMessage                             = "リクエストでアップロードされたファイル '{0}' のデータがありません。"
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSEはAcceptヘッダー値がtext/event-streamのリクエストでのみ構成できます。'
    noSessionAvailableToSaveExceptionMessage                          = '保存するためのセッションが利用できません。'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "パラメータの場所が 'Path' の場合、スイッチパラメータ 'Required' は必須です。"
    noOpenApiUrlSuppliedExceptionMessage                              = '{0} 用の OpenAPI URL が提供されていません。'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = '最大同時スケジュール数は 1 以上でなければなりませんが、受け取った値: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'SnapinsはWindows PowerShellのみでサポートされています。'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = 'イベントビューアーロギングはWindowsでのみサポートされています。'
    parametersMutuallyExclusiveExceptionMessage                       = "パラメータ '{0}' と '{1}' は互いに排他的です。"
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = 'PathItems機能はOpenAPI v3.0.xではサポートされていません。'
    openApiParameterRequiresNameExceptionMessage                      = 'OpenApi パラメータには名前が必要です。'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = '最大同時タスク数は最小値 {0} より少なくてはいけませんが、取得した値は: {1}'
    noSemaphoreFoundExceptionMessage                                  = "名前 '{0}' のセマフォが見つかりません"
    singleValueForIntervalExceptionMessage                            = 'インターバルを使用する場合、単一の{0}値しか指定できません。'
    jwtNotYetValidExceptionMessage                                    = 'JWTはまだ有効ではありません。'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[動詞] {0}: {1}にすでに定義されています'
    noSecretNamedMountedExceptionMessage                              = "名前 '{0}' のシークレットはマウントされていません。"
    moduleOrVersionNotFoundExceptionMessage                           = '{0}でモジュールまたはバージョンが見つかりません: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'ScriptBlockが提供されていません。'
    noSecretVaultRegisteredExceptionMessage                           = "名前 '{0}' のシークレットボールトは登録されていません。"
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'RedirectToパラメーターが提供されている場合、エンドポイントには名前が必要です。'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "OpenAPI オブジェクト 'license' には 'name' プロパティが必要です。-LicenseName パラメータを使用してください。"
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: 静的ルートに対して提供されたソースパスが存在しません: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = '切断する WebSocket の名前が指定されていません。'
    certificateExpiredExceptionMessage                                = "証明書 '{0}' の有効期限が切れています: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = 'シークレットボールトのアンロック有効期限が過去に設定されています (UTC) :{0}'
    invalidWebExceptionTypeExceptionMessage                           = '例外が無効な型です。WebExceptionまたはHttpRequestExceptionのいずれかである必要がありますが、次の型を取得しました: {0}'
    invalidSecretValueTypeExceptionMessage                            = 'シークレットの値が無効な型です。期待される型: String、SecureString、HashTable、Byte[]、またはPSCredential。しかし、次を取得しました: {0}'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = '明示的なTLSモードはSMTPSおよびTCPSエンドポイントでのみサポートされています。'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "パラメーター'DiscriminatorMapping'は'DiscriminatorProperty'が存在する場合にのみ使用できます。"
    scriptErrorExceptionMessage                                       = "スクリプト{1} {2}（行{3}）のエラー'{0}'（文字{4}）が{6}オブジェクト'{7}'の{5}を実行中に発生しました クラス: {8} 基底クラス: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = '四半期ごとの間隔値を提供できません。'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[スケジュール] {0}: EndTime 値は未来に設定する必要があります。'
    invalidJwtSignatureSuppliedExceptionMessage                       = '無効なJWT署名が提供されました。'
    noSetScriptBlockForVaultExceptionMessage                          = "ボールト'{0}'のシークレットを更新/作成するためのスクリプトブロックが提供されていません。"
    accessMethodNotExistForMergingExceptionMessage                    = 'マージするアクセス方法が存在しません: {0}'
    defaultAuthNotInListExceptionMessage                              = "デフォルト認証'{0}'は提供された認証リストにありません。"
    parameterHasNoNameExceptionMessage                                = "パラメーターに名前がありません。このコンポーネントに'Name'パラメーターを使用して名前を付けてください。"
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: {2}用に既に定義されています。'
    fileWatcherAlreadyDefinedExceptionMessage                         = "名前 '{0}' のファイルウォッチャーは既に定義されています。"
    noServiceHandlersDefinedExceptionMessage                          = 'サービスハンドラが定義されていません。'
    secretRequiredForCustomSessionStorageExceptionMessage             = 'カスタムセッションストレージを使用する場合、シークレットが必要です。'
    secretManagementModuleNotInstalledExceptionMessage                = 'Microsoft.PowerShell.SecretManagementモジュールがインストールされていません。'
    noPathSuppliedForRouteExceptionMessage                            = 'ルートのパスが提供されていません。'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "'anyof'を含むスキーマの検証はサポートされていません。"
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'IIS認証のサポートはWindowsのみです。'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'OAuth2 InnerSchemeはBasicまたはFormのいずれかでなければなりませんが、取得したのは: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = '{0} ページのルートパスが提供されていません。'
    cacheStorageNotFoundForExistsExceptionMessage                     = "キャッシュされたアイテム '{1}' が存在するかどうかを確認しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。"
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: ハンドラは既に定義されています。'
    sessionsNotConfiguredExceptionMessage                             = 'セッションが構成されていません。'
    propertiesTypeObjectAssociationExceptionMessage                   = 'Object 型のプロパティのみが {0} と関連付けられます。'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = 'セッション持続認証を使用するにはセッションが必要です。'
    invalidPathWildcardOrDirectoryExceptionMessage                    = '指定されたパスはワイルドカードまたはディレクトリにすることはできません: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = 'アクセス方法はすでに定義されています: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "パラメータ 'Value' または 'ExternalValue' は必須です。"
    maximumConcurrentTasksInvalidExceptionMessage                     = '最大同時タスク数は >=1 でなければなりませんが、取得した値は: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = '型が定義されていないため、プロパティを作成できません。'
    authMethodNotExistForMergingExceptionMessage                      = 'マージするための認証方法は存在しません：{0}'
    maxValueInvalidExceptionMessage                                   = "{1}の最大値'{0}'は無効です。{2}以下でなければなりません。"
    endpointAlreadyDefinedExceptionMessage                            = "名前 '{0}' のエンドポイントは既に定義されています。"
    eventAlreadyRegisteredExceptionMessage                            = '{0}イベントはすでに登録されています：{1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "リクエストに '{0}' という名前のパラメータが提供されていないか、データがありません。"
    cacheStorageNotFoundForSetExceptionMessage                        = "キャッシュされたアイテム '{1}' を設定しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。"
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: 既に定義されています。'
    valueForUsingVariableNotFoundExceptionMessage                     = "'`$using:{0}'の値が見つかりませんでした。"
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = 'ドキュメントツール RapidPdf は OpenAPI 3.1 をサポートしていません'
    oauth2ClientSecretRequiredExceptionMessage                        = 'PKCEを使用しない場合、OAuth2にはクライアントシークレットが必要です。'
    invalidBase64JwtExceptionMessage                                  = 'JWTに無効なBase64エンコード値が見つかりました。'
    noSessionToCalculateDataHashExceptionMessage                      = 'データハッシュを計算するセッションがありません。'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "キャッシュされたアイテム '{1}' を削除しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。"
    csrfMiddlewareNotInitializedExceptionMessage                      = 'CSRFミドルウェアが初期化されていません。'
    infoTitleMandatoryMessage                                         = 'info.title は必須です。'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = 'タイプ{0}はオブジェクトにのみ関連付けることができます。'
    userFileDoesNotExistExceptionMessage                              = 'ユーザーファイルが存在しません：{0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = 'ルートパラメーターには有効で空でないScriptBlockが必要です。'
    nextTriggerCalculationErrorExceptionMessage                       = '次のトリガー日時の計算中に問題が発生したようです: {0}'
    cannotLockValueTypeExceptionMessage                               = '[ValueType]をロックできません。'
    failedToCreateOpenSslCertExceptionMessage                         = 'OpenSSL証明書の作成に失敗しました: {0}'
    jwtExpiredExceptionMessage                                        = 'JWTの有効期限が切れています。'
    openingGuiMessage                                                 = 'GUIを開いています。'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = '複数タイプのプロパティはOpenApiバージョン3.1以上が必要です。'
    noNameForWebSocketRemoveExceptionMessage                          = '削除する WebSocket の名前が指定されていません。'
    maxSizeInvalidExceptionMessage                                    = 'MaxSizeは0以上でなければなりませんが、受け取った値は: {0}'
    iisShutdownMessage                                                = '(IIS シャットダウン)'
    cannotUnlockValueTypeExceptionMessage                             = '[ValueType]のロックを解除できません。'
    noJwtSignatureForAlgorithmExceptionMessage                        = '{0}のためのJWT署名が提供されていません。'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = '最大同時 WebSocket スレッド数は >=1 でなければなりませんが、取得した値は: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = '確認メッセージはSMTPおよびTCPエンドポイントでのみサポートされています。'
    failedToConnectToUrlExceptionMessage                              = 'URLへの接続に失敗しました: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = 'ミューテックスの所有権を取得できませんでした。ミューテックス名: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'PKCEを使用するOAuth2にはセッションが必要です。'
    failedToConnectToWebSocketExceptionMessage                        = 'WebSocket への接続に失敗しました: {0}'
    unsupportedObjectExceptionMessage                                 = 'サポートされていないオブジェクトです。'
    failedToParseAddressExceptionMessage                              = "'{0}'を有効なIP/ホスト:ポートアドレスとして解析できませんでした。"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'ローカルホスト以外のアドレスでリッスンするには管理者権限で実行する必要があります。'
    specificationMessage                                              = '仕様'
    cacheStorageNotFoundForClearExceptionMessage                      = "キャッシュをクリアしようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。"
    restartingServerMessage                                           = 'サーバーを再起動しています...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "パラメーター'Every'がNoneに設定されている場合、間隔を提供できません。"
    unsupportedJwtAlgorithmExceptionMessage                           = '現在サポートされていないJWTアルゴリズムです: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'WebSocketsはシグナルメッセージを送信するように構成されていません。'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = '提供されたHashtableミドルウェアに無効なロジック型があります。ScriptBlockを期待しましたが、次を取得しました: {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = '最大同時スケジュール数は最小 {0} 未満にすることはできませんが、受け取った値: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = 'セマフォの所有権を取得できませんでした。セマフォ名: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = 'プロパティに名前がない場合、プロパティパラメータは使用できません。'
    customSessionStorageMethodNotImplementedExceptionMessage          = "カスタムセッションストレージは必要なメソッド'{0}()'を実装していません。"
    authenticationMethodDoesNotExistExceptionMessage                  = '認証方法が存在しません: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'Webhooks機能はOpenAPI v3.0.xではサポートされていません。'
    invalidContentTypeForSchemaExceptionMessage                       = "スキーマの 'content-type' が無効です: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "ボールト'{0}'のロック解除に必要なスクリプトブロックが提供されていません。"
    definitionTagMessage                                              = '定義 {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'RunspacePoolのオープンに失敗しました: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'RunspacePoolのクローズに失敗しました: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[動詞] {0}: ロジックが渡されていません'
    noMutexFoundExceptionMessage                                      = "名前 '{0}' のミューテックスが見つかりません"
    documentationMessage                                              = 'ドキュメント'
    timerAlreadyDefinedExceptionMessage                               = '[タイマー] {0}: タイマーはすでに定義されています。'
    invalidPortExceptionMessage                                       = 'ポートは負であってはなりません: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = 'ビューのフォルダ名は既に存在します: {0}'
    noNameForWebSocketResetExceptionMessage                           = 'リセットする WebSocket の名前が指定されていません。'
    mergeDefaultAuthNotInListExceptionMessage                         = "MergeDefault認証'{0}'は提供された認証リストにありません。"
    descriptionRequiredExceptionMessage                               = 'パス:{0} 応答:{1} に説明が必要です'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'ページ名は有効な英数字である必要があります: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = 'デフォルト値は boolean ではなく、enum に含まれていません。'
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'OpenApi コンポーネントスキーマ {0} は存在しません。'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[タイマー] {0}: {1} は 0 より大きくなければなりません。'
    taskTimedOutExceptionMessage                                      = 'タスクが{0}ミリ秒後にタイムアウトしました。'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[スケジュール] {0}: 'StartTime' が 'EndTime' の後であることはできません"
    infoVersionMandatoryMessage                                       = 'info.version は必須です。'
    cannotUnlockNullObjectExceptionMessage                            = 'nullオブジェクトのロックを解除できません。'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = 'カスタム認証スキームには空でないScriptBlockが必要です。'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = '認証方法には空でない ScriptBlock が必要です。'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "'oneof'を含むスキーマの検証はサポートされていません。"
    routeParameterCannotBeNullExceptionMessage                        = "パラメータ 'Route' は null ではいけません。"
    cacheStorageAlreadyExistsExceptionMessage                         = "名前 '{0}' のキャッシュストレージは既に存在します。"
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "'{0}' ログ記録方法のために提供された出力方法は、有効なScriptBlockが必要です。"
    scopedVariableAlreadyDefinedExceptionMessage                      = 'スコープ付き変数が既に定義されています: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = 'OAuth2には認可URLの提供が必要です。'
    pathNotExistExceptionMessage                                      = 'パスが存在しません: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = 'Windows AD認証用のドメインサーバー名が提供されていません。'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = '提供された日付はスケジュールの終了時間 {0} の後です'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = 'メソッドのワイルドカード * は AutoMethods スイッチと互換性がありません。'
    cannotSupplyIntervalForYearExceptionMessage                       = '毎年の間隔値を提供できません。'
    missingComponentsMessage                                          = '欠落しているコンポーネント'
    invalidStrictTransportSecurityDurationExceptionMessage            = '無効な Strict-Transport-Security 期間が指定されました: {0}。0 より大きい必要があります。'
    noSecretForHmac512ExceptionMessage                                = 'HMAC512ハッシュに対する秘密が提供されていません。'
    daysInMonthExceededExceptionMessage                               = '{0}は{1}日しかありませんが、{2}が指定されました。'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'カスタムロギング出力メソッドには空でないScriptBlockが必要です。'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = 'エンコーディング属性は、multipart および application/x-www-form-urlencoded リクエストボディにのみ適用されます。'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = '提供された日付はスケジュールの開始時間 {0} より前です'
    unlockSecretRequiredExceptionMessage                              = "Microsoft.PowerShell.SecretStoreを使用する場合、'UnlockSecret'プロパティが必要です。"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: ロジックが渡されませんでした。'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = '{0} コンテンツタイプ用のボディパーサーは既に定義されています。'
    invalidJwtSuppliedExceptionMessage                                = '無効なJWTが提供されました。'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'フラッシュメッセージを使用するにはセッションが必要です。'
    semaphoreAlreadyExistsExceptionMessage                            = '次の名前のセマフォはすでに存在します: {0}'
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = '無効なJWTヘッダーアルゴリズムが提供されました。'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "OAuth2プロバイダーはInnerSchemeを使用するために必要な'password' grant_typeをサポートしていません。"
    invalidAliasFoundExceptionMessage                                 = '無効な{0}エイリアスが見つかりました: {1}'
    scheduleDoesNotExistExceptionMessage                              = "スケジュール '{0}' は存在しません。"
    accessMethodNotExistExceptionMessage                              = 'アクセス方法が存在しません: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "OAuth2プロバイダーは'code' response_typeをサポートしていません。"
    untestedPowerShellVersionWarningMessage                           = '[警告] Pode {0} はリリース時に利用可能でなかったため、PowerShell {1} でテストされていません。'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "シークレットボールト'{0}'は既に登録されています（シークレットボールトの自動インポート中）。"
    schemeRequiresValidScriptBlockExceptionMessage                    = "'{0}'認証バリデーターのために提供されたスキームには有効なScriptBlockが必要です。"
    serverLoopingMessage                                              = 'サーバーループ間隔 {0}秒'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'Certificate Thumbprints/NameはWindowsでのみサポートされています。'
    sseConnectionNameRequiredExceptionMessage                         = "-Nameまたは`$WebEvent.Sse.NameからSSE接続名が必要です。"
    invalidMiddlewareTypeExceptionMessage                             = '提供されたMiddlewaresの1つが無効な型です。ScriptBlockまたはHashtableのいずれかを期待しましたが、次を取得しました: {0}'
    noSecretForJwtSignatureExceptionMessage                           = 'JWT署名に対する秘密が提供されていません。'
    modulePathDoesNotExistExceptionMessage                            = 'モジュールパスが存在しません: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[タスク] {0}: タスクは既に定義されています。'
    verbAlreadyDefinedExceptionMessage                                = '[動詞] {0}: すでに定義されています'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'クライアント証明書はHTTPSエンドポイントでのみサポートされています。'
    endpointNameNotExistExceptionMessage                              = "名前'{0}'のエンドポイントが存在しません。"
    middlewareNoLogicSuppliedExceptionMessage                         = '[ミドルウェア]: ScriptBlockにロジックが提供されていません。'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'ValidがAllの場合、複数の認証済みユーザーを1つのオブジェクトにマージするためのScriptBlockが必要です。'
    secretVaultAlreadyRegisteredExceptionMessage                      = "名前 '{0}' のシークレットボールトは既に登録されています{1}。"
    deprecatedTitleVersionDescriptionWarningMessage                   = "警告: 'Enable-PodeOpenApi' のタイトル、バージョン、および説明は非推奨です。代わりに 'Add-PodeOAInfo' を使用してください。"
    undefinedOpenApiReferencesMessage                                 = '未定義のOpenAPI参照:'
    doneMessage                                                       = '完了'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = 'このバージョンの Swagger-Editor は OpenAPI 3.1 をサポートしていません'
    durationMustBeZeroOrGreaterExceptionMessage                       = '期間は 0 以上でなければなりませんが、取得した値は: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = 'ビューのパスが存在しません: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "パラメーター'Discriminator'は'allOf'と互換性がありません。"
    noNameForWebSocketSendMessageExceptionMessage                     = 'メッセージを送信する WebSocket の名前が指定されていません。'
    hashtableMiddlewareNoLogicExceptionMessage                        = '提供されたHashtableミドルウェアにロジックが定義されていません。'
    openApiInfoMessage                                                = 'OpenAPI情報:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "'{1}'認証バリデーターのために提供された'{0}'スキームには有効なScriptBlockが必要です。"
    sseFailedToBroadcastExceptionMessage                              = '{0}のSSEブロードキャストレベルが定義されているため、SSEのブロードキャストに失敗しました: {1}'
    adModuleWindowsOnlyExceptionMessage                               = 'Active DirectoryモジュールはWindowsでのみ利用可能です。'
    invalidAccessControlMaxAgeDurationExceptionMessage                = '無効な Access-Control-Max-Age 期間が提供されました：{0}。0 より大きくする必要があります。'
    openApiDefinitionAlreadyExistsExceptionMessage                    = '名前が {0} の OpenAPI 定義は既に存在します。'
    renamePodeOADefinitionTagExceptionMessage                         = "Rename-PodeOADefinitionTag は Select-PodeOADefinition 'ScriptBlock' 内で使用できません。"
    loggingAlreadyEnabledExceptionMessage                             = "ログ記録 '{0}' は既に有効になっています。"
    invalidEncodingExceptionMessage                                   = '無効なエンコーディング: {0}'
    syslogProtocolExceptionMessage                                    = 'SyslogプロトコルはRFC3164またはRFC5424のみを使用できます。'
    taskProcessDoesNotExistExceptionMessage                           = 'タスクプロセスが存在しません: {0}'
    scheduleProcessDoesNotExistExceptionMessage                       = 'スケジュールプロセスが存在しません: {0}'
    definitionTagChangeNotAllowedExceptionMessage                     = 'Routeの定義タグは変更できません。'
    getRequestBodyNotAllowedExceptionMessage                          = "'{0}' 操作にはリクエストボディを含めることはできません。-AllowNonStandardBody を使用してこの制限を回避してください。"
    fnDoesNotAcceptArrayAsPipelineInputExceptionMessage               = "関数 '{0}' は配列をパイプライン入力として受け付けません。"
    unsupportedStreamCompressionEncodingExceptionMessage              = 'サポートされていないストリーム圧縮エンコーディングが提供されました: {0}'
    localEndpointConflictExceptionMessage                             = "'{0}' と '{1}' は OpenAPI のローカルエンドポイントとして定義されていますが、API 定義ごとに 1 つのローカルエンドポイントのみ許可されます。"
    deprecatedFunctionWarningMessage                                  = "警告: 関数 '{0}' は廃止され、将来のリリースで削除されます。代わりに '{1}' 関数を使用してください。"
    suspendingMessage                                                 = '停止'
    resumingMessage                                                   = '再開'
    serverControlCommandsTitle                                        = 'サーバーコントロールコマンド:'
    gracefullyTerminateMessage                                        = 'サーバーを正常に終了します。'
    restartServerMessage                                              = 'サーバーを再起動して設定をリロードします。'
    resumeServerMessage                                               = 'サーバーを再開します。'
    suspendServerMessage                                              = 'サーバーを一時停止します。'
    startingMessage                                                   = '開始中'
    restartingMessage                                                 = '再起動中'
    suspendedMessage                                                  = '一時停止中'
    runningMessage                                                    = '実行中'
    openHttpEndpointMessage                                           = 'デフォルトのブラウザで最初の HTTP エンドポイントを開きます。'
    terminatedMessage                                                 = '終了しました'
    showMetricsMessage                                                = 'メトリクスを表示'
    clearConsoleMessage                                               = 'コンソールをクリア'
    serverMetricsMessage                                              = 'サーバーメトリクス'
    totalUptimeMessage                                                = '総稼働時間:'
    uptimeSinceLastRestartMessage                                     = '最後の再起動からの稼働時間:'
    totalRestartMessage                                               = '再起動の総数:'
    defaultEndpointAlreadySetExceptionMessage                         = "タイプ '{0}' のデフォルトエンドポイントは既に設定されています。タイプごとに1つのデフォルトエンドポイントのみ許可されています。"
    enableHttpServerMessage                                           = 'HTTPサーバーを有効化する'
    disableHttpServerMessage                                          = 'HTTPサーバーを無効化する'
    showHelpMessage                                                   = 'ヘルプを表示'
    hideHelpMessage                                                   = 'ヘルプを非表示'
    hideEndpointsMessage                                              = 'エンドポイントを非表示'
    showEndpointsMessage                                              = 'エンドポイントを表示'
    hideOpenAPIMessage                                                = 'OpenAPIを非表示'
    showOpenAPIMessage                                                = 'OpenAPIを表示'
    enableQuietModeMessage                                            = 'クワイエットモードを有効化'
    disableQuietModeMessage                                           = 'クワイエットモードを無効化'
    rateLimitRuleAlreadyExistsExceptionMessage                        = "名前が '{0}' のレート制限ルールは既に存在します。"
    rateLimitRuleDoesNotExistExceptionMessage                         = "名前が '{0}' のレート制限ルールは存在しません。"
    accessLimitRuleAlreadyExistsExceptionMessage                      = "名前が '{0}' のアクセス制限ルールは既に存在します。"
    accessLimitRuleDoesNotExistExceptionMessage                       = "名前が '{0}' のアクセス制限ルールは存在しません。"
}