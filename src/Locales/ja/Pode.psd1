ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyExceptionMessage = Active DirectoryモジュールはWindowsでのみ利用可能です。
adModuleNotInstalledExceptionMessage = Active Directoryモジュールがインストールされていません。
secretManagementModuleNotInstalledExceptionMessage = Microsoft.PowerShell.SecretManagementモジュールがインストールされていません。
secretVaultAlreadyRegisteredAutoImportExceptionMessage = シークレットボールト'{0}'は既に登録されています（シークレットボールトの自動インポート中）。
failedToOpenRunspacePoolExceptionMessage = RunspacePoolのオープンに失敗しました: {0}
cronExpressionInvalidExceptionMessage = Cron式は5つの部分で構成される必要があります: {0}
invalidAliasFoundExceptionMessage = 無効な{0}エイリアスが見つかりました: {1}
invalidAtomCharacterExceptionMessage = 無効なアトム文字: {0}
minValueGreaterThanMaxExceptionMessage = {0}の最小値は最大値を超えることはできません。
minValueInvalidExceptionMessage = {1}の最小値'{0}'は無効です。{2}以上でなければなりません。
maxValueInvalidExceptionMessage = {1}の最大値'{0}'は無効です。{2}以下でなければなりません。
valueOutOfRangeExceptionMessage = {1}の値'{0}'は無効です。{2}から{3}の間でなければなりません。
daysInMonthExceededExceptionMessage = {0}は{1}日しかありませんが、{2}が指定されました。
nextTriggerCalculationErrorExceptionMessage = 次のトリガー日時の計算中に問題が発生したようです: {0}
incompatiblePodeDllExceptionMessage = 既存の互換性のないPode.DLLバージョン{0}がロードされています。バージョン{1}が必要です。新しいPowerShell/pwshセッションを開いて再試行してください。
endpointNotExistExceptionMessage = プロトコル'{0}'、アドレス'{1}'またはローカルアドレス'{2}'のエンドポイントが存在しません。
endpointNameNotExistExceptionMessage = 名前'{0}'のエンドポイントが存在しません。
failedToConnectToUrlExceptionMessage = URLへの接続に失敗しました: {0}
failedToParseAddressExceptionMessage = '{0}'を有効なIP/ホスト:ポートアドレスとして解析できませんでした。
invalidIpAddressExceptionMessage = 提供されたIPアドレスは無効です: {0}
invalidPortExceptionMessage = ポートは負であってはなりません: {0}
pathNotExistExceptionMessage = パスが存在しません: {0}
noSecretForHmac256ExceptionMessage = HMAC256ハッシュに対する秘密が提供されていません。
noSecretForHmac384ExceptionMessage = HMAC384ハッシュに対する秘密が提供されていません。
noSecretForHmac512ExceptionMessage = HMAC512ハッシュに対する秘密が提供されていません。
noSecretForJwtSignatureExceptionMessage = JWT署名に対する秘密が提供されていません。
noSecretExpectedForNoSignatureExceptionMessage = 署名なしのための秘密が提供されることを期待していませんでした。
unsupportedJwtAlgorithmExceptionMessage = 現在サポートされていないJWTアルゴリズムです: {0}
invalidBase64JwtExceptionMessage = JWTに無効なBase64エンコード値が見つかりました。
invalidJsonJwtExceptionMessage = JWTに無効なJSON値が見つかりました。
unsupportedFunctionInServerlessContextExceptionMessage = サーバーレスコンテキストではサポートされていない関数です: {0}
invalidPathWildcardOrDirectoryExceptionMessage = 指定されたパスはワイルドカードまたはディレクトリにすることはできません: {0}
invalidExceptionTypeExceptionMessage = 例外が無効な型です。WebExceptionまたはHttpRequestExceptionのいずれかである必要がありますが、次の型を取得しました: {0}
pathToLoadNotFoundExceptionMessage = 読み込むパス{0}が見つかりません: {1}
singleValueForIntervalExceptionMessage = インターバルを使用する場合、単一の{0}値しか指定できません。
scriptErrorExceptionMessage = スクリプト{1} {2}（行{3}）のエラー'{0}'（文字{4}）が{6}オブジェクト'{7}'の{5}を実行中に発生しました クラス: {8} 基底クラス: {9}
noScriptBlockSuppliedExceptionMessage = ScriptBlockが提供されていません。
iisAspnetcoreTokenMissingExceptionMessage = IIS ASPNETCORE_TOKENがありません。
propertiesParameterWithoutNameExceptionMessage = プロパティに名前がない場合、プロパティパラメータは使用できません。
multiTypePropertiesRequireOpenApi31ExceptionMessage = 複数タイプのプロパティはOpenApiバージョン3.1以上が必要です。
openApiVersionPropertyMandatoryExceptionMessage = OpenApiバージョンプロパティは必須です。
webhooksFeatureNotSupportedInOpenApi30ExceptionMessage = Webhooks機能はOpenAPI v3.0.xではサポートされていません。
authenticationMethodDoesNotExistExceptionMessage = 認証方法が存在しません: {0}
unsupportedObjectExceptionMessage = サポートされていないオブジェクトです。
validationOfAnyOfSchemaNotSupportedExceptionMessage = 'anyof'を含むスキーマの検証はサポートされていません。
validationOfOneOfSchemaNotSupportedExceptionMessage = 'oneof'を含むスキーマの検証はサポートされていません。
cannotCreatePropertyWithoutTypeExceptionMessage = 型が定義されていないため、プロパティを作成できません。
headerMustHaveNameInEncodingContextExceptionMessage = エンコーディングコンテキストで使用される場合、ヘッダーには名前が必要です。
descriptionRequiredExceptionMessage = 説明が必要です。
openApiDocumentNotCompliantExceptionMessage = OpenAPIドキュメントが準拠していません。
noComponentInDefinitionExceptionMessage = {2}定義に{0}タイプの名前{1}コンポーネントが利用できません。
methodPathAlreadyDefinedExceptionMessage = [{0}] {1}: 既に定義されています。
methodPathAlreadyDefinedForUrlExceptionMessage = [{0}] {1}: {2}用に既に定義されています。
invalidMiddlewareTypeExceptionMessage = 提供されたMiddlewaresの1つが無効な型です。ScriptBlockまたはHashtableのいずれかを期待しましたが、次を取得しました: {0}
hashtableMiddlewareNoLogicExceptionMessage = 提供されたHashtableミドルウェアにロジックが定義されていません。
invalidLogicTypeInHashtableMiddlewareExceptionMessage = 提供されたHashtableミドルウェアに無効なロジック型があります。ScriptBlockを期待しましたが、次を取得しました: {0}
scopedVariableAlreadyDefinedExceptionMessage = スコープ付き変数が既に定義されています: {0}
valueForUsingVariableNotFoundExceptionMessage = '$using:{0}'の値が見つかりませんでした。
unlockSecretRequiredExceptionMessage = Microsoft.PowerShell.SecretStoreを使用する場合、'UnlockSecret'プロパティが必要です。
unlockSecretButNoScriptBlockExceptionMessage = カスタムシークレットボールトタイプに対してアンロックシークレットが提供されましたが、アンロックスクリプトブロックが提供されていません。
noUnlockScriptBlockForVaultExceptionMessage = ボールト'{0}'のロック解除に必要なスクリプトブロックが提供されていません。
noSetScriptBlockForVaultExceptionMessage = ボールト'{0}'のシークレットを更新/作成するためのスクリプトブロックが提供されていません。
noRemoveScriptBlockForVaultExceptionMessage = ボールト'{0}'のシークレットを削除するためのスクリプトブロックが提供されていません。
invalidSecretValueTypeExceptionMessage = シークレットの値が無効な型です。期待される型: String、SecureString、HashTable、Byte[]、またはPSCredential。しかし、次を取得しました: {0}
limitValueCannotBeZeroOrLessExceptionMessage = {0}の制限値は0またはそれ以下にすることはできません。
secondsValueCannotBeZeroOrLessExceptionMessage = {0}の秒数値は0またはそれ以下にすることはできません。
failedToCreateOpenSslCertExceptionMessage = OpenSSL証明書の作成に失敗しました: {0}
certificateThumbprintsNameSupportedOnWindowsExceptionMessage = Certificate Thumbprints/NameはWindowsでのみサポートされています。
noCertificateFoundExceptionMessage = '{2}'用の{0}\{1}に証明書が見つかりませんでした。
runspacePoolFailedToLoadExceptionMessage = {0} RunspacePoolの読み込みに失敗しました。
noServiceHandlersDefinedExceptionMessage = サービスハンドラが定義されていません。
noSessionToSetOnResponseExceptionMessage = レスポンスに設定するセッションがありません。
noSessionToCalculateDataHashExceptionMessage = データハッシュを計算するセッションがありません。
moduleOrVersionNotFoundExceptionMessage = {0}でモジュールまたはバージョンが見つかりません: {1}@{2}
noSmtpHandlersDefinedExceptionMessage = SMTPハンドラが定義されていません。
taskTimedOutExceptionMessage = タスクが{0}ミリ秒後にタイムアウトしました。
verbAlreadyDefinedExceptionMessage = [動詞] {0}: すでに定義されています
verbAlreadyDefinedForUrlExceptionMessage = [動詞] {0}: {1}にすでに定義されています
pathOrScriptBlockRequiredExceptionMessage = カスタムアクセス値のソース化には、パスまたはスクリプトブロックが必要です。
accessMethodAlreadyDefinedExceptionMessage = アクセス方法はすでに定義されています: {0}
accessMethodNotExistForMergingExceptionMessage = マージするアクセス方法が存在しません: {0}
routeAlreadyContainsCustomAccessExceptionMessage = ルート '[{0}] {1}' はすでに名前 '{2}' のカスタムアクセスを含んでいます
accessMethodNotExistExceptionMessage = アクセス方法が存在しません: {0}
pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage = PathItems機能はOpenAPI v3.0.xではサポートされていません。
nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage = カスタム認証スキームには空でないScriptBlockが必要です。
oauth2InnerSchemeInvalidExceptionMessage = OAuth2 InnerSchemeはBasicまたはFormのいずれかでなければなりませんが、取得したのは: {0}
sessionsRequiredForOAuth2WithPKCEExceptionMessage = PKCEを使用するOAuth2にはセッションが必要です。
oauth2ClientSecretRequiredExceptionMessage = PKCEを使用しない場合、OAuth2にはクライアントシークレットが必要です。
authMethodAlreadyDefinedExceptionMessage = 認証方法はすでに定義されています：{0}
invalidSchemeForAuthValidatorExceptionMessage = '{1}'認証バリデーターのために提供された'{0}'スキームには有効なScriptBlockが必要です。
sessionsRequiredForSessionPersistentAuthExceptionMessage = セッション持続認証を使用するにはセッションが必要です。
oauth2RequiresAuthorizeUrlExceptionMessage = OAuth2には認可URLの提供が必要です。
authMethodNotExistForMergingExceptionMessage = マージするための認証方法は存在しません：{0}
mergeDefaultAuthNotInListExceptionMessage = MergeDefault認証'{0}'は提供された認証リストにありません。
defaultAuthNotInListExceptionMessage = デフォルト認証'{0}'は提供された認証リストにありません。
scriptBlockRequiredForMergingUsersExceptionMessage = ValidがAllの場合、複数の認証済みユーザーを1つのオブジェクトにマージするためのScriptBlockが必要です。
noDomainServerNameForWindowsAdAuthExceptionMessage = Windows AD認証用のドメインサーバー名が提供されていません。
sessionsNotConfiguredExceptionMessage = セッションが構成されていません。
windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage = Windowsローカル認証のサポートはWindowsのみです。
iisAuthSupportIsForWindowsOnlyExceptionMessage = IIS認証のサポートはWindowsのみです。
noAlgorithmInJwtHeaderExceptionMessage = JWTヘッダーにアルゴリズムが提供されていません。
invalidJwtSuppliedExceptionMessage = 無効なJWTが提供されました。
invalidJwtHeaderAlgorithmSuppliedExceptionMessage = 無効なJWTヘッダーアルゴリズムが提供されました。
noJwtSignatureForAlgorithmExceptionMessage = {0}のためのJWT署名が提供されていません。
expectedNoJwtSignatureSuppliedExceptionMessage = 提供されるべきではないJWT署名が予期されました。
invalidJwtSignatureSuppliedExceptionMessage = 無効なJWT署名が提供されました。
jwtExpiredExceptionMessage = JWTの有効期限が切れています。
jwtNotYetValidExceptionMessage = JWTはまだ有効ではありません。
snapinsSupportedOnWindowsPowershellOnlyExceptionMessage = SnapinsはWindows PowerShellのみでサポートされています。
userFileDoesNotExistExceptionMessage = ユーザーファイルが存在しません：{0}
schemeRequiresValidScriptBlockExceptionMessage = '{0}'認証バリデーターのために提供されたスキームには有効なScriptBlockが必要です。
oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage = OAuth2プロバイダーは'code' response_typeをサポートしていません。
oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage = OAuth2プロバイダーはInnerSchemeを使用するために必要な'password' grant_typeをサポートしていません。
eventAlreadyRegisteredExceptionMessage = {0}イベントはすでに登録されています：{1}
noEventRegisteredExceptionMessage = 登録された{0}イベントはありません：{1}
sessionsRequiredForFlashMessagesExceptionMessage = フラッシュメッセージを使用するにはセッションが必要です。
eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage = イベントビューアーロギングはWindowsでのみサポートされています。
nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage = カスタムロギング出力メソッドには空でないScriptBlockが必要です。
requestLoggingAlreadyEnabledExceptionMessage = リクエストロギングは既に有効になっています。
outputMethodRequiresValidScriptBlockForRequestLoggingExceptionMessage = リクエストロギングのために提供された出力メソッドには有効なScriptBlockが必要です。
errorLoggingAlreadyEnabledExceptionMessage = エラーロギングは既に有効になっています。
nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage = ロギングメソッドには空でないScriptBlockが必要です。
csrfMiddlewareNotInitializedExceptionMessage = CSRFミドルウェアが初期化されていません。
sessionsRequiredForCsrfExceptionMessage = クッキーを使用しない場合は、CSRFを使用するためにセッションが必要です。
middlewareNoLogicSuppliedExceptionMessage = [ミドルウェア]: ScriptBlockにロジックが提供されていません。
parameterHasNoNameExceptionMessage = パラメーターに名前がありません。このコンポーネントに'Name'パラメーターを使用して名前を付けてください。
reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = OpenAPI v3.0では再利用可能なコンポーネント機能'pathItems'は使用できません。
noPropertiesMutuallyExclusiveExceptionMessage = パラメーター'NoProperties'は'Properties'、'MinProperties'、および'MaxProperties'と相互排他的です。
discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = パラメーター'DiscriminatorMapping'は'DiscriminatorProperty'が存在する場合にのみ使用できます。
discriminatorIncompatibleWithAllOfExceptionMessage = パラメーター'Discriminator'は'allOf'と互換性がありません。
typeCanOnlyBeAssociatedWithObjectExceptionMessage = タイプ{0}はオブジェクトにのみ関連付けることができます。
showPodeGuiOnlyAvailableOnWindowsExceptionMessage = Show-PodeGuiは現在、Windows PowerShellおよびWindows上のPowerShell 7+でのみ利用可能です。
nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage = RedirectToパラメーターが提供されている場合、エンドポイントには名前が必要です。
clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage = クライアント証明書はHTTPSエンドポイントでのみサポートされています。
explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage = 明示的なTLSモードはSMTPSおよびTCPSエンドポイントでのみサポートされています。
acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = 確認メッセージはSMTPおよびTCPエンドポイントでのみサポートされています。
crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage = CRLFメッセージ終了チェックはTCPエンドポイントでのみサポートされています。
mustBeRunningWithAdminPrivilegesExceptionMessage = ローカルホスト以外のアドレスでリッスンするには管理者権限で実行する必要があります。
certificateSuppliedForNonHttpsWssEndpointExceptionMessage = HTTPS/WSS以外のエンドポイントに提供された証明書。
websocketsNotConfiguredForSignalMessagesExceptionMessage = WebSocketsはシグナルメッセージを送信するように構成されていません。
noPathSuppliedForRouteExceptionMessage = ルートのパスが提供されていません。
accessRequiresAuthenticationOnRoutesExceptionMessage = アクセスにはルート上の認証が必要です。
accessMethodDoesNotExistExceptionMessage = アクセスメソッドが存在しません：{0}。
routeParameterNeedsValidScriptblockExceptionMessage = ルートパラメーターには有効で空でないScriptBlockが必要です。
noCommandsSuppliedToConvertToRoutesExceptionMessage = ルートに変換するためのコマンドが提供されていません。
nonEmptyScriptBlockRequiredForPageRouteExceptionMessage = ページルートを作成するには空でないScriptBlockが必要です。
sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage = SSEはAcceptヘッダー値がtext/event-streamのリクエストでのみ構成できます。
sseConnectionNameRequiredExceptionMessage = -Nameまたは$WebEvent.Sse.NameからSSE接続名が必要です。
sseFailedToBroadcastExceptionMessage = {0}のSSEブロードキャストレベルが定義されているため、SSEのブロードキャストに失敗しました: {1}
podeNotInitializedExceptionMessage = Podeが初期化されていません。
invalidTaskTypeExceptionMessage = タスクタイプが無効です。予期されるタイプ：[System.Threading.Tasks.Task]または[hashtable]
cannotLockValueTypeExceptionMessage = [ValueTypes]をロックできません。
cannotLockNullObjectExceptionMessage = nullオブジェクトをロックできません。
failedToAcquireLockExceptionMessage = オブジェクトのロックを取得できませんでした。
cannotUnlockValueTypeExceptionMessage = [ValueTypes]のロックを解除できません。
cannotUnlockNullObjectExceptionMessage = nullオブジェクトのロックを解除できません。
sessionMiddlewareAlreadyInitializedExceptionMessage = セッションミドルウェアは既に初期化されています。
customSessionStorageMethodNotImplementedExceptionMessage = カスタムセッションストレージは必要なメソッド'{0}()'を実装していません。
secretRequiredForCustomSessionStorageExceptionMessage = カスタムセッションストレージを使用する場合、シークレットが必要です。
noSessionAvailableToSaveExceptionMessage = 保存するためのセッションが利用できません。
cannotSupplyIntervalWhenEveryIsNoneExceptionMessage = パラメーター'Every'がNoneに設定されている場合、間隔を提供できません。
cannotSupplyIntervalForQuarterExceptionMessage = 四半期ごとの間隔値を提供できません。
cannotSupplyIntervalForYearExceptionMessage = 毎年の間隔値を提供できません。
secretVaultAlreadyRegisteredExceptionMessage = 名前 '{0}' のシークレットボールトは既に登録されています{1}。
secretVaultUnlockExpiryDateInPastExceptionMessage = シークレットボールトのアンロック有効期限が過去に設定されています (UTC) :{0}
secretAlreadyMountedExceptionMessage = 名前 '{0}' のシークレットは既にマウントされています。
credentialsPassedWildcardForHeadersLiteralExceptionMessage = 資格情報が渡されると、ヘッダーのワイルドカード * はワイルドカードとしてではなく、リテラル文字列として解釈されます。
wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage = ヘッダーのワイルドカード * は AutoHeaders スイッチと互換性がありません。
wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage = メソッドのワイルドカード * は AutoMethods スイッチと互換性がありません。
invalidAccessControlMaxAgeDurationExceptionMessage = 無効な Access-Control-Max-Age 期間が提供されました：{0}。0 より大きくする必要があります。
noNameForWebSocketDisconnectExceptionMessage = 切断する WebSocket の名前が指定されていません。
noNameForWebSocketRemoveExceptionMessage = 削除する WebSocket の名前が指定されていません。
noNameForWebSocketSendMessageExceptionMessage = メッセージを送信する WebSocket の名前が指定されていません。
noSecretNamedMountedExceptionMessage = 名前 '{0}' のシークレットはマウントされていません。
noNameForWebSocketResetExceptionMessage = リセットする WebSocket の名前が指定されていません。
schemaValidationRequiresPowerShell610ExceptionMessage = スキーマ検証には PowerShell バージョン 6.1.0 以上が必要です。
routeParameterCannotBeNullExceptionMessage = パラメータ 'Route' は null ではいけません。
encodingAttributeOnlyAppliesToMultipartExceptionMessage = エンコーディング属性は、multipart および application/x-www-form-urlencoded リクエストボディにのみ適用されます。
testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage = 'Test-PodeOAComponentSchema' は 'Enable-PodeOpenApi -EnableSchemaValidation' を使用して有効にする必要があります。
openApiComponentSchemaDoesNotExistExceptionMessage = OpenApi コンポーネントスキーマ {0} は存在しません。
openApiParameterRequiresNameExceptionMessage = OpenApi パラメータには名前が必要です。
openApiLicenseObjectRequiresNameExceptionMessage = OpenAPI オブジェクト 'license' には 'name' プロパティが必要です。-LicenseName パラメータを使用してください。
parametersValueOrExternalValueMandatoryExceptionMessage = パラメータ 'Value' または 'ExternalValue' は必須です。
parametersMutuallyExclusiveExceptionMessage = パラメータ '{0}' と '{1}' は互いに排他的です。
maximumConcurrentWebSocketThreadsInvalidExceptionMessage = 最大同時 WebSocket スレッド数は >=1 でなければなりませんが、取得した値は: {0}
maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage = 最大同時 WebSocket スレッド数は最小値 {0} より小さくてはいけませんが、取得した値は: {1}
alreadyConnectedToWebSocketExceptionMessage = 名前 '{0}' の WebSocket に既に接続されています
failedToConnectToWebSocketExceptionMessage = WebSocket への接続に失敗しました: {0}
verbNoLogicPassedExceptionMessage = [動詞] {0}: ロジックが渡されていません
scriptPathDoesNotExistExceptionMessage = スクリプトパスが存在しません: {0}
failedToImportModuleExceptionMessage = モジュールのインポートに失敗しました: {0}
modulePathDoesNotExistExceptionMessage = モジュールパスが存在しません: {0}
defaultValueNotBooleanOrEnumExceptionMessage = デフォルト値は boolean ではなく、enum に含まれていません。
propertiesTypeObjectAssociationExceptionMessage = Object 型のプロパティのみが {0} と関連付けられます。
invalidContentTypeForSchemaExceptionMessage = スキーマの 'content-type' が無効です: {0}
openApiRequestStyleInvalidForParameterExceptionMessage = OpenApi リクエストのスタイルは {1} パラメータに対して {0} であってはなりません。
pathParameterRequiresRequiredSwitchExceptionMessage = パラメータの場所が 'Path' の場合、スイッチパラメータ 'Required' は必須です。
operationIdMustBeUniqueForArrayExceptionMessage = OperationID: {0} は一意でなければならず、配列に適用できません。
operationIdMustBeUniqueExceptionMessage = OperationID: {0} は一意でなければなりません。
noOpenApiUrlSuppliedExceptionMessage = {0} 用の OpenAPI URL が提供されていません。
noTitleSuppliedForPageExceptionMessage = {0} ページのタイトルが提供されていません。
noRoutePathSuppliedForPageExceptionMessage = {0} ページのルートパスが提供されていません。
swaggerEditorDoesNotSupportOpenApi31ExceptionMessage = このバージョンの Swagger-Editor は OpenAPI 3.1 をサポートしていません
rapidPdfDoesNotSupportOpenApi31ExceptionMessage = ドキュメントツール RapidPdf は OpenAPI 3.1 をサポートしていません
definitionTagNotDefinedExceptionMessage = 定義タグ {0} が定義されていません。
scopedVariableNotFoundExceptionMessage = スコープ変数が見つかりません: {0}
noSecretVaultRegisteredExceptionMessage = 名前 '{0}' のシークレットボールトは登録されていません。
invalidStrictTransportSecurityDurationExceptionMessage = 無効な Strict-Transport-Security 期間が指定されました: {0}。0 より大きい必要があります。
durationMustBeZeroOrGreaterExceptionMessage = 期間は 0 以上でなければなりませんが、取得した値は: {0}s
taskAlreadyDefinedExceptionMessage = [タスク] {0}: タスクは既に定義されています。
maximumConcurrentTasksInvalidExceptionMessage = 最大同時タスク数は >=1 でなければなりませんが、取得した値は: {0}
maximumConcurrentTasksLessThanMinimumExceptionMessage = 最大同時タスク数は最小値 {0} より少なくてはいけませんが、取得した値は: {1}
taskDoesNotExistExceptionMessage = タスク '{0}' は存在しません。
cacheStorageNotFoundForRetrieveExceptionMessage = キャッシュされたアイテム '{1}' を取得しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。
cacheStorageNotFoundForSetExceptionMessage = キャッシュされたアイテム '{1}' を設定しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。
cacheStorageNotFoundForExistsExceptionMessage = キャッシュされたアイテム '{1}' が存在するかどうかを確認しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。
cacheStorageNotFoundForRemoveExceptionMessage = キャッシュされたアイテム '{1}' を削除しようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。
cacheStorageNotFoundForClearExceptionMessage = キャッシュをクリアしようとしたときに、名前 '{0}' のキャッシュストレージが見つかりません。
cacheStorageAlreadyExistsExceptionMessage = 名前 '{0}' のキャッシュストレージは既に存在します。
pathToIconForGuiDoesNotExistExceptionMessage = GUI用アイコンのパスが存在しません: {0}
invalidHostnameSuppliedExceptionMessage = 無効なホスト名が指定されました: {0}
endpointAlreadyDefinedExceptionMessage = 名前 '{0}' のエンドポイントは既に定義されています。
certificateExpiredExceptionMessage = 証明書 '{0}' の有効期限が切れています: {1}
endpointNotDefinedForRedirectingExceptionMessage = リダイレクトのために名前 '{0}' のエンドポイントが定義されていません。
fileWatcherAlreadyDefinedExceptionMessage = 名前 '{0}' のファイルウォッチャーは既に定義されています。
handlerAlreadyDefinedExceptionMessage = [{0}] {1}: ハンドラは既に定義されています。
maxDaysInvalidExceptionMessage = MaxDaysは0以上でなければなりませんが、受け取った値は: {0}
maxSizeInvalidExceptionMessage = MaxSizeは0以上でなければなりませんが、受け取った値は: {0}
loggingMethodAlreadyDefinedExceptionMessage = ログ記録方法は既に定義されています: {0}
loggingMethodRequiresValidScriptBlockExceptionMessage = '{0}' ログ記録方法のために提供された出力方法は、有効なScriptBlockが必要です。
csrfCookieRequiresSecretExceptionMessage = CSRFのためにクッキーを使用する場合、秘密が必要です。秘密を提供するか、クッキーのグローバル秘密を設定してください - (Set-PodeCookieSecret '<value>' -Global)
bodyParserAlreadyDefinedForContentTypeExceptionMessage = {0} コンテンツタイプ用のボディパーサーは既に定義されています。
middlewareAlreadyDefinedExceptionMessage = [Middleware] {0}: ミドルウェアは既に定義されています。
parameterNotSuppliedInRequestExceptionMessage = リクエストに '{0}' という名前のパラメータが提供されていないか、データがありません。
noDataForFileUploadedExceptionMessage = リクエストでアップロードされたファイル '{0}' のデータがありません。
viewsFolderNameAlreadyExistsExceptionMessage = ビューのフォルダ名は既に存在します: {0}
viewsPathDoesNotExistExceptionMessage = ビューのパスが存在しません: {0}
timerAlreadyDefinedExceptionMessage = [タイマー] {0}: タイマーはすでに定義されています。
timerParameterMustBeGreaterThanZeroExceptionMessage = [タイマー] {0}: {1} は 0 より大きくなければなりません。
timerDoesNotExistExceptionMessage = タイマー '{0}' は存在しません。
mutexAlreadyExistsExceptionMessage = 次の名前のミューテックスはすでに存在します: {0}
noMutexFoundExceptionMessage = 名前 '{0}' のミューテックスが見つかりません
failedToAcquireMutexOwnershipExceptionMessage = ミューテックスの所有権を取得できませんでした。ミューテックス名: {0}
semaphoreAlreadyExistsExceptionMessage = 次の名前のセマフォはすでに存在します: {0}
failedToAcquireSemaphoreOwnershipExceptionMessage = セマフォの所有権を取得できませんでした。セマフォ名: {0}
scheduleAlreadyDefinedExceptionMessage = [スケジュール] {0}: スケジュールはすでに定義されています。
scheduleCannotHaveNegativeLimitExceptionMessage = [スケジュール] {0}: 負の制限を持つことはできません。
scheduleEndTimeMustBeInFutureExceptionMessage = [スケジュール] {0}: EndTime 値は未来に設定する必要があります。
scheduleStartTimeAfterEndTimeExceptionMessage = [スケジュール] {0}: 'StartTime' が 'EndTime' の後であることはできません
maximumConcurrentSchedulesInvalidExceptionMessage = 最大同時スケジュール数は 1 以上でなければなりませんが、受け取った値: {0}
maximumConcurrentSchedulesLessThanMinimumExceptionMessage = 最大同時スケジュール数は最小 {0} 未満にすることはできませんが、受け取った値: {1}
scheduleDoesNotExistExceptionMessage = スケジュール '{0}' は存在しません。
suppliedDateBeforeScheduleStartTimeExceptionMessage = 提供された日付はスケジュールの開始時間 {0} より前です
suppliedDateAfterScheduleEndTimeExceptionMessage = 提供された日付はスケジュールの終了時間 {0} の後です
noSemaphoreFoundExceptionMessage = 名前 '{0}' のセマフォが見つかりません
noLogicPassedForRouteExceptionMessage = ルートに対してロジックが渡されませんでした: {0}
noPathSuppliedForStaticRouteExceptionMessage = [{0}]: 静的ルートに対して提供されたパスがありません。
sourcePathDoesNotExistForStaticRouteExceptionMessage = [{0})] {1}: 静的ルートに対して提供されたソースパスが存在しません: {2}
noLogicPassedForMethodRouteExceptionMessage = [{0}] {1}: ロジックが渡されませんでした。
moduleDoesNotContainFunctionExceptionMessage = モジュール {0} にはルートに変換する関数 {1} が含まれていません。
pageNameShouldBeAlphaNumericExceptionMessage = ページ名は有効な英数字である必要があります: {0}
filesHaveChangedMessage = 次のファイルが変更されました:
multipleEndpointsForGuiMessage = 複数のエンドポイントが定義されていますが、GUIには最初のエンドポイントのみが使用されます。
openingGuiMessage = GUIを開いています。
listeningOnEndpointsMessage = 次の {0} エンドポイントでリッスンしています [{1} スレッド]:
specificationMessage = 仕様
documentationMessage = ドキュメント
restartingServerMessage = サーバーを再起動しています...
doneMessage = 完了
deprecatedTitleVersionDescriptionWarningMessage = 警告: 'Enable-PodeOpenApi' のタイトル、バージョン、および説明は非推奨です。代わりに 'Add-PodeOAInfo' を使用してください。
undefinedOpenApiReferencesMessage = 未定義のOpenAPI参照:
definitionTagMessage = 定義 {0}:
openApiGenerationDocumentErrorMessage = OpenAPI生成ドキュメントエラー:
infoTitleMandatoryMessage = info.title は必須です。
infoVersionMandatoryMessage = info.version は必須です。
missingComponentsMessage = 欠落しているコンポーネント
openApiInfoMessage = OpenAPI情報:
serverLoopingMessage = サーバーループ間隔 {0}秒
iisShutdownMessage = (IIS シャットダウン)
terminatingMessage = 終了中...
eolPowerShellWarningMessage = [警告] Pode {0} は、EOLであるPowerShell {1} でテストされていません。
untestedPowerShellVersionWarningMessage = [警告] Pode {0} はリリース時に利用可能でなかったため、PowerShell {1} でテストされていません。
'@