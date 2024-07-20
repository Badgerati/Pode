@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'يتطلب التحقق من صحة المخطط إصدار PowerShell 6.1.0 أو أحدث.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = 'مطلوب مسار أو ScriptBlock للحصول على قيم الوصول المخصصة.'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'يجب أن يكون OperationID: {0} فريدًا ولا يمكن تطبيقه على مصفوفة.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "لم يتم تعريف نقطة نهاية باسم '{0}' لإعادة التوجيه."
    filesHaveChangedMessage                                           = 'تم تغيير الملفات التالية:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'IIS ASPNETCORE_TOKEN مفقود.'
    minValueGreaterThanMaxExceptionMessage                            = 'يجب ألا تكون القيمة الدنيا {0} أكبر من القيمة القصوى.'
    noLogicPassedForRouteExceptionMessage                             = 'لم يتم تمرير منطق للمسار: {0}'
    scriptPathDoesNotExistExceptionMessage                            = 'مسار البرنامج النصي غير موجود: {0}'
    mutexAlreadyExistsExceptionMessage                                = 'يوجد بالفعل Mutex بالاسم التالي: {0}'
    listeningOnEndpointsMessage                                       = 'الاستماع على {0} نقطة(نقاط) النهاية التالية [{1} خيط(خيوط)]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = 'الدالة {0} غير مدعومة في سياق بدون خادم.'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = 'لم يكن من المتوقع توفير توقيع JWT.'
    secretAlreadyMountedExceptionMessage                              = "تم تثبيت سر بالاسم '{0}' بالفعل."
    failedToAcquireLockExceptionMessage                               = 'فشل في الحصول على قفل على الكائن.'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: لم يتم توفير مسار للمسار الثابت.'
    invalidHostnameSuppliedExceptionMessage                           = 'اسم المضيف المقدم غير صالح: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = 'طريقة المصادقة محددة بالفعل: {0}'
    csrfCookieRequiresSecretExceptionMessage                          = "عند استخدام ملفات تعريف الارتباط لـ CSRF، يكون السر مطلوبًا. يمكنك تقديم سر أو تعيين السر العالمي لملف تعريف الارتباط - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = 'مطلوب ScriptBlock غير فارغ لإنشاء مسار الصفحة.'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "المعامل 'NoProperties' يتعارض مع 'Properties' و 'MinProperties' و 'MaxProperties'."
    incompatiblePodeDllExceptionMessage                               = 'يتم تحميل إصدار غير متوافق من Pode.DLL {0}. الإصدار {1} مطلوب. افتح جلسة Powershell/pwsh جديدة وأعد المحاولة.'
    accessMethodDoesNotExistExceptionMessage                          = 'طريقة الوصول غير موجودة: {0}.'
    scheduleAlreadyDefinedExceptionMessage                            = '[الجدول الزمني] {0}: الجدول الزمني معرف بالفعل.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = 'لا يمكن أن تكون قيمة الثواني 0 أو أقل لـ {0}'
    pathToLoadNotFoundExceptionMessage                                = 'لم يتم العثور على المسار لتحميل {0}: {1}'
    failedToImportModuleExceptionMessage                              = 'فشل في استيراد الوحدة: {0}'
    endpointNotExistExceptionMessage                                  = "نقطة النهاية مع البروتوكول '{0}' والعنوان '{1}' أو العنوان المحلي '{2}' غير موجودة."
    terminatingMessage                                                = 'إنهاء...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = 'لم يتم توفير أي أوامر لتحويلها إلى طرق.'
    invalidTaskTypeExceptionMessage                                   = 'نوع المهمة غير صالح، المتوقع إما [System.Threading.Tasks.Task] أو [hashtable].'
    alreadyConnectedToWebSocketExceptionMessage                       = "متصل بالفعل بـ WebSocket بالاسم '{0}'"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'فحص نهاية الرسالة CRLF مدعوم فقط على نقاط النهاية TCP.'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "يجب تمكين 'Test-PodeOAComponentSchema' باستخدام 'Enable-PodeOpenApi -EnableSchemaValidation'"
    adModuleNotInstalledExceptionMessage                              = 'وحدة Active Directory غير مثبتة.'
    cronExpressionInvalidExceptionMessage                             = 'يجب أن تتكون تعبير Cron من 5 أجزاء فقط: {0}'
    noSessionToSetOnResponseExceptionMessage                          = 'لا توجد جلسة متاحة لتعيينها على الاستجابة.'
    valueOutOfRangeExceptionMessage                                   = "القيمة '{0}' لـ {1} غير صالحة، يجب أن تكون بين {2} و {3}"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'تم تعريف طريقة التسجيل بالفعل: {0}'
    noSecretForHmac256ExceptionMessage                                = 'لم يتم تقديم أي سر لتجزئة HMAC256.'
    eolPowerShellWarningMessage                                       = '[تحذير] لم يتم اختبار Pode {0} على PowerShell {1}، حيث أنه نهاية العمر.'
    runspacePoolFailedToLoadExceptionMessage                          = 'فشل تحميل RunspacePool لـ {0}.'
    noEventRegisteredExceptionMessage                                 = 'لا يوجد حدث {0} مسجل: {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[الجدول الزمني] {0}: لا يمكن أن يكون له حد سلبي.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'لا يمكن أن يكون نمط الطلب OpenApi {0} لمعلمة {1}.'
    openApiDocumentNotCompliantExceptionMessage                       = 'مستند OpenAPI غير متوافق.'
    taskDoesNotExistExceptionMessage                                  = "المهمة '{0}' غير موجودة."
    scopedVariableNotFoundExceptionMessage                            = 'لم يتم العثور على المتغير المحدد: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = 'الجلسات مطلوبة لاستخدام CSRF إلا إذا كنت ترغب في استخدام ملفات تعريف الارتباط.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'مطلوب ScriptBlock غير فارغ لطريقة التسجيل.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = 'عند تمرير بيانات الاعتماد، سيتم اعتبار العلامة * للعنوان كـ سلسلة نصية حرفية وليس كعلامة.'
    podeNotInitializedExceptionMessage                                = 'لم يتم تهيئة Pode.'
    multipleEndpointsForGuiMessage                                    = 'تم تعريف نقاط نهاية متعددة، سيتم استخدام الأولى فقط للواجهة الرسومية.'
    operationIdMustBeUniqueExceptionMessage                           = 'يجب أن يكون OperationID: {0} فريدًا.'
    invalidJsonJwtExceptionMessage                                    = 'تم العثور على قيمة JSON غير صالحة في JWT'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'لم يتم توفير أي خوارزمية في رأس JWT.'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'خاصية إصدار OpenApi إلزامية.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = 'لا يمكن أن تكون القيمة الحدية 0 أو أقل لـ {0}'
    timerDoesNotExistExceptionMessage                                 = "المؤقت '{0}' غير موجود."
    openApiGenerationDocumentErrorMessage                             = 'خطأ في مستند إنشاء OpenAPI:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "المسار '[{0}] {1}' يحتوي بالفعل على وصول مخصص باسم '{2}'"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = 'لا يمكن أن يكون الحد الأقصى لمؤشرات ترابط WebSocket المتزامنة أقل من الحد الأدنى {0}، ولكن تم الحصول عليه: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: تم تعريف الوسيط بالفعل.'
    invalidAtomCharacterExceptionMessage                              = 'حرف الذرة غير صالح: {0}'
    invalidCronAtomFormatExceptionMessage                             = 'تم العثور على تنسيق cron غير صالح: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "لم يتم العثور على مخزن ذاكرة التخزين المؤقت بالاسم '{0}' عند محاولة استرجاع العنصر المخزن مؤقتًا '{1}'"
    headerMustHaveNameInEncodingContextExceptionMessage               = 'يجب أن يحتوي الرأس على اسم عند استخدامه في سياق الترميز.'
    moduleDoesNotContainFunctionExceptionMessage                      = 'الوحدة {0} لا تحتوي على الوظيفة {1} لتحويلها إلى مسار.'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'المسار إلى الأيقونة للواجهة الرسومية غير موجود: {0}'
    noTitleSuppliedForPageExceptionMessage                            = 'لم يتم توفير عنوان للصفحة {0}.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'تم توفير شهادة لنقطة نهاية غير HTTPS/WSS.'
    cannotLockNullObjectExceptionMessage                              = 'لا يمكن قفل كائن فارغ.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui متاح حاليًا فقط لـ Windows PowerShell و PowerShell 7+ على Windows.'
    unlockSecretButNoScriptBlockExceptionMessage                      = 'تم تقديم سر الفتح لنوع خزنة سرية مخصصة، ولكن لم يتم تقديم ScriptBlock الفتح.'
    invalidIpAddressExceptionMessage                                  = 'عنوان IP المقدم غير صالح: {0}'
    maxDaysInvalidExceptionMessage                                    = 'يجب أن يكون MaxDays 0 أو أكبر، ولكن تم الحصول على: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "لم يتم تقديم ScriptBlock الإزالة لإزالة الأسرار من الخزنة '{0}'"
    noSecretExpectedForNoSignatureExceptionMessage                    = 'لم يكن من المتوقع تقديم أي سر لعدم وجود توقيع.'
    noCertificateFoundExceptionMessage                                = "لم يتم العثور على شهادة في {0}{1} لـ '{2}'"
    minValueInvalidExceptionMessage                                   = "القيمة الدنيا '{0}' لـ {1} غير صالحة، يجب أن تكون أكبر من/أو تساوي {2}"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = 'يتطلب الوصول توفير المصادقة على الطرق.'
    noSecretForHmac384ExceptionMessage                                = 'لم يتم تقديم أي سر لتجزئة HMAC384.'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'دعم المصادقة المحلية لـ Windows هو فقط لنظام Windows.'
    definitionTagNotDefinedExceptionMessage                           = 'لم يتم تعريف علامة التعريف {0}.'
    noComponentInDefinitionExceptionMessage                           = 'لا توجد مكون من نوع {0} باسم {1} متاح في تعريف {2}.'
    noSmtpHandlersDefinedExceptionMessage                             = 'لم يتم تعريف أي معالجات SMTP.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'تم تهيئة Session Middleware بالفعل.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "ميزة المكون القابل لإعادة الاستخدام 'pathItems' غير متوفرة في OpenAPI v3.0."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = 'العلامة * للعنوان غير متوافقة مع مفتاح AutoHeaders.'
    noDataForFileUploadedExceptionMessage                             = "لا توجد بيانات للملف '{0}' الذي تم تحميله في الطلب."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'يمكن تكوين SSE فقط على الطلبات التي تحتوي على قيمة رأس Accept النص/تيار الأحداث.'
    noSessionAvailableToSaveExceptionMessage                          = 'لا توجد جلسة متاحة للحفظ.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "إذا كانت موقع المعلمة هو 'Path'، فإن المعلمة التبديل 'Required' إلزامية."
    noOpenApiUrlSuppliedExceptionMessage                              = 'لم يتم توفير عنوان URL OpenAPI لـ {0}.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = 'يجب أن تكون الجداول الزمنية المتزامنة القصوى >=1 ولكن تم الحصول على: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Snapins مدعومة فقط في Windows PowerShell.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = 'تسجيل عارض الأحداث مدعوم فقط على Windows.'
    parametersMutuallyExclusiveExceptionMessage                       = "المعاملات '{0}' و '{1}' متعارضة."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = 'ميزة PathItems غير مدعومة في OpenAPI v3.0.x'
    openApiParameterRequiresNameExceptionMessage                      = 'يتطلب معلمة OpenApi اسمًا محددًا.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = 'لا يمكن أن يكون الحد الأقصى للمهام المتزامنة أقل من الحد الأدنى {0}، ولكن تم الحصول عليه: {1}'
    noSemaphoreFoundExceptionMessage                                  = "لم يتم العثور على Semaphore باسم '{0}'"
    singleValueForIntervalExceptionMessage                            = 'يمكنك تقديم قيمة {0} واحدة فقط عند استخدام الفواصل الزمنية.'
    jwtNotYetValidExceptionMessage                                    = 'JWT غير صالح للاستخدام بعد.'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[الفعل] {0}: تم التعريف بالفعل لـ {1}'
    noSecretNamedMountedExceptionMessage                              = "لم يتم تثبيت أي سر بالاسم '{0}'."
    moduleOrVersionNotFoundExceptionMessage                           = 'لم يتم العثور على الوحدة أو الإصدار على {0}: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'لم يتم تقديم أي ScriptBlock.'
    noSecretVaultRegisteredExceptionMessage                           = "لم يتم تسجيل خزينة سرية بالاسم '{0}'."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'مطلوب اسم لنقطة النهاية إذا تم توفير معامل RedirectTo.'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "يتطلب كائن OpenAPI 'license' الخاصية 'name'. استخدم المعامل -LicenseName."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: مسار المصدر المقدم للمسار الثابت غير موجود: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = 'لا يوجد اسم لفصل WebSocket من المزود.'
    certificateExpiredExceptionMessage                                = "الشهادة '{0}' منتهية الصلاحية: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = 'تاريخ انتهاء صلاحية فتح مخزن الأسرار في الماضي (UTC): {0}'
    invalidWebExceptionTypeExceptionMessage                           = 'الاستثناء من نوع غير صالح، يجب أن يكون إما WebException أو HttpRequestException، ولكن تم الحصول عليه: {0}'
    invalidSecretValueTypeExceptionMessage                            = 'قيمة السر من نوع غير صالح. الأنواع المتوقعة: String، SecureString، HashTable، Byte[]، أو PSCredential. ولكن تم الحصول عليه: {0}'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = 'وضع TLS الصريح مدعوم فقط على نقاط النهاية SMTPS و TCPS.'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "يمكن استخدام المعامل 'DiscriminatorMapping' فقط عندما تكون خاصية 'DiscriminatorProperty' موجودة."
    scriptErrorExceptionMessage                                       = "خطأ '{0}' في البرنامج النصي {1} {2} (السطر {3}) الحرف {4} أثناء تنفيذ {5} على الكائن {6} 'الصنف: {7} الصنف الأساسي: {8}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = 'لا يمكن توفير قيمة الفاصل الزمني لكل ربع.'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[الجدول الزمني] {0}: يجب أن تكون قيمة EndTime في المستقبل.'
    invalidJwtSignatureSuppliedExceptionMessage                       = 'توقيع JWT المقدم غير صالح.'
    noSetScriptBlockForVaultExceptionMessage                          = "لم يتم تقديم ScriptBlock الإعداد لتحديث/إنشاء الأسرار في الخزنة '{0}'"
    accessMethodNotExistForMergingExceptionMessage                    = 'طريقة الوصول غير موجودة للدمج: {0}'
    defaultAuthNotInListExceptionMessage                              = "المصادقة الافتراضية '{0}' غير موجودة في قائمة المصادقة المقدمة."
    parameterHasNoNameExceptionMessage                                = "لا يحتوي المعامل على اسم. يرجى إعطاء هذا المكون اسمًا باستخدام معامل 'Name'."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: تم التعريف بالفعل لـ {2}'
    fileWatcherAlreadyDefinedExceptionMessage                         = "تم تعريف مراقب الملفات باسم '{0}' بالفعل."
    noServiceHandlersDefinedExceptionMessage                          = 'لم يتم تعريف أي معالجات خدمة.'
    secretRequiredForCustomSessionStorageExceptionMessage             = 'مطلوب سر عند استخدام تخزين الجلسة المخصص.'
    secretManagementModuleNotInstalledExceptionMessage                = 'وحدة Microsoft.PowerShell.SecretManagement غير مثبتة.'
    noPathSuppliedForRouteExceptionMessage                            = 'لم يتم توفير مسار للطريق.'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "التحقق من مخطط يتضمن 'أي منها' غير مدعوم."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'دعم مصادقة IIS هو فقط لنظام Windows.'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'يمكن أن تكون OAuth2 InnerScheme إما مصادقة Basic أو Form فقط، ولكن تم الحصول على: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = 'لم يتم توفير مسار للصفحة {0}.'
    cacheStorageNotFoundForExistsExceptionMessage                     = "لم يتم العثور على مخزن ذاكرة التخزين المؤقت بالاسم '{0}' عند محاولة التحقق مما إذا كان العنصر المخزن مؤقتًا '{1}' موجودًا."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: تم تعريف المعالج بالفعل.'
    sessionsNotConfiguredExceptionMessage                             = 'لم يتم تكوين الجلسات.'
    propertiesTypeObjectAssociationExceptionMessage                   = 'يمكن ربط خصائص النوع Object فقط بـ {0}.'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = 'تتطلب المصادقة المستمرة للجلسة جلسات.'
    invalidPathWildcardOrDirectoryExceptionMessage                    = 'لا يمكن أن يكون المسار المقدم عبارة عن حرف بدل أو دليل: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = 'طريقة الوصول معرفة بالفعل: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "المعاملات 'Value' أو 'ExternalValue' إلزامية."
    maximumConcurrentTasksInvalidExceptionMessage                     = 'يجب أن يكون الحد الأقصى للمهام المتزامنة >=1، ولكن تم الحصول عليه: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = 'لا يمكن إنشاء الخاصية لأنه لم يتم تعريف نوع.'
    authMethodNotExistForMergingExceptionMessage                      = 'طريقة المصادقة غير موجودة للدمج: {0}'
    maxValueInvalidExceptionMessage                                   = "القيمة القصوى '{0}' لـ {1} غير صالحة، يجب أن تكون أقل من/أو تساوي {2}"
    endpointAlreadyDefinedExceptionMessage                            = "تم تعريف نقطة نهاية باسم '{0}' بالفعل."
    eventAlreadyRegisteredExceptionMessage                            = 'الحدث {0} مسجل بالفعل: {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "لم يتم توفير معلمة باسم '{0}' في الطلب أو لا توجد بيانات متاحة."
    cacheStorageNotFoundForSetExceptionMessage                        = "لم يتم العثور على مخزن ذاكرة التخزين المؤقت بالاسم '{0}' عند محاولة تعيين العنصر المخزن مؤقتًا '{1}'"
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: تم التعريف بالفعل.'
    errorLoggingAlreadyEnabledExceptionMessage                        = 'تم تمكين تسجيل الأخطاء بالفعل.'
    valueForUsingVariableNotFoundExceptionMessage                     = "لم يتم العثور على قيمة لـ '`$using:{0}'."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = 'أداة الوثائق RapidPdf لا تدعم OpenAPI 3.1'
    oauth2ClientSecretRequiredExceptionMessage                        = 'تتطلب OAuth2 سر العميل عند عدم استخدام PKCE.'
    invalidBase64JwtExceptionMessage                                  = 'تم العثور على قيمة مشفرة بتنسيق Base64 غير صالحة في JWT'
    noSessionToCalculateDataHashExceptionMessage                      = 'لا توجد جلسة متاحة لحساب تجزئة البيانات.'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "لم يتم العثور على مخزن ذاكرة التخزين المؤقت بالاسم '{0}' عند محاولة إزالة العنصر المخزن مؤقتًا '{1}'"
    csrfMiddlewareNotInitializedExceptionMessage                      = 'لم يتم تهيئة CSRF Middleware.'
    infoTitleMandatoryMessage                                         = 'info.title إلزامي.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = 'النوع {0} يمكن ربطه فقط بجسم.'
    userFileDoesNotExistExceptionMessage                              = 'ملف المستخدم غير موجود: {0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = 'المعامل Route يتطلب ScriptBlock صالح وغير فارغ.'
    nextTriggerCalculationErrorExceptionMessage                       = 'يبدو أن هناك خطأ ما أثناء محاولة حساب تاريخ المشغل التالي: {0}'
    cannotLockValueTypeExceptionMessage                               = 'لا يمكن قفل [ValueType].'
    failedToCreateOpenSslCertExceptionMessage                         = 'فشل في إنشاء شهادة OpenSSL: {0}'
    jwtExpiredExceptionMessage                                        = 'انتهت صلاحية JWT.'
    openingGuiMessage                                                 = 'جارٍ فتح الواجهة الرسومية.'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = 'تتطلب خصائص الأنواع المتعددة إصدار OpenApi 3.1 أو أعلى.'
    noNameForWebSocketRemoveExceptionMessage                          = 'لا يوجد اسم لإزالة WebSocket من المزود.'
    maxSizeInvalidExceptionMessage                                    = 'يجب أن يكون MaxSize 0 أو أكبر، ولكن تم الحصول على: {0}'
    iisShutdownMessage                                                = '(إيقاف تشغيل IIS)'
    cannotUnlockValueTypeExceptionMessage                             = 'لا يمكن فتح [ValueType].'
    noJwtSignatureForAlgorithmExceptionMessage                        = 'لم يتم توفير توقيع JWT لـ {0}.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = 'يجب أن يكون الحد الأقصى لمؤشرات ترابط WebSocket المتزامنة >=1، ولكن تم الحصول عليه: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = 'رسالة الإقرار مدعومة فقط على نقاط النهاية SMTP و TCP.'
    failedToConnectToUrlExceptionMessage                              = 'فشل الاتصال بعنوان URL: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = 'فشل في الحصول على ملكية Mutex. اسم Mutex: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'تتطلب OAuth2 مع PKCE جلسات.'
    failedToConnectToWebSocketExceptionMessage                        = 'فشل الاتصال بـ WebSocket: {0}'
    unsupportedObjectExceptionMessage                                 = 'الكائن غير مدعوم'
    failedToParseAddressExceptionMessage                              = "فشل في تحليل '{0}' كعنوان IP/مضيف:منفذ صالح"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'يجب التشغيل بامتيازات المسؤول للاستماع إلى العناوين غير المحلية.'
    specificationMessage                                              = 'مواصفات'
    cacheStorageNotFoundForClearExceptionMessage                      = "لم يتم العثور على مخزن ذاكرة التخزين المؤقت بالاسم '{0}' عند محاولة مسح الذاكرة المؤقتة."
    restartingServerMessage                                           = 'إعادة تشغيل الخادم...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "لا يمكن توفير فترة زمنية عندما يكون المعامل 'Every' مضبوطًا على None."
    unsupportedJwtAlgorithmExceptionMessage                           = 'خوارزمية JWT غير مدعومة حاليًا: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'لم يتم تهيئة WebSockets لإرسال رسائل الإشارة.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = 'مكون Middleware من نوع Hashtable المقدم يحتوي على نوع منطق غير صالح. كان المتوقع ScriptBlock، ولكن تم الحصول عليه: {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = 'لا يمكن أن تكون الجداول الزمنية المتزامنة القصوى أقل من الحد الأدنى {0} ولكن تم الحصول على: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = 'فشل في الحصول على ملكية Semaphore. اسم Semaphore: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = 'لا يمكن استخدام معلمات الخصائص إذا لم يكن لدى الخاصية اسم.'
    customSessionStorageMethodNotImplementedExceptionMessage          = "تخزين الجلسة المخصص لا ينفذ الطريقة المطلوبة '{0}()'."
    authenticationMethodDoesNotExistExceptionMessage                  = 'طريقة المصادقة غير موجودة: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'ميزة Webhooks غير مدعومة في OpenAPI v3.0.x'
    invalidContentTypeForSchemaExceptionMessage                       = "'content-type' غير صالح في المخطط: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "لم يتم تقديم ScriptBlock الفتح لفتح الخزنة '{0}'"
    definitionTagMessage                                              = 'تعريف {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'فشل في فتح RunspacePool: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'فشل في إغلاق RunspacePool: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[الفعل] {0}: لم يتم تمرير أي منطق'
    noMutexFoundExceptionMessage                                      = "لم يتم العثور على Mutex باسم '{0}'"
    documentationMessage                                              = 'توثيق'
    timerAlreadyDefinedExceptionMessage                               = '[المؤقت] {0}: المؤقت معرف بالفعل.'
    invalidPortExceptionMessage                                       = 'لا يمكن أن يكون المنفذ سالبًا: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = 'اسم مجلد العرض موجود بالفعل: {0}'
    noNameForWebSocketResetExceptionMessage                           = 'لا يوجد اسم لإعادة تعيين WebSocket من المزود.'
    mergeDefaultAuthNotInListExceptionMessage                         = "المصادقة MergeDefault '{0}' غير موجودة في قائمة المصادقة المقدمة."
    descriptionRequiredExceptionMessage                               = 'الوصف مطلوب.'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'يجب أن يكون اسم الصفحة قيمة أبجدية رقمية صالحة: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = 'القيمة الافتراضية ليست من نوع boolean وليست جزءًا من التعداد.'
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'مخطط مكون OpenApi {0} غير موجود.'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[المؤقت] {0}: {1} يجب أن يكون أكبر من 0.'
    taskTimedOutExceptionMessage                                      = 'انتهت المهلة الزمنية للمهمة بعد {0}ms.'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[الجدول الزمني] {0}: لا يمكن أن يكون 'StartTime' بعد 'EndTime'"
    infoVersionMandatoryMessage                                       = 'info.version إلزامي.'
    cannotUnlockNullObjectExceptionMessage                            = 'لا يمكن فتح كائن فارغ.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = 'مطلوب ScriptBlock غير فارغ لخطة المصادقة المخصصة.'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = 'مطلوب ScriptBlock غير فارغ لطريقة المصادقة.'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "التحقق من مخطط يتضمن 'واحد منها' غير مدعوم."
    routeParameterCannotBeNullExceptionMessage                        = "لا يمكن أن يكون المعامل 'Route' فارغًا."
    cacheStorageAlreadyExistsExceptionMessage                         = "مخزن ذاكرة التخزين المؤقت بالاسم '{0}' موجود بالفعل."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "تتطلب طريقة الإخراج المقدمة لطريقة التسجيل '{0}' ScriptBlock صالح."
    scopedVariableAlreadyDefinedExceptionMessage                      = 'المتغير المحدد بالفعل معرف: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = 'تتطلب OAuth2 توفير عنوان URL للتفويض.'
    pathNotExistExceptionMessage                                      = 'المسار غير موجود: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = 'لم يتم توفير اسم خادم المجال لمصادقة Windows AD.'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = 'التاريخ المقدم بعد وقت انتهاء الجدول الزمني في {0}'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = 'العلامة * للطرق غير متوافقة مع مفتاح AutoMethods.'
    cannotSupplyIntervalForYearExceptionMessage                       = 'لا يمكن توفير قيمة الفاصل الزمني لكل سنة.'
    missingComponentsMessage                                          = 'المكون (المكونات) المفقود'
    invalidStrictTransportSecurityDurationExceptionMessage            = 'تم توفير مدة Strict-Transport-Security غير صالحة: {0}. يجب أن تكون أكبر من 0.'
    noSecretForHmac512ExceptionMessage                                = 'لم يتم تقديم أي سر لتجزئة HMAC512.'
    daysInMonthExceededExceptionMessage                               = 'يحتوي {0} على {1} أيام فقط، ولكن تم توفير {2}.'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'مطلوب ScriptBlock غير فارغ لطريقة إخراج السجل المخصصة.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = 'ينطبق سمة الترميز فقط على نصوص الطلبات multipart و application/x-www-form-urlencoded.'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = 'التاريخ المقدم قبل وقت بدء الجدول الزمني في {0}'
    unlockSecretRequiredExceptionMessage                              = "خاصية 'UnlockSecret' مطلوبة عند استخدام Microsoft.PowerShell.SecretStore"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: لم يتم تمرير منطق.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = 'تم تعريف محلل الجسم لنوع المحتوى {0} بالفعل.'
    invalidJwtSuppliedExceptionMessage                                = 'JWT المقدم غير صالح.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'الجلسات مطلوبة لاستخدام رسائل الفلاش.'
    semaphoreAlreadyExistsExceptionMessage                            = 'يوجد بالفعل Semaphore بالاسم التالي: {0}'
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = 'خوارزمية رأس JWT المقدمة غير صالحة.'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "مزود OAuth2 لا يدعم نوع المنحة 'password' المطلوبة لاستخدام InnerScheme."
    invalidAliasFoundExceptionMessage                                 = 'تم العثور على اسم مستعار غير صالح {0}: {1}'
    scheduleDoesNotExistExceptionMessage                              = "الجدول الزمني '{0}' غير موجود."
    accessMethodNotExistExceptionMessage                              = 'طريقة الوصول غير موجودة: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "مزود OAuth2 لا يدعم نوع الاستجابة 'code'."
    untestedPowerShellVersionWarningMessage                           = '[تحذير] لم يتم اختبار Pode {0} على PowerShell {1}، حيث لم يكن متاحًا عند إصدار Pode.'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "تم تسجيل خزنة سرية باسم '{0}' بالفعل أثناء استيراد الخزن السرية تلقائيًا."
    schemeRequiresValidScriptBlockExceptionMessage                    = "تتطلب الخطة المقدمة لمحقق المصادقة '{0}' ScriptBlock صالح."
    serverLoopingMessage                                              = 'تكرار الخادم كل {0} ثانية'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'بصمات الإبهام/الاسم للشهادة مدعومة فقط على Windows.'
    sseConnectionNameRequiredExceptionMessage                         = "مطلوب اسم اتصال SSE، إما من -Name أو `$WebEvent.Sse.Name"
    invalidMiddlewareTypeExceptionMessage                             = 'أحد مكونات Middleware المقدمة من نوع غير صالح. كان المتوقع إما ScriptBlock أو Hashtable، ولكن تم الحصول عليه: {0}'
    noSecretForJwtSignatureExceptionMessage                           = 'لم يتم تقديم أي سر لتوقيع JWT.'
    modulePathDoesNotExistExceptionMessage                            = 'مسار الوحدة غير موجود: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[المهمة] {0}: المهمة معرفة بالفعل.'
    verbAlreadyDefinedExceptionMessage                                = '[الفعل] {0}: تم التعريف بالفعل'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'الشهادات العميلة مدعومة فقط على نقاط النهاية HTTPS.'
    endpointNameNotExistExceptionMessage                              = "نقطة النهاية بالاسم '{0}' غير موجودة."
    middlewareNoLogicSuppliedExceptionMessage                         = '[Middleware]: لم يتم توفير أي منطق في ScriptBlock.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'مطلوب ScriptBlock لدمج عدة مستخدمين مصادق عليهم في كائن واحد عندما تكون Valid هي All.'
    secretVaultAlreadyRegisteredExceptionMessage                      = "تم تسجيل مخزن الأسرار بالاسم '{0}' بالفعل{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "تحذير: العنوان، الإصدار والوصف في 'Enable-PodeOpenApi' مهمل. يرجى استخدام 'Add-PodeOAInfo' بدلاً من ذلك."
    undefinedOpenApiReferencesMessage                                 = 'مراجع OpenAPI غير معرّفة:'
    doneMessage                                                       = 'تم'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = 'هذا الإصدار من Swagger-Editor لا يدعم OpenAPI 3.1'
    durationMustBeZeroOrGreaterExceptionMessage                       = 'يجب أن تكون المدة 0 أو أكبر، ولكن تم الحصول عليها: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = 'مسار العرض غير موجود: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "المعامل 'Discriminator' غير متوافق مع 'allOf'."
    noNameForWebSocketSendMessageExceptionMessage                     = 'لا يوجد اسم لإرسال رسالة إلى WebSocket المزود.'
    hashtableMiddlewareNoLogicExceptionMessage                        = 'مكون Middleware من نوع Hashtable المقدم لا يحتوي على منطق معرف.'
    openApiInfoMessage                                                = 'معلومات OpenAPI:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "تتطلب الخطة '{0}' المقدمة لمحقق المصادقة '{1}' ScriptBlock صالح."
    sseFailedToBroadcastExceptionMessage                              = 'فشل بث SSE بسبب مستوى البث SSE المحدد لـ {0}: {1}'
    adModuleWindowsOnlyExceptionMessage                               = 'وحدة Active Directory متاحة فقط على نظام Windows.'
    requestLoggingAlreadyEnabledExceptionMessage                      = 'تم تمكين تسجيل الطلبات بالفعل.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = 'مدة Access-Control-Max-Age غير صالحة المقدمة: {0}. يجب أن تكون أكبر من 0.'
    openApiDefinitionAlreadyExistsExceptionMessage                    = 'تعريف OpenAPI باسم {0} موجود بالفعل.'
    renamePodeOADefinitionTagExceptionMessage                         = "لا يمكن استخدام Rename-PodeOADefinitionTag داخل Select-PodeOADefinition 'ScriptBlock'."
    fnDoesNotAcceptArrayAsPipelineInputExceptionMessage               = "الدالة '{0}' لا تقبل مصفوفة كمدخل لأنبوب البيانات."
    definitionTagChangeNotAllowedExceptionMessage                     = 'لا يمكن تغيير علامة التعريف لمسار.'
}
