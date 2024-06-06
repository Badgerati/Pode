ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyExceptionMessage = Moduł Active Directory jest dostępny tylko w systemie Windows.
adModuleNotInstalledExceptionMessage = Moduł Active Directory nie jest zainstalowany.
secretManagementModuleNotInstalledExceptionMessage = Moduł Microsoft.PowerShell.SecretManagement nie jest zainstalowany.
secretVaultAlreadyRegisteredAutoImportExceptionMessage = Skarbiec z nazwą '{0}' został już zarejestrowany podczas automatycznego importowania skarbców.
failedToOpenRunspacePoolExceptionMessage = Nie udało się otworzyć RunspacePool: {0}
cronExpressionInvalidExceptionMessage = Wyrażenie Cron powinno składać się tylko z 5 części: {0}
invalidAliasFoundExceptionMessage = Znaleziono nieprawidłowy alias {0}: {1}
invalidAtomCharacterExceptionMessage = Nieprawidłowy znak atomu: {0}
minValueGreaterThanMaxExceptionMessage = Minimalna wartość dla {0} nie powinna być większa od maksymalnej wartości.
minValueInvalidExceptionMessage = Minimalna wartość '{0}' dla {1} jest nieprawidłowa, powinna być większa lub równa {2}
maxValueInvalidExceptionMessage = Maksymalna wartość '{0}' dla {1} jest nieprawidłowa, powinna być mniejsza lub równa {2}
valueOutOfRangeExceptionMessage = Wartość '{0}' dla {1} jest nieprawidłowa, powinna być pomiędzy {2} a {3}
daysInMonthExceededExceptionMessage = {0} ma tylko {1} dni, ale podano {2}.
nextTriggerCalculationErrorExceptionMessage = Wygląda na to, że coś poszło nie tak przy próbie obliczenia następnej daty i godziny wyzwalacza: {0}
incompatiblePodeDllExceptionMessage = Istnieje niekompatybilna wersja Pode.DLL {0}. Wymagana wersja {1}. Otwórz nową sesję Powershell/pwsh i spróbuj ponownie.
endpointNotExistExceptionMessage = Punkt końcowy z protokołem '{0}' i adresem '{1}' lub adresem lokalnym '{2}' nie istnieje.
endpointNameNotExistExceptionMessage = Punkt końcowy o nazwie '{0}' nie istnieje.
failedToConnectToUrlExceptionMessage = Nie udało się połączyć z URL: {0}
failedToParseAddressExceptionMessage = Nie udało się przeanalizować '{0}' jako poprawnego adresu IP/Host:Port
invalidIpAddressExceptionMessage = Podany adres IP jest nieprawidłowy: {0}
invalidPortExceptionMessage = Port nie może być ujemny: {0}
pathNotExistExceptionMessage = Ścieżka nie istnieje: {0}
noSecretForHmac256ExceptionMessage = Nie podano tajemnicy dla haszowania HMAC256.
noSecretForHmac384ExceptionMessage = Nie podano tajemnicy dla haszowania HMAC384.
noSecretForHmac512ExceptionMessage = Nie podano tajemnicy dla haszowania HMAC512.
noSecretForJwtSignatureExceptionMessage = Nie podano tajemnicy dla podpisu JWT.
noSecretExpectedForNoSignatureExceptionMessage = Nie oczekiwano podania tajemnicy dla braku podpisu.
unsupportedJwtAlgorithmExceptionMessage = Algorytm JWT nie jest obecnie obsługiwany: {0}
invalidBase64JwtExceptionMessage = Nieprawidłowa wartość zakodowana w Base64 znaleziona w JWT
invalidJsonJwtExceptionMessage = Nieprawidłowa wartość JSON znaleziona w JWT
unsupportedFunctionInServerlessContextExceptionMessage = Funkcja {0} nie jest obsługiwana w kontekście bezserwerowym.
invalidPathWildcardOrDirectoryExceptionMessage = Podana ścieżka nie może być symbolem wieloznacznym ani katalogiem: {0}
invalidExceptionTypeExceptionMessage = Wyjątek jest nieprawidłowego typu, powinien być WebException lub HttpRequestException, ale otrzymano: {0}
pathToLoadNotFoundExceptionMessage = Ścieżka do załadowania {0} nie znaleziona: {1}
singleValueForIntervalExceptionMessage = Możesz podać tylko jedną wartość {0} podczas korzystania z interwałów.
scriptErrorExceptionMessage = Błąd '{0}' w skrypcie {1} {2} (linia {3}) znak {4} podczas wykonywania {5} na {6} obiekt '{7}' Klasa: {8} Klasa bazowa: {9}
noScriptBlockSuppliedExceptionMessage = Nie podano ScriptBlock.
iisAspnetcoreTokenMissingExceptionMessage = Brakujący IIS ASPNETCORE_TOKEN.
propertiesParameterWithoutNameExceptionMessage = Parametry Properties nie mogą być używane, jeśli właściwość nie ma nazwy.
multiTypePropertiesRequireOpenApi31ExceptionMessage = Właściwości wielotypowe wymagają wersji OpenApi 3.1 lub wyższej.
openApiVersionPropertyMandatoryExceptionMessage = Właściwość wersji OpenApi jest obowiązkowa.
webhooksFeatureNotSupportedInOpenApi30ExceptionMessage = Funkcja Webhooks nie jest obsługiwana w OpenAPI v3.0.x
authenticationMethodDoesNotExistExceptionMessage = Metoda uwierzytelniania nie istnieje: {0}
unsupportedObjectExceptionMessage = Obiekt nieobsługiwany
validationOfAnyOfSchemaNotSupportedExceptionMessage = Walidacja schematu, który zawiera 'anyof', nie jest obsługiwana.
validationOfOneOfSchemaNotSupportedExceptionMessage = Walidacja schematu, który zawiera 'oneof', nie jest obsługiwana.
cannotCreatePropertyWithoutTypeExceptionMessage = Nie można utworzyć właściwości, ponieważ nie zdefiniowano typu.
headerMustHaveNameInEncodingContextExceptionMessage = Nagłówek musi mieć nazwę, gdy jest używany w kontekście kodowania.
descriptionRequiredExceptionMessage = Wymagany jest opis.
openApiDocumentNotCompliantExceptionMessage = Dokument OpenAPI nie jest zgodny.
noComponentInDefinitionExceptionMessage = Brak komponentu typu {0} o nazwie {1} dostępnego w definicji {2}.
methodPathAlreadyDefinedExceptionMessage = [{0}] {1}: Już zdefiniowane.
methodPathAlreadyDefinedForUrlExceptionMessage = [{0}] {1}: Już zdefiniowane dla {2}
invalidMiddlewareTypeExceptionMessage = Jeden z dostarczonych Middleware jest nieprawidłowego typu. Oczekiwano ScriptBlock lub Hashtable, ale otrzymano: {0}
hashtableMiddlewareNoLogicExceptionMessage = Dostarczone Middleware typu Hashtable nie ma zdefiniowanej logiki.
invalidLogicTypeInHashtableMiddlewareExceptionMessage = Dostarczone Middleware typu Hashtable ma nieprawidłowy typ logiki. Oczekiwano ScriptBlock, ale otrzymano: {0}
scopedVariableAlreadyDefinedExceptionMessage = Zmienna z zakresem już zdefiniowana: {0}
valueForUsingVariableNotFoundExceptionMessage = Nie można znaleźć wartości dla '$using:{0}'.
unlockSecretRequiredExceptionMessage = Właściwość 'UnlockSecret' jest wymagana przy używaniu Microsoft.PowerShell.SecretStore
unlockSecretButNoScriptBlockExceptionMessage = Podano tajemnicę odblokowania dla niestandardowego typu skarbca, ale nie podano ScriptBlock odblokowania.
noUnlockScriptBlockForVaultExceptionMessage = Nie podano ScriptBlock odblokowania dla odblokowania skarbca '{0}'
noSetScriptBlockForVaultExceptionMessage = Nie podano ScriptBlock dla aktualizacji/tworzenia tajemnic w skarbcu '{0}'
noRemoveScriptBlockForVaultExceptionMessage = Nie podano ScriptBlock dla usuwania tajemnic ze skarbca '{0}'
invalidSecretValueTypeExceptionMessage = Wartość tajemnicy jest nieprawidłowego typu. Oczekiwane typy: String, SecureString, HashTable, Byte[] lub PSCredential. Ale otrzymano: {0}
limitValueCannotBeZeroOrLessExceptionMessage = Wartość limitu nie może być 0 lub mniejsza dla {0}
secondsValueCannotBeZeroOrLessExceptionMessage = Wartość sekund nie może być 0 lub mniejsza dla {0}
failedToCreateOpenSslCertExceptionMessage = Nie udało się utworzyć certyfikatu openssl: {0}
certificateThumbprintsNameSupportedOnWindowsExceptionMessage = Odciski palców/nazwa certyfikatu są obsługiwane tylko w systemie Windows.
noCertificateFoundExceptionMessage = Nie znaleziono certyfikatu w {0}\{1} dla '{2}'
runspacePoolFailedToLoadExceptionMessage = {0} Nie udało się załadować RunspacePool.
noServiceHandlersDefinedExceptionMessage = Nie zdefiniowano żadnych obsługujących usług.
noSessionToSetOnResponseExceptionMessage = Brak dostępnej sesji do ustawienia odpowiedzi.
noSessionToCalculateDataHashExceptionMessage = Brak dostępnej sesji do obliczenia skrótu danych.
moduleOrVersionNotFoundExceptionMessage = Nie znaleziono modułu lub wersji na {0}: {1}@{2}
noSmtpHandlersDefinedExceptionMessage = Nie zdefiniowano żadnych obsługujących SMTP.
taskTimedOutExceptionMessage = Zadanie przekroczyło limit czasu po {0}ms.
verbAlreadyDefinedExceptionMessage = [Czasownik] {0}: Już zdefiniowane
verbAlreadyDefinedForUrlExceptionMessage = [Czasownik] {0}: Już zdefiniowane dla {1}
pathOrScriptBlockRequiredExceptionMessage = Ścieżka lub ScriptBlock są wymagane do pozyskiwania wartości dostępu niestandardowego.
accessMethodAlreadyDefinedExceptionMessage = Metoda dostępu już zdefiniowana: {0}
accessMethodNotExistForMergingExceptionMessage = Metoda dostępu nie istnieje do scalania: {0}
routeAlreadyContainsCustomAccessExceptionMessage = Trasa '[{0}] {1}' już zawiera dostęp niestandardowy z nazwą '{2}'
accessMethodNotExistExceptionMessage = Metoda dostępu nie istnieje: {0}
pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage = Funkcja PathItems nie jest obsługiwana w OpenAPI v3.0.x
nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage = Dla niestandardowego schematu uwierzytelniania wymagany jest niepusty ScriptBlock.
oauth2InnerSchemeInvalidExceptionMessage = OAuth2 InnerScheme może być tylko jednym z dwóch: Basic lub Form, ale otrzymano: {0}
sessionsRequiredForOAuth2WithPKCEExceptionMessage = Sesje są wymagane do używania OAuth2 z PKCE
oauth2ClientSecretRequiredExceptionMessage = OAuth2 wymaga tajemnicy klienta, gdy nie używa się PKCE.
authMethodAlreadyDefinedExceptionMessage = Metoda uwierzytelniania już zdefiniowana: {0}
invalidSchemeForAuthValidatorExceptionMessage = Dostarczony schemat '{0}' dla walidatora uwierzytelniania '{1}' wymaga ważnego ScriptBlock.
sessionsRequiredForSessionPersistentAuthExceptionMessage = Sesje są wymagane do używania trwałego uwierzytelniania sesji.
oauth2RequiresAuthorizeUrlExceptionMessage = OAuth2 wymaga podania URL autoryzacji
authMethodNotExistForMergingExceptionMessage = Metoda uwierzytelniania nie istnieje dla scalania: {0}
mergeDefaultAuthNotInListExceptionMessage = Uwierzytelnianie MergeDefault '{0}' nie znajduje się na dostarczonej liście uwierzytelniania.
defaultAuthNotInListExceptionMessage = Domyślne uwierzytelnianie '{0}' nie znajduje się na dostarczonej liście uwierzytelniania.
scriptBlockRequiredForMergingUsersExceptionMessage = Wymagany jest ScriptBlock do scalania wielu uwierzytelnionych użytkowników w jeden obiekt, gdy opcja Valid to All.
noDomainServerNameForWindowsAdAuthExceptionMessage = Nie podano nazwy serwera domeny dla uwierzytelniania Windows AD
sessionsNotConfiguredExceptionMessage = Sesje nie zostały skonfigurowane.
windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage = Wsparcie lokalnego uwierzytelniania Windows jest tylko dla Windows.
iisAuthSupportIsForWindowsOnlyExceptionMessage = Wsparcie uwierzytelniania IIS jest tylko dla Windows.
noAlgorithmInJwtHeaderExceptionMessage = Brak dostarczonego algorytmu w nagłówku JWT.
invalidJwtSuppliedExceptionMessage = Dostarczono nieprawidłowy JWT.
invalidJwtHeaderAlgorithmSuppliedExceptionMessage = Dostarczono nieprawidłowy algorytm nagłówka JWT.
noJwtSignatureForAlgorithmExceptionMessage = Nie dostarczono podpisu JWT dla {0}.
expectedNoJwtSignatureSuppliedExceptionMessage = Oczekiwano, że nie zostanie dostarczony żaden podpis JWT.
invalidJwtSignatureSuppliedExceptionMessage = Dostarczono nieprawidłowy podpis JWT.
jwtExpiredExceptionMessage = JWT wygasł.
jwtNotYetValidExceptionMessage = JWT jeszcze nie jest ważny.
snapinsSupportedOnWindowsPowershellOnlyExceptionMessage = Snapiny są obsługiwane tylko w Windows PowerShell.
userFileDoesNotExistExceptionMessage = Plik użytkownika nie istnieje: {0}
schemeRequiresValidScriptBlockExceptionMessage = Dostarczony schemat dla walidatora uwierzytelniania '{0}' wymaga ważnego ScriptBlock.
oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage = Dostawca OAuth2 nie obsługuje typu odpowiedzi 'code'.
oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage = Dostawca OAuth2 nie obsługuje typu 'password' wymaganego przez InnerScheme.
eventAlreadyRegisteredExceptionMessage = Wydarzenie {0} już zarejestrowane: {1}
noEventRegisteredExceptionMessage = Brak zarejestrowanego wydarzenia {0}: {1}
sessionsRequiredForFlashMessagesExceptionMessage = Sesje są wymagane do używania wiadomości Flash.
eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage = Rejestrowanie w Podglądzie zdarzeń jest obsługiwane tylko w systemie Windows.
nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage = Metoda niestandardowego rejestrowania wymaga niepustego ScriptBlock.
requestLoggingAlreadyEnabledExceptionMessage = Rejestrowanie żądań jest już włączone.
outputMethodRequiresValidScriptBlockForRequestLoggingExceptionMessage = Podana metoda wyjściowa do rejestrowania żądań wymaga prawidłowego ScriptBlock.
errorLoggingAlreadyEnabledExceptionMessage = Rejestrowanie błędów jest już włączone.
nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage = Metoda rejestrowania wymaga niepustego ScriptBlock.
csrfMiddlewareNotInitializedExceptionMessage = Middleware CSRF nie został zainicjowany.
sessionsRequiredForCsrfExceptionMessage = Sesje są wymagane do używania CSRF, chyba że chcesz używać ciasteczek.
middlewareNoLogicSuppliedExceptionMessage = [Middleware]: Nie dostarczono logiki w ScriptBlock.
parameterHasNoNameExceptionMessage = Parametr nie ma nazwy. Proszę nadać tej części nazwę za pomocą parametru 'Name'.
reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = Funkcja wielokrotnego użytku 'pathItems' nie jest dostępna w OpenAPI v3.0.
noPropertiesMutuallyExclusiveExceptionMessage = Parametr 'NoProperties' jest wzajemnie wykluczający się z 'Properties', 'MinProperties' i 'MaxProperties'.
discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = Parametr 'DiscriminatorMapping' może być używany tylko wtedy, gdy jest obecna właściwość 'DiscriminatorProperty'.
discriminatorIncompatibleWithAllOfExceptionMessage = Parametr 'Discriminator' jest niezgodny z 'allOf'.
typeCanOnlyBeAssociatedWithObjectExceptionMessage = Typ {0} może być powiązany tylko z obiektem.
showPodeGuiOnlyAvailableOnWindowsExceptionMessage = Show-PodeGui jest obecnie dostępne tylko dla Windows PowerShell i PowerShell 7+ w Windows.
nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage = Nazwa jest wymagana dla punktu końcowego, jeśli podano parametr RedirectTo.
clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage = Certyfikaty klienta są obsługiwane tylko na punktach końcowych HTTPS.
explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage = Tryb TLS Explicity jest obsługiwany tylko na punktach końcowych SMTPS i TCPS.
acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = Komunikat potwierdzenia jest obsługiwany tylko na punktach końcowych SMTP i TCP.
crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage = Sprawdzanie końca wiadomości CRLF jest obsługiwane tylko na punktach końcowych TCP.
mustBeRunningWithAdminPrivilegesExceptionMessage = Musisz mieć uprawnienia administratora, aby nasłuchiwać na adresach innych niż localhost.
certificateSuppliedForNonHttpsWssEndpointExceptionMessage = Certyfikat dostarczony dla punktu końcowego innego niż HTTPS/WSS.
websocketsNotConfiguredForSignalMessagesExceptionMessage = WebSockets nie zostały skonfigurowane do wysyłania wiadomości sygnałowych.
noPathSuppliedForRouteExceptionMessage = Nie podano ścieżki dla trasy.
accessRequiresAuthenticationOnRoutesExceptionMessage = Dostęp wymaga uwierzytelnienia na trasach.
accessMethodDoesNotExistExceptionMessage = Metoda dostępu nie istnieje: {0}.
routeParameterNeedsValidScriptblockExceptionMessage = Parametr trasy wymaga prawidłowego, niepustego ScriptBlock.
noCommandsSuppliedToConvertToRoutesExceptionMessage = Nie dostarczono żadnych poleceń do konwersji na trasy.
nonEmptyScriptBlockRequiredForPageRouteExceptionMessage = Aby utworzyć trasę strony, wymagany jest niepusty ScriptBlock.
sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage = SSE można skonfigurować tylko na żądaniach z wartością nagłówka Accept równą text/event-stream.
sseConnectionNameRequiredExceptionMessage = Wymagana jest nazwa połączenia SSE, z -Name lub $WebEvent.Sse.Name.
sseFailedToBroadcastExceptionMessage = SSE nie udało się przesłać z powodu zdefiniowanego poziomu przesyłania SSE dla {0}: {1}
podeNotInitializedExceptionMessage = Pode nie został zainicjowany.
invalidTaskTypeExceptionMessage = Typ zadania jest nieprawidłowy, oczekiwano [System.Threading.Tasks.Task] lub [hashtable]
cannotLockValueTypeExceptionMessage = Nie można zablokować [ValueTypes].
cannotLockNullObjectExceptionMessage = Nie można zablokować pustego obiektu.
failedToAcquireLockExceptionMessage = Nie udało się uzyskać blokady na obiekcie.
cannotUnlockValueTypeExceptionMessage = Nie można odblokować [ValueTypes].
cannotUnlockNullObjectExceptionMessage = Nie można odblokować pustego obiektu.
sessionMiddlewareAlreadyInitializedExceptionMessage = Middleware sesji został już zainicjowany.
customSessionStorageMethodNotImplementedExceptionMessage = Niestandardowe przechowywanie sesji nie implementuje wymaganego ''{0}()'' sposobu.
secretRequiredForCustomSessionStorageExceptionMessage = Podczas korzystania z niestandardowego przechowywania sesji wymagany jest sekret.
noSessionAvailableToSaveExceptionMessage = Brak dostępnej sesji do zapisania.
cannotSupplyIntervalWhenEveryIsNoneExceptionMessage = Nie można dostarczyć interwału, gdy parametr 'Every' jest ustawiony na None.
cannotSupplyIntervalForQuarterExceptionMessage = Nie można dostarczyć wartości interwału dla każdego kwartału.
cannotSupplyIntervalForYearExceptionMessage = Nie można dostarczyć wartości interwału dla każdego roku.
secretVaultAlreadyRegisteredExceptionMessage = Skarbiec tajemnic o nazwie '{0}' został już zarejestrowany{1}.
secretVaultUnlockExpiryDateInPastExceptionMessage = Data wygaśnięcia odblokowania Skarbca tajemnic jest w przeszłości (UTC): {0}
secretAlreadyMountedExceptionMessage = Tajemnica o nazwie '{0}' została już zamontowana.
credentialsPassedWildcardForHeadersLiteralExceptionMessage = Gdy przekazywane są dane uwierzytelniające, symbol wieloznaczny * dla nagłówków będzie traktowany jako dosłowny ciąg znaków, a nie symbol wieloznaczny.
wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage = Symbol wieloznaczny * dla nagłówków jest niezgodny z przełącznikiem AutoHeaders.
wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage = Symbol wieloznaczny * dla metod jest niezgodny z przełącznikiem AutoMethods.
invalidAccessControlMaxAgeDurationExceptionMessage = Podano nieprawidłowy czas trwania Access-Control-Max-Age: {0}. Powinien być większy niż 0.
noNameForWebSocketDisconnectExceptionMessage = Nie podano nazwy dla rozłączenia WebSocket.
noNameForWebSocketRemoveExceptionMessage = Nie podano nazwy dla usunięcia WebSocket.
noNameForWebSocketSendMessageExceptionMessage = Nie podano nazwy dla wysłania wiadomości do WebSocket.
noSecretNamedMountedExceptionMessage = Nie zamontowano tajemnicy o nazwie '{0}'.
noNameForWebSocketResetExceptionMessage = Nie podano nazwy dla resetowania WebSocket.
schemaValidationRequiresPowerShell610ExceptionMessage = Walidacja schematu wymaga wersji PowerShell 6.1.0 lub nowszej.
routeParameterCannotBeNullExceptionMessage = Parametr 'Route' nie może być pusty.
encodingAttributeOnlyAppliesToMultipartExceptionMessage = Atrybut kodowania dotyczy tylko ciał żądania typu multipart i application/x-www-form-urlencoded.
testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage = 'Test-PodeOAComponentSchema' musi być włączony przy użyciu 'Enable-PodeOpenApi -EnableSchemaValidation'
openApiComponentSchemaDoesNotExistExceptionMessage = Schemat komponentu OpenApi {0} nie istnieje.
openApiParameterRequiresNameExceptionMessage = Parametr OpenApi wymaga podania nazwy.
openApiLicenseObjectRequiresNameExceptionMessage = Obiekt OpenAPI 'license' wymaga właściwości 'name'. Użyj parametru -LicenseName.
parametersValueOrExternalValueMandatoryExceptionMessage = Parametry 'Value' lub 'ExternalValue' są obowiązkowe.
parametersMutuallyExclusiveExceptionMessage = Parametry '{0}' i '{1}' są wzajemnie wykluczające się.
maximumConcurrentWebSocketThreadsInvalidExceptionMessage = Maksymalna liczba jednoczesnych wątków WebSocket musi wynosić >=1, ale otrzymano: {0}
maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage = Maksymalna liczba jednoczesnych wątków WebSocket nie może być mniejsza niż minimum {0}, ale otrzymano: {1}
alreadyConnectedToWebSocketExceptionMessage = Już połączono z WebSocket o nazwie '{0}'
failedToConnectToWebSocketExceptionMessage = Nie udało się połączyć z WebSocket: {0}
verbNoLogicPassedExceptionMessage = [Czasownik] {0}: Nie przekazano logiki
scriptPathDoesNotExistExceptionMessage = Ścieżka skryptu nie istnieje: {0}
failedToImportModuleExceptionMessage = Nie udało się zaimportować modułu: {0}
modulePathDoesNotExistExceptionMessage = Ścieżka modułu nie istnieje: {0}
defaultValueNotBooleanOrEnumExceptionMessage = Wartość domyślna nie jest typu boolean i nie należy do enum.
propertiesTypeObjectAssociationExceptionMessage = Tylko właściwości typu Object mogą być powiązane z {0}.
invalidContentTypeForSchemaExceptionMessage = Nieprawidłowy 'content-type' znaleziony w schemacie: {0}
openApiRequestStyleInvalidForParameterExceptionMessage = Styl żądania OpenApi nie może być {0} dla parametru {1}.
pathParameterRequiresRequiredSwitchExceptionMessage = Jeśli lokalizacja parametru to 'Path', przełącznik 'Required' jest obowiązkowy.
operationIdMustBeUniqueForArrayExceptionMessage = OperationID: {0} musi być unikalny i nie może być zastosowany do tablicy.
operationIdMustBeUniqueExceptionMessage = OperationID: {0} musi być unikalny.
noOpenApiUrlSuppliedExceptionMessage = Nie dostarczono adresu URL OpenAPI dla {0}.
noTitleSuppliedForPageExceptionMessage = Nie dostarczono tytułu dla strony {0}.
noRoutePathSuppliedForPageExceptionMessage = Nie dostarczono ścieżki trasy dla strony {0}.
swaggerEditorDoesNotSupportOpenApi31ExceptionMessage = Ta wersja Swagger-Editor nie obsługuje OpenAPI 3.1
rapidPdfDoesNotSupportOpenApi31ExceptionMessage = Narzędzie do dokumentów RapidPdf nie obsługuje OpenAPI 3.1
definitionTagNotDefinedExceptionMessage = Etykieta definicji {0} nie jest zdefiniowana.
scopedVariableNotFoundExceptionMessage = Nie znaleziono zmiennej zakresu: {0}
noSecretVaultRegisteredExceptionMessage = Nie zarejestrowano Skarbca Tajemnic o nazwie '{0}'.
invalidStrictTransportSecurityDurationExceptionMessage = Nieprawidłowy czas trwania Strict-Transport-Security: {0}. Powinien być większy niż 0.
durationMustBeZeroOrGreaterExceptionMessage = Czas trwania musi wynosić 0 lub więcej, ale otrzymano: {0}s
taskAlreadyDefinedExceptionMessage = [Zadanie] {0}: Zadanie już zdefiniowane.
maximumConcurrentTasksInvalidExceptionMessage = Maksymalna liczba jednoczesnych zadań musi wynosić >=1, ale otrzymano: {0}
maximumConcurrentTasksLessThanMinimumExceptionMessage = Maksymalna liczba jednoczesnych zadań nie może być mniejsza niż minimum {0}, ale otrzymano: {1}
taskDoesNotExistExceptionMessage = Zadanie '{0}' nie istnieje.
cacheStorageNotFoundForRetrieveExceptionMessage = Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby pobrania elementu z pamięci podręcznej '{1}'.
cacheStorageNotFoundForSetExceptionMessage = Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby ustawienia elementu w pamięci podręcznej '{1}'.
cacheStorageNotFoundForExistsExceptionMessage = Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby sprawdzenia, czy element w pamięci podręcznej '{1}' istnieje.
cacheStorageNotFoundForRemoveExceptionMessage = Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby usunięcia elementu z pamięci podręcznej '{1}'.
cacheStorageNotFoundForClearExceptionMessage = Nie znaleziono magazynu pamięci podręcznej o nazwie '{0}' podczas próby wyczyszczenia pamięci podręcznej.
cacheStorageAlreadyExistsExceptionMessage = Magazyn pamięci podręcznej o nazwie '{0}' już istnieje.
pathToIconForGuiDoesNotExistExceptionMessage = Ścieżka do ikony dla GUI nie istnieje: {0}
invalidHostnameSuppliedExceptionMessage = Podano nieprawidłową nazwę hosta: {0}
endpointAlreadyDefinedExceptionMessage = Punkt końcowy o nazwie '{0}' został już zdefiniowany.
certificateExpiredExceptionMessage = Certyfikat '{0}' wygasł: {1}
endpointNotDefinedForRedirectingExceptionMessage = Nie zdefiniowano punktu końcowego o nazwie '{0}' do przekierowania.
fileWatcherAlreadyDefinedExceptionMessage = Obserwator plików o nazwie '{0}' został już zdefiniowany.
handlerAlreadyDefinedExceptionMessage = [{0}] {1}: Handler już zdefiniowany.
maxDaysInvalidExceptionMessage = MaxDays musi wynosić 0 lub więcej, ale otrzymano: {0}
maxSizeInvalidExceptionMessage = MaxSize musi wynosić 0 lub więcej, ale otrzymano: {0}
loggingMethodAlreadyDefinedExceptionMessage = Metoda logowania już zdefiniowana: {0}
loggingMethodRequiresValidScriptBlockExceptionMessage = Dostarczona metoda wyjściowa dla metody logowania '{0}' wymaga poprawnego ScriptBlock.
csrfCookieRequiresSecretExceptionMessage = Podczas używania ciasteczek do CSRF, wymagany jest Sekret. Możesz dostarczyć Sekret lub ustawić globalny sekret dla ciasteczek - (Set-PodeCookieSecret '<value>' -Global)
bodyParserAlreadyDefinedForContentTypeExceptionMessage = Parser treści dla typu zawartości {0} jest już zdefiniowany.
middlewareAlreadyDefinedExceptionMessage = [Middleware] {0}: Middleware już zdefiniowany.
parameterNotSuppliedInRequestExceptionMessage = Parametr o nazwie '{0}' nie został dostarczony w żądaniu lub nie ma dostępnych danych.
noDataForFileUploadedExceptionMessage = Brak danych dla pliku '{0}' przesłanego w żądaniu.
viewsFolderNameAlreadyExistsExceptionMessage = Nazwa folderu Widoków już istnieje: {0}
viewsPathDoesNotExistExceptionMessage = Ścieżka do Widoków nie istnieje: {0}
timerAlreadyDefinedExceptionMessage = [Timer] {0}: Timer już zdefiniowany.
timerParameterMustBeGreaterThanZeroExceptionMessage = [Timer] {0}: {1} musi być większy od 0.
timerDoesNotExistExceptionMessage = Timer '{0}' nie istnieje.
mutexAlreadyExistsExceptionMessage = Muteks o nazwie '{0}' już istnieje.
noMutexFoundExceptionMessage = Nie znaleziono muteksu o nazwie '{0}'.
failedToAcquireMutexOwnershipExceptionMessage = Nie udało się przejąć własności muteksu. Nazwa muteksu: {0}
semaphoreAlreadyExistsExceptionMessage = Semafor o nazwie '{0}' już istnieje.
failedToAcquireSemaphoreOwnershipExceptionMessage = Nie udało się przejąć własności semaforu. Nazwa semaforu: {0}
scheduleAlreadyDefinedExceptionMessage = [Harmonogram] {0}: Harmonogram już zdefiniowany.
scheduleCannotHaveNegativeLimitExceptionMessage = [Harmonogram] {0}: Nie może mieć ujemnego limitu.
scheduleEndTimeMustBeInFutureExceptionMessage = [Harmonogram] {0}: Wartość EndTime musi być w przyszłości.
scheduleStartTimeAfterEndTimeExceptionMessage = [Harmonogram] {0}: Nie może mieć 'StartTime' po 'EndTime'.
maximumConcurrentSchedulesInvalidExceptionMessage = Maksymalna liczba równoczesnych harmonogramów musi wynosić >=1, ale otrzymano: {0}
maximumConcurrentSchedulesLessThanMinimumExceptionMessage = Maksymalna liczba równoczesnych harmonogramów nie może być mniejsza niż minimalna liczba {0}, ale otrzymano: {1}
scheduleDoesNotExistExceptionMessage = Harmonogram '{0}' nie istnieje.
suppliedDateBeforeScheduleStartTimeExceptionMessage = Podana data jest wcześniejsza niż czas rozpoczęcia harmonogramu o {0}
suppliedDateAfterScheduleEndTimeExceptionMessage = Podana data jest późniejsza niż czas zakończenia harmonogramu o {0}
noSemaphoreFoundExceptionMessage = Nie znaleziono semaforu o nazwie '{0}'
noLogicPassedForRouteExceptionMessage = Brak logiki przekazanej dla trasy: {0}
noPathSuppliedForStaticRouteExceptionMessage = [{0}]: Brak dostarczonej ścieżki dla trasy statycznej.
sourcePathDoesNotExistForStaticRouteExceptionMessage = [{0})] {1}: Dostarczona ścieżka źródłowa dla trasy statycznej nie istnieje: {2}
noLogicPassedForMethodRouteExceptionMessage = [{0}] {1}: Brak logiki przekazanej.
moduleDoesNotContainFunctionExceptionMessage = Moduł {0} nie zawiera funkcji {1} do konwersji na trasę.
pageNameShouldBeAlphaNumericExceptionMessage = Nazwa strony powinna być poprawną wartością alfanumeryczną: {0}
filesHaveChangedMessage = Następujące pliki zostały zmienione:
multipleEndpointsForGuiMessage = Zdefiniowano wiele punktów końcowych, tylko pierwszy będzie używany dla GUI.
openingGuiMessage = Otwieranie GUI.
listeningOnEndpointsMessage = Nasłuchiwanie na następujących {0} punktach końcowych [{1} wątków]:
specificationMessage = Specyfikacja
documentationMessage = Dokumentacja
restartingServerMessage = Restartowanie serwera...
doneMessage = Gotowe
deprecatedTitleVersionDescriptionWarningMessage = OSTRZEŻENIE: Tytuł, Wersja i Opis w 'Enable-PodeOpenApi' są przestarzałe. Proszę użyć 'Add-PodeOAInfo' zamiast tego.
undefinedOpenApiReferencesMessage = Niezdefiniowane odwołania OpenAPI:
definitionTagMessage = Definicja {0}:
openApiGenerationDocumentErrorMessage = Błąd generowania dokumentu OpenAPI:
infoTitleMandatoryMessage = info.title jest obowiązkowe.
infoVersionMandatoryMessage = info.version jest obowiązkowe.
missingComponentsMessage = Brakujące komponenty
openApiInfoMessage = Informacje OpenAPI:
serverLoopingMessage = Pętla serwera co {0} sekund
iisShutdownMessage = (Zamykanie IIS)
terminatingMessage = Kończenie...
eolPowerShellWarningMessage = [OSTRZEŻENIE] Pode {0} nie był testowany na PowerShell {1}, ponieważ jest to wersja EOL.
untestedPowerShellVersionWarningMessage = [OSTRZEŻENIE] Pode {0} nie był testowany na PowerShell {1}, ponieważ nie był dostępny, gdy Pode został wydany.
'@