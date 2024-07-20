@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'Walidacja schematu wymaga wersji PowerShell 6.1.0 lub nowszej.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = 'Ścieżka lub ScriptBlock są wymagane do pozyskiwania wartości dostępu niestandardowego.'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID: {0} musi być unikalny i nie może być zastosowany do tablicy.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "Nie zdefiniowano punktu końcowego o nazwie '{0}' do przekierowania."
    filesHaveChangedMessage                                           = 'Następujące pliki zostały zmienione:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'Brakujący IIS ASPNETCORE_TOKEN.'
    minValueGreaterThanMaxExceptionMessage                            = 'Minimalna wartość dla {0} nie powinna być większa od maksymalnej wartości.'
    noLogicPassedForRouteExceptionMessage                             = 'Brak logiki przekazanej dla trasy: {0}'
    scriptPathDoesNotExistExceptionMessage                            = 'Ścieżka skryptu nie istnieje: {0}'
    mutexAlreadyExistsExceptionMessage                                = "Muteks o nazwie '{0}' już istnieje."
    listeningOnEndpointsMessage                                       = 'Nasłuchiwanie na następujących {0} punktach końcowych [{1} wątków]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = 'Funkcja {0} nie jest obsługiwana w kontekście bezserwerowym.'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = 'Oczekiwano, że nie zostanie dostarczony żaden podpis JWT.'
    secretAlreadyMountedExceptionMessage                              = "Tajemnica o nazwie '{0}' została już zamontowana."
    failedToAcquireLockExceptionMessage                               = 'Nie udało się uzyskać blokady na obiekcie.'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: Brak dostarczonej ścieżki dla trasy statycznej.'
    invalidHostnameSuppliedExceptionMessage                           = 'Podano nieprawidłową nazwę hosta: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = 'Metoda uwierzytelniania już zdefiniowana: {0}'
    csrfCookieRequiresSecretExceptionMessage                          = "Podczas używania ciasteczek do CSRF, wymagany jest Sekret. Możesz dostarczyć Sekret lub ustawić globalny sekret dla ciasteczek - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = 'Aby utworzyć trasę strony, wymagany jest niepusty ScriptBlock.'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "Parametr 'NoProperties' jest wzajemnie wykluczający się z 'Properties', 'MinProperties' i 'MaxProperties'."
    incompatiblePodeDllExceptionMessage                               = 'Istnieje niekompatybilna wersja Pode.DLL {0}. Wymagana wersja {1}. Otwórz nową sesję Powershell/pwsh i spróbuj ponownie.'
    accessMethodDoesNotExistExceptionMessage                          = 'Metoda dostępu nie istnieje: {0}.'
    scheduleAlreadyDefinedExceptionMessage                            = '[Harmonogram] {0}: Harmonogram już zdefiniowany.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = 'Wartość sekund nie może być 0 lub mniejsza dla {0}'
    pathToLoadNotFoundExceptionMessage                                = 'Ścieżka do załadowania {0} nie znaleziona: {1}'
    failedToImportModuleExceptionMessage                              = 'Nie udało się zaimportować modułu: {0}'
    endpointNotExistExceptionMessage                                  = "Punkt końcowy z protokołem '{0}' i adresem '{1}' lub adresem lokalnym '{2}' nie istnieje."
    terminatingMessage                                                = 'Kończenie...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = 'Nie dostarczono żadnych poleceń do konwersji na trasy.'
    invalidTaskTypeExceptionMessage                                   = 'Typ zadania jest nieprawidłowy, oczekiwano [System.Threading.Tasks.Task] lub [hashtable]'
    alreadyConnectedToWebSocketExceptionMessage                       = "Już połączono z WebSocket o nazwie '{0}'"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'Sprawdzanie końca wiadomości CRLF jest obsługiwane tylko na punktach końcowych TCP.'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema' musi być włączony przy użyciu 'Enable-PodeOpenApi -EnableSchemaValidation'"
    adModuleNotInstalledExceptionMessage                              = 'Moduł Active Directory nie jest zainstalowany.'
    cronExpressionInvalidExceptionMessage                             = 'Wyrażenie Cron powinno składać się tylko z 5 części: {0}'
    noSessionToSetOnResponseExceptionMessage                          = 'Brak dostępnej sesji do ustawienia odpowiedzi.'
    valueOutOfRangeExceptionMessage                                   = "Wartość '{0}' dla {1} jest nieprawidłowa, powinna być pomiędzy {2} a {3}"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'Metoda logowania już zdefiniowana: {0}'
    noSecretForHmac256ExceptionMessage                                = 'Nie podano tajemnicy dla haszowania HMAC256.'
    eolPowerShellWarningMessage                                       = '[OSTRZEŻENIE] Pode {0} nie był testowany na PowerShell {1}, ponieważ jest to wersja EOL.'
    runspacePoolFailedToLoadExceptionMessage                          = '{0} Nie udało się załadować RunspacePool.'
    noEventRegisteredExceptionMessage                                 = 'Brak zarejestrowanego wydarzenia {0}: {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[Harmonogram] {0}: Nie może mieć ujemnego limitu.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'Styl żądania OpenApi nie może być {0} dla parametru {1}.'
    openApiDocumentNotCompliantExceptionMessage                       = 'Dokument OpenAPI nie jest zgodny.'
    taskDoesNotExistExceptionMessage                                  = "Zadanie '{0}' nie istnieje."
    scopedVariableNotFoundExceptionMessage                            = 'Nie znaleziono zmiennej zakresu: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = 'Sesje są wymagane do używania CSRF, chyba że chcesz używać ciasteczek.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'Metoda rejestrowania wymaga niepustego ScriptBlock.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = 'Gdy przekazywane są dane uwierzytelniające, symbol wieloznaczny * dla nagłówków będzie traktowany jako dosłowny ciąg znaków, a nie symbol wieloznaczny.'
    podeNotInitializedExceptionMessage                                = 'Pode nie został zainicjowany.'
    multipleEndpointsForGuiMessage                                    = 'Zdefiniowano wiele punktów końcowych, tylko pierwszy będzie używany dla GUI.'
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID: {0} musi być unikalny.'
    invalidJsonJwtExceptionMessage                                    = 'Nieprawidłowa wartość JSON znaleziona w JWT'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'Brak dostarczonego algorytmu w nagłówku JWT.'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'Właściwość wersji OpenApi jest obowiązkowa.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = 'Wartość limitu nie może być 0 lub mniejsza dla {0}'
    timerDoesNotExistExceptionMessage                                 = "Timer '{0}' nie istnieje."
    openApiGenerationDocumentErrorMessage                             = 'Błąd generowania dokumentu OpenAPI:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "Trasa '[{0}] {1}' już zawiera dostęp niestandardowy z nazwą '{2}'"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = 'Maksymalna liczba jednoczesnych wątków WebSocket nie może być mniejsza niż minimum {0}, ale otrzymano: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: Middleware już zdefiniowany.'
    invalidAtomCharacterExceptionMessage                              = 'Nieprawidłowy znak atomu: {0}'
    invalidCronAtomFormatExceptionMessage                             = 'Znaleziono nieprawidłowy format atomu cron: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby pobrania elementu z pamięci podręcznej '{1}'."
    headerMustHaveNameInEncodingContextExceptionMessage               = 'Nagłówek musi mieć nazwę, gdy jest używany w kontekście kodowania.'
    moduleDoesNotContainFunctionExceptionMessage                      = 'Moduł {0} nie zawiera funkcji {1} do konwersji na trasę.'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'Ścieżka do ikony dla GUI nie istnieje: {0}'
    noTitleSuppliedForPageExceptionMessage                            = 'Nie dostarczono tytułu dla strony {0}.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'Certyfikat dostarczony dla punktu końcowego innego niż HTTPS/WSS.'
    cannotLockNullObjectExceptionMessage                              = 'Nie można zablokować pustego obiektu.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui jest obecnie dostępne tylko dla Windows PowerShell i PowerShell 7+ w Windows.'
    unlockSecretButNoScriptBlockExceptionMessage                      = 'Podano tajemnicę odblokowania dla niestandardowego typu skarbca, ale nie podano ScriptBlock odblokowania.'
    invalidIpAddressExceptionMessage                                  = 'Podany adres IP jest nieprawidłowy: {0}'
    maxDaysInvalidExceptionMessage                                    = 'MaxDays musi wynosić 0 lub więcej, ale otrzymano: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "Nie podano ScriptBlock dla usuwania tajemnic ze skarbca '{0}'"
    noSecretExpectedForNoSignatureExceptionMessage                    = 'Nie oczekiwano podania tajemnicy dla braku podpisu.'
    noCertificateFoundExceptionMessage                                = "Nie znaleziono certyfikatu w {0}{1} dla '{2}'"
    minValueInvalidExceptionMessage                                   = "Minimalna wartość '{0}' dla {1} jest nieprawidłowa, powinna być większa lub równa {2}"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = 'Dostęp wymaga uwierzytelnienia na trasach.'
    noSecretForHmac384ExceptionMessage                                = 'Nie podano tajemnicy dla haszowania HMAC384.'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'Wsparcie lokalnego uwierzytelniania Windows jest tylko dla Windows.'
    definitionTagNotDefinedExceptionMessage                           = 'Etykieta definicji {0} nie jest zdefiniowana.'
    noComponentInDefinitionExceptionMessage                           = 'Brak komponentu typu {0} o nazwie {1} dostępnego w definicji {2}.'
    noSmtpHandlersDefinedExceptionMessage                             = 'Nie zdefiniowano żadnych obsługujących SMTP.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'Middleware sesji został już zainicjowany.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "Funkcja wielokrotnego użytku 'pathItems' nie jest dostępna w OpenAPI v3.0."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = 'Symbol wieloznaczny * dla nagłówków jest niezgodny z przełącznikiem AutoHeaders.'
    noDataForFileUploadedExceptionMessage                             = "Brak danych dla pliku '{0}' przesłanego w żądaniu."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSE można skonfigurować tylko na żądaniach z wartością nagłówka Accept równą text/event-stream.'
    noSessionAvailableToSaveExceptionMessage                          = 'Brak dostępnej sesji do zapisania.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "Jeśli lokalizacja parametru to 'Path', przełącznik 'Required' jest obowiązkowy."
    noOpenApiUrlSuppliedExceptionMessage                              = 'Nie dostarczono adresu URL OpenAPI dla {0}.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = 'Maksymalna liczba równoczesnych harmonogramów musi wynosić >=1, ale otrzymano: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Snapiny są obsługiwane tylko w Windows PowerShell.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = 'Rejestrowanie w Podglądzie zdarzeń jest obsługiwane tylko w systemie Windows.'
    parametersMutuallyExclusiveExceptionMessage                       = "Parametry '{0}' i '{1}' są wzajemnie wykluczające się."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = 'Funkcja PathItems nie jest obsługiwana w OpenAPI v3.0.x'
    openApiParameterRequiresNameExceptionMessage                      = 'Parametr OpenApi wymaga podania nazwy.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = 'Maksymalna liczba jednoczesnych zadań nie może być mniejsza niż minimum {0}, ale otrzymano: {1}'
    noSemaphoreFoundExceptionMessage                                  = "Nie znaleziono semaforu o nazwie '{0}'"
    singleValueForIntervalExceptionMessage                            = 'Możesz podać tylko jedną wartość {0} podczas korzystania z interwałów.'
    jwtNotYetValidExceptionMessage                                    = 'JWT jeszcze nie jest ważny.'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[Czasownik] {0}: Już zdefiniowane dla {1}'
    noSecretNamedMountedExceptionMessage                              = "Nie zamontowano tajemnicy o nazwie '{0}'."
    moduleOrVersionNotFoundExceptionMessage                           = 'Nie znaleziono modułu lub wersji na {0}: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'Nie podano ScriptBlock.'
    noSecretVaultRegisteredExceptionMessage                           = "Nie zarejestrowano Skarbca Tajemnic o nazwie '{0}'."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'Nazwa jest wymagana dla punktu końcowego, jeśli podano parametr RedirectTo.'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "Obiekt OpenAPI 'license' wymaga właściwości 'name'. Użyj parametru -LicenseName."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: Dostarczona ścieżka źródłowa dla trasy statycznej nie istnieje: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = 'Nie podano nazwy dla rozłączenia WebSocket.'
    certificateExpiredExceptionMessage                                = "Certyfikat '{0}' wygasł: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = 'Data wygaśnięcia odblokowania Skarbca tajemnic jest w przeszłości (UTC): {0}'
    invalidWebExceptionTypeExceptionMessage                           = 'Wyjątek jest nieprawidłowego typu, powinien być WebException lub HttpRequestException, ale otrzymano: {0}'
    invalidSecretValueTypeExceptionMessage                            = 'Wartość tajemnicy jest nieprawidłowego typu. Oczekiwane typy: String, SecureString, HashTable, Byte[] lub PSCredential. Ale otrzymano: {0}'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = 'Tryb TLS Explicity jest obsługiwany tylko na punktach końcowych SMTPS i TCPS.'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "Parametr 'DiscriminatorMapping' może być używany tylko wtedy, gdy jest obecna właściwość 'DiscriminatorProperty'."
    scriptErrorExceptionMessage                                       = "Błąd '{0}' w skrypcie {1} {2} (linia {3}) znak {4} podczas wykonywania {5} na {6} obiekt '{7}' Klasa: {8} Klasa bazowa: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = 'Nie można dostarczyć wartości interwału dla każdego kwartału.'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[Harmonogram] {0}: Wartość EndTime musi być w przyszłości.'
    invalidJwtSignatureSuppliedExceptionMessage                       = 'Dostarczono nieprawidłowy podpis JWT.'
    noSetScriptBlockForVaultExceptionMessage                          = "Nie podano ScriptBlock dla aktualizacji/tworzenia tajemnic w skarbcu '{0}'"
    accessMethodNotExistForMergingExceptionMessage                    = 'Metoda dostępu nie istnieje do scalania: {0}'
    defaultAuthNotInListExceptionMessage                              = "Domyślne uwierzytelnianie '{0}' nie znajduje się na dostarczonej liście uwierzytelniania."
    parameterHasNoNameExceptionMessage                                = "Parametr nie ma nazwy. Proszę nadać tej części nazwę za pomocą parametru 'Name'."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: Już zdefiniowane dla {2}'
    fileWatcherAlreadyDefinedExceptionMessage                         = "Obserwator plików o nazwie '{0}' został już zdefiniowany."
    noServiceHandlersDefinedExceptionMessage                          = 'Nie zdefiniowano żadnych obsługujących usług.'
    secretRequiredForCustomSessionStorageExceptionMessage             = 'Podczas korzystania z niestandardowego przechowywania sesji wymagany jest sekret.'
    secretManagementModuleNotInstalledExceptionMessage                = 'Moduł Microsoft.PowerShell.SecretManagement nie jest zainstalowany.'
    noPathSuppliedForRouteExceptionMessage                            = 'Nie podano ścieżki dla trasy.'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "Walidacja schematu, który zawiera 'anyof', nie jest obsługiwana."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'Wsparcie uwierzytelniania IIS jest tylko dla Windows.'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'OAuth2 InnerScheme może być tylko jednym z dwóch: Basic lub Form, ale otrzymano: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = 'Nie dostarczono ścieżki trasy dla strony {0}.'
    cacheStorageNotFoundForExistsExceptionMessage                     = "Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby sprawdzenia, czy element w pamięci podręcznej '{1}' istnieje."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: Handler już zdefiniowany.'
    sessionsNotConfiguredExceptionMessage                             = 'Sesje nie zostały skonfigurowane.'
    propertiesTypeObjectAssociationExceptionMessage                   = 'Tylko właściwości typu Object mogą być powiązane z {0}.'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = 'Sesje są wymagane do używania trwałego uwierzytelniania sesji.'
    invalidPathWildcardOrDirectoryExceptionMessage                    = 'Podana ścieżka nie może być symbolem wieloznacznym ani katalogiem: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = 'Metoda dostępu już zdefiniowana: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "Parametry 'Value' lub 'ExternalValue' są obowiązkowe."
    maximumConcurrentTasksInvalidExceptionMessage                     = 'Maksymalna liczba jednoczesnych zadań musi wynosić >=1, ale otrzymano: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = 'Nie można utworzyć właściwości, ponieważ nie zdefiniowano typu.'
    authMethodNotExistForMergingExceptionMessage                      = 'Metoda uwierzytelniania nie istnieje dla scalania: {0}'
    maxValueInvalidExceptionMessage                                   = "Maksymalna wartość '{0}' dla {1} jest nieprawidłowa, powinna być mniejsza lub równa {2}"
    endpointAlreadyDefinedExceptionMessage                            = "Punkt końcowy o nazwie '{0}' został już zdefiniowany."
    eventAlreadyRegisteredExceptionMessage                            = 'Wydarzenie {0} już zarejestrowane: {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "Parametr o nazwie '{0}' nie został dostarczony w żądaniu lub nie ma dostępnych danych."
    cacheStorageNotFoundForSetExceptionMessage                        = "Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby ustawienia elementu w pamięci podręcznej '{1}'."
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: Już zdefiniowane.'
    errorLoggingAlreadyEnabledExceptionMessage                        = 'Rejestrowanie błędów jest już włączone.'
    valueForUsingVariableNotFoundExceptionMessage                     = "Nie można znaleźć wartości dla '`$using:{0}'."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = 'Narzędzie do dokumentów RapidPdf nie obsługuje OpenAPI 3.1'
    oauth2ClientSecretRequiredExceptionMessage                        = 'OAuth2 wymaga tajemnicy klienta, gdy nie używa się PKCE.'
    invalidBase64JwtExceptionMessage                                  = 'Nieprawidłowa wartość zakodowana w Base64 znaleziona w JWT'
    noSessionToCalculateDataHashExceptionMessage                      = 'Brak dostępnej sesji do obliczenia skrótu danych.'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby usunięcia elementu z pamięci podręcznej '{1}'."
    csrfMiddlewareNotInitializedExceptionMessage                      = 'Middleware CSRF nie został zainicjowany.'
    infoTitleMandatoryMessage                                         = 'info.title jest obowiązkowe.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = 'Typ {0} może być powiązany tylko z obiektem.'
    userFileDoesNotExistExceptionMessage                              = 'Plik użytkownika nie istnieje: {0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = 'Parametr trasy wymaga prawidłowego, niepustego ScriptBlock.'
    nextTriggerCalculationErrorExceptionMessage                       = 'Wygląda na to, że coś poszło nie tak przy próbie obliczenia następnej daty i godziny wyzwalacza: {0}'
    cannotLockValueTypeExceptionMessage                               = 'Nie można zablokować [ValueType].'
    failedToCreateOpenSslCertExceptionMessage                         = 'Nie udało się utworzyć certyfikatu OpenSSL: {0}'
    jwtExpiredExceptionMessage                                        = 'JWT wygasł.'
    openingGuiMessage                                                 = 'Otwieranie GUI.'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = 'Właściwości wielotypowe wymagają wersji OpenApi 3.1 lub wyższej.'
    noNameForWebSocketRemoveExceptionMessage                          = 'Nie podano nazwy dla usunięcia WebSocket.'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize musi wynosić 0 lub więcej, ale otrzymano: {0}'
    iisShutdownMessage                                                = '(Zamykanie IIS)'
    cannotUnlockValueTypeExceptionMessage                             = 'Nie można odblokować [ValueType].'
    noJwtSignatureForAlgorithmExceptionMessage                        = 'Nie dostarczono podpisu JWT dla {0}.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = 'Maksymalna liczba jednoczesnych wątków WebSocket musi wynosić >=1, ale otrzymano: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = 'Komunikat potwierdzenia jest obsługiwany tylko na punktach końcowych SMTP i TCP.'
    failedToConnectToUrlExceptionMessage                              = 'Nie udało się połączyć z URL: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = 'Nie udało się przejąć własności muteksu. Nazwa muteksu: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'Sesje są wymagane do używania OAuth2 z PKCE'
    failedToConnectToWebSocketExceptionMessage                        = 'Nie udało się połączyć z WebSocket: {0}'
    unsupportedObjectExceptionMessage                                 = 'Obiekt nieobsługiwany'
    failedToParseAddressExceptionMessage                              = "Nie udało się przeanalizować '{0}' jako poprawnego adresu IP/Host:Port"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'Musisz mieć uprawnienia administratora, aby nasłuchiwać na adresach innych niż localhost.'
    specificationMessage                                              = 'Specyfikacja'
    cacheStorageNotFoundForClearExceptionMessage                      = "Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby wyczyszczenia pamięci podręcznej."
    restartingServerMessage                                           = 'Restartowanie serwera...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "Nie można dostarczyć interwału, gdy parametr 'Every' jest ustawiony na None."
    unsupportedJwtAlgorithmExceptionMessage                           = 'Algorytm JWT nie jest obecnie obsługiwany: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'WebSockets nie zostały skonfigurowane do wysyłania wiadomości sygnałowych.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = 'Dostarczone Middleware typu Hashtable ma nieprawidłowy typ logiki. Oczekiwano ScriptBlock, ale otrzymano: {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = 'Maksymalna liczba równoczesnych harmonogramów nie może być mniejsza niż minimalna liczba {0}, ale otrzymano: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = 'Nie udało się przejąć własności semaforu. Nazwa semaforu: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = 'Parametry Properties nie mogą być używane, jeśli właściwość nie ma nazwy.'
    customSessionStorageMethodNotImplementedExceptionMessage          = "Niestandardowe przechowywanie sesji nie implementuje wymaganego ''{0}()'' sposobu."
    authenticationMethodDoesNotExistExceptionMessage                  = 'Metoda uwierzytelniania nie istnieje: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'Funkcja Webhooks nie jest obsługiwana w OpenAPI v3.0.x'
    invalidContentTypeForSchemaExceptionMessage                       = "Nieprawidłowy 'content-type' znaleziony w schemacie: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "Nie podano ScriptBlock odblokowania dla odblokowania skarbca '{0}'"
    definitionTagMessage                                              = 'Definicja {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'Nie udało się otworzyć RunspacePool: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'Nie udało się zamknąć RunspacePool: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[Czasownik] {0}: Nie przekazano logiki'
    noMutexFoundExceptionMessage                                      = "Nie znaleziono muteksu o nazwie '{0}'."
    documentationMessage                                              = 'Dokumentacja'
    timerAlreadyDefinedExceptionMessage                               = '[Timer] {0}: Timer już zdefiniowany.'
    invalidPortExceptionMessage                                       = 'Port nie może być ujemny: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = 'Nazwa folderu Widoków już istnieje: {0}'
    noNameForWebSocketResetExceptionMessage                           = 'Nie podano nazwy dla resetowania WebSocket.'
    mergeDefaultAuthNotInListExceptionMessage                         = "Uwierzytelnianie MergeDefault '{0}' nie znajduje się na dostarczonej liście uwierzytelniania."
    descriptionRequiredExceptionMessage                               = 'Wymagany jest opis.'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'Nazwa strony powinna być poprawną wartością alfanumeryczną: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = 'Wartość domyślna nie jest typu boolean i nie należy do enum.'
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'Schemat komponentu OpenApi {0} nie istnieje.'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[Timer] {0}: {1} musi być większy od 0.'
    taskTimedOutExceptionMessage                                      = 'Zadanie przekroczyło limit czasu po {0}ms.'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[Harmonogram] {0}: Nie może mieć 'StartTime' po 'EndTime'."
    infoVersionMandatoryMessage                                       = 'info.version jest obowiązkowe.'
    cannotUnlockNullObjectExceptionMessage                            = 'Nie można odblokować pustego obiektu.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = 'Dla niestandardowego schematu uwierzytelniania wymagany jest niepusty ScriptBlock.'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = 'Wymagany jest niepusty ScriptBlock dla metody uwierzytelniania.'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "Walidacja schematu, który zawiera 'oneof', nie jest obsługiwana."
    routeParameterCannotBeNullExceptionMessage                        = "Parametr 'Route' nie może być pusty."
    cacheStorageAlreadyExistsExceptionMessage                         = "Magazyn pamięci podręcznej o nazwie '{0}' już istnieje."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "Dostarczona metoda wyjściowa dla metody logowania '{0}' wymaga poprawnego ScriptBlock."
    scopedVariableAlreadyDefinedExceptionMessage                      = 'Zmienna z zakresem już zdefiniowana: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = 'OAuth2 wymaga podania URL autoryzacji'
    pathNotExistExceptionMessage                                      = 'Ścieżka nie istnieje: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = 'Nie podano nazwy serwera domeny dla uwierzytelniania Windows AD'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = 'Podana data jest późniejsza niż czas zakończenia harmonogramu o {0}'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = 'Symbol wieloznaczny * dla metod jest niezgodny z przełącznikiem AutoMethods.'
    cannotSupplyIntervalForYearExceptionMessage                       = 'Nie można dostarczyć wartości interwału dla każdego roku.'
    missingComponentsMessage                                          = 'Brakujące komponenty'
    invalidStrictTransportSecurityDurationExceptionMessage            = 'Nieprawidłowy czas trwania Strict-Transport-Security: {0}. Powinien być większy niż 0.'
    noSecretForHmac512ExceptionMessage                                = 'Nie podano tajemnicy dla haszowania HMAC512.'
    daysInMonthExceededExceptionMessage                               = '{0} ma tylko {1} dni, ale podano {2}.'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'Metoda niestandardowego rejestrowania wymaga niepustego ScriptBlock.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = 'Atrybut kodowania dotyczy tylko ciał żądania typu multipart i application/x-www-form-urlencoded.'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = 'Podana data jest wcześniejsza niż czas rozpoczęcia harmonogramu o {0}'
    unlockSecretRequiredExceptionMessage                              = "Właściwość 'UnlockSecret' jest wymagana przy używaniu Microsoft.PowerShell.SecretStore"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: Brak logiki przekazanej.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = 'Parser treści dla typu zawartości {0} jest już zdefiniowany.'
    invalidJwtSuppliedExceptionMessage                                = 'Dostarczono nieprawidłowy JWT.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'Sesje są wymagane do używania wiadomości Flash.'
    semaphoreAlreadyExistsExceptionMessage                            = "Semafor o nazwie '{0}' już istnieje."
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = 'Dostarczono nieprawidłowy algorytm nagłówka JWT.'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "Dostawca OAuth2 nie obsługuje typu 'password' wymaganego przez InnerScheme."
    invalidAliasFoundExceptionMessage                                 = 'Znaleziono nieprawidłowy alias {0}: {1}'
    scheduleDoesNotExistExceptionMessage                              = "Harmonogram '{0}' nie istnieje."
    accessMethodNotExistExceptionMessage                              = 'Metoda dostępu nie istnieje: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "Dostawca OAuth2 nie obsługuje typu odpowiedzi 'code'."
    untestedPowerShellVersionWarningMessage                           = '[OSTRZEŻENIE] Pode {0} nie był testowany na PowerShell {1}, ponieważ nie był dostępny, gdy Pode został wydany.'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "Skarbiec z nazwą '{0}' został już zarejestrowany podczas automatycznego importowania skarbców."
    schemeRequiresValidScriptBlockExceptionMessage                    = "Dostarczony schemat dla walidatora uwierzytelniania '{0}' wymaga ważnego ScriptBlock."
    serverLoopingMessage                                              = 'Pętla serwera co {0} sekund'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'Odciski palców/nazwa certyfikatu są obsługiwane tylko w systemie Windows.'
    sseConnectionNameRequiredExceptionMessage                         = "Wymagana jest nazwa połączenia SSE, z -Name lub `$WebEvent.Sse.Name"
    invalidMiddlewareTypeExceptionMessage                             = 'Jeden z dostarczonych Middleware jest nieprawidłowego typu. Oczekiwano ScriptBlock lub Hashtable, ale otrzymano: {0}'
    noSecretForJwtSignatureExceptionMessage                           = 'Nie podano tajemnicy dla podpisu JWT.'
    modulePathDoesNotExistExceptionMessage                            = 'Ścieżka modułu nie istnieje: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[Zadanie] {0}: Zadanie już zdefiniowane.'
    verbAlreadyDefinedExceptionMessage                                = '[Czasownik] {0}: Już zdefiniowane'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'Certyfikaty klienta są obsługiwane tylko na punktach końcowych HTTPS.'
    endpointNameNotExistExceptionMessage                              = "Punkt końcowy o nazwie '{0}' nie istnieje."
    middlewareNoLogicSuppliedExceptionMessage                         = '[Middleware]: Nie dostarczono logiki w ScriptBlock.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'Wymagany jest ScriptBlock do scalania wielu uwierzytelnionych użytkowników w jeden obiekt, gdy opcja Valid to All.'
    secretVaultAlreadyRegisteredExceptionMessage                      = "Skarbiec tajemnic o nazwie '{0}' został już zarejestrowany{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "OSTRZEŻENIE: Tytuł, Wersja i Opis w 'Enable-PodeOpenApi' są przestarzałe. Proszę użyć 'Add-PodeOAInfo' zamiast tego."
    undefinedOpenApiReferencesMessage                                 = 'Niezdefiniowane odwołania OpenAPI:'
    doneMessage                                                       = 'Gotowe'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = 'Ta wersja Swagger-Editor nie obsługuje OpenAPI 3.1'
    durationMustBeZeroOrGreaterExceptionMessage                       = 'Czas trwania musi wynosić 0 lub więcej, ale otrzymano: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = 'Ścieżka do Widoków nie istnieje: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "Parametr 'Discriminator' jest niezgodny z 'allOf'."
    noNameForWebSocketSendMessageExceptionMessage                     = 'Nie podano nazwy dla wysłania wiadomości do WebSocket.'
    hashtableMiddlewareNoLogicExceptionMessage                        = 'Dostarczone Middleware typu Hashtable nie ma zdefiniowanej logiki.'
    openApiInfoMessage                                                = 'Informacje OpenAPI:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "Dostarczony schemat '{0}' dla walidatora uwierzytelniania '{1}' wymaga ważnego ScriptBlock."
    sseFailedToBroadcastExceptionMessage                              = 'SSE nie udało się przesłać z powodu zdefiniowanego poziomu przesyłania SSE dla {0}: {1}'
    adModuleWindowsOnlyExceptionMessage                               = 'Moduł Active Directory jest dostępny tylko w systemie Windows.'
    requestLoggingAlreadyEnabledExceptionMessage                      = 'Rejestrowanie żądań jest już włączone.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = 'Podano nieprawidłowy czas trwania Access-Control-Max-Age: {0}. Powinien być większy niż 0.'
    openApiDefinitionAlreadyExistsExceptionMessage                    = 'Definicja OpenAPI o nazwie {0} już istnieje.'
    renamePodeOADefinitionTagExceptionMessage                         = "Rename-PodeOADefinitionTag nie może być używany wewnątrz 'ScriptBlock' Select-PodeOADefinition."
    NonHashtableArrayElementExceptionMessage                          = 'Tablica zawiera element, który nie jest tabelą skrótów'
    InputNotHashtableOrArrayOfHashtablesExceptionMessage              = 'Dane wejściowe nie są tabelą skrótów ani tablicą tabel skrótów'
    DefinitionTagChangeNotAllowedExceptionMessage                     = 'Tag definicji dla Route nie może zostać zmieniony.'
}

