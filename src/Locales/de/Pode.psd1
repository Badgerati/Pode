@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'Die Schema-Validierung erfordert PowerShell Version 6.1.0 oder höher.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = 'Ein Pfad oder ScriptBlock ist erforderlich, um die benutzerdefinierten Zugriffswerte zu beziehen.'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID: {0} muss eindeutig sein und kann nicht auf ein Array angewendet werden.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "Ein Endpunkt mit dem Namen '{0}' wurde nicht für die Weiterleitung definiert."
    filesHaveChangedMessage                                           = 'Die folgenden Dateien wurden geändert:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'Das IIS-ASPNETCORE_TOKEN fehlt.'
    minValueGreaterThanMaxExceptionMessage                            = 'Der Mindestwert für {0} darf nicht größer als der Maximalwert sein.'
    noLogicPassedForRouteExceptionMessage                             = 'Keine Logik für Route übergeben: {0}'
    scriptPathDoesNotExistExceptionMessage                            = 'Der Skriptpfad existiert nicht: {0}'
    mutexAlreadyExistsExceptionMessage                                = 'Ein Mutex mit folgendem Namen existiert bereits: {0}'
    listeningOnEndpointsMessage                                       = 'Lauschen auf den folgenden {0} Endpunkt(en) [{1} Thread(s)]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = 'Die Funktion {0} wird in einem serverlosen Kontext nicht unterstützt.'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = 'Es wurde keine JWT-Signatur erwartet.'
    secretAlreadyMountedExceptionMessage                              = "Ein Geheimnis mit dem Namen '{0}' wurde bereits eingebunden."
    failedToAcquireLockExceptionMessage                               = 'Sperre des Objekts konnte nicht erworben werden.'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: Kein Pfad für statische Route angegeben.'
    invalidHostnameSuppliedExceptionMessage                           = 'Der angegebene Hostname ist ungültig: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = 'Authentifizierungsmethode bereits definiert: {0}'
    csrfCookieRequiresSecretExceptionMessage                          = "Beim Verwenden von Cookies für CSRF ist ein Geheimnis erforderlich. Sie können ein Geheimnis angeben oder das globale Cookie-Geheimnis festlegen - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = 'Ein nicht leerer ScriptBlock ist erforderlich, um eine Seitenroute zu erstellen.'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "Der Parameter 'NoProperties' schließt 'Properties', 'MinProperties' und 'MaxProperties' gegenseitig aus."
    incompatiblePodeDllExceptionMessage                               = 'Eine vorhandene inkompatible Pode.DLL-Version {0} ist geladen. Version {1} wird benötigt. Öffnen Sie eine neue PowerShell/pwsh-Sitzung und versuchen Sie es erneut.'
    accessMethodDoesNotExistExceptionMessage                          = 'Zugriffsmethode existiert nicht: {0}.'
    scheduleAlreadyDefinedExceptionMessage                            = '[Aufgabenplaner] {0}: Aufgabenplaner bereits definiert.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = 'Der Sekundenwert darf für {0} nicht 0 oder weniger sein.'
    pathToLoadNotFoundExceptionMessage                                = 'Pfad zum Laden von {0} nicht gefunden: {1}'
    failedToImportModuleExceptionMessage                              = 'Modulimport fehlgeschlagen: {0}'
    endpointNotExistExceptionMessage                                  = "Der Endpunkt mit dem Protokoll '{0}' und der Adresse '{1}' oder der lokalen Adresse '{2}' existiert nicht"
    terminatingMessage                                                = 'Beenden...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = 'Keine Befehle zur Umwandlung in Routen bereitgestellt.'
    invalidTaskTypeExceptionMessage                                   = 'Aufgabentyp ist ungültig, erwartet entweder [System.Threading.Tasks.Task] oder [hashtable]'
    alreadyConnectedToWebSocketExceptionMessage                       = "Bereits mit dem WebSocket mit dem Namen '{0}' verbunden"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'Die CRLF-Nachrichtenendprüfung wird nur auf TCP-Endpunkten unterstützt.'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema' muss mit 'Enable-PodeOpenApi -EnableSchemaValidation' aktiviert werden."
    adModuleNotInstalledExceptionMessage                              = 'Das Active Directory-Modul ist nicht installiert.'
    cronExpressionInvalidExceptionMessage                             = 'Die Cron-Ausdruck sollte nur aus 5 Teilen bestehen: {0}'
    noSessionToSetOnResponseExceptionMessage                          = 'Keine Sitzung verfügbar, die auf die Antwort gesetzt werden kann.'
    valueOutOfRangeExceptionMessage                                   = "Wert '{0}' für {1} ist ungültig, sollte zwischen {2} und {3} liegen"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'Logging-Methode bereits definiert: {0}'
    noSecretForHmac256ExceptionMessage                                = 'Es wurde kein Geheimnis für den HMAC256-Hash angegeben.'
    eolPowerShellWarningMessage                                       = '[WARNUNG] Pode {0} wurde nicht auf PowerShell {1} getestet, da es das Ende des Lebenszyklus erreicht hat.'
    runspacePoolFailedToLoadExceptionMessage                          = '{0} RunspacePool konnte nicht geladen werden.'
    noEventRegisteredExceptionMessage                                 = 'Kein Ereignis {0} registriert: {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[Aufgabenplaner] {0}: Kann kein negatives Limit haben.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'Der OpenApi-Anfragestil kann für einen {1}-Parameter nicht {0} sein.'
    openApiDocumentNotCompliantExceptionMessage                       = 'Das OpenAPI-Dokument ist nicht konform.'
    taskDoesNotExistExceptionMessage                                  = "Aufgabe '{0}' existiert nicht."
    scopedVariableNotFoundExceptionMessage                            = 'Bereichsvariable nicht gefunden: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = 'Sitzungen sind erforderlich, um CSRF zu verwenden, es sei denn, Sie möchten Cookies verwenden.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'Ein nicht leerer ScriptBlock ist für die Protokollierungsmethode erforderlich.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = 'Wenn Anmeldeinformationen übergeben werden, wird das *-Wildcard für Header als Literalzeichenfolge und nicht als Platzhalter verwendet.'
    podeNotInitializedExceptionMessage                                = 'Pode wurde nicht initialisiert.'
    multipleEndpointsForGuiMessage                                    = 'Mehrere Endpunkte definiert, es wird nur der erste für die GUI verwendet.'
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID: {0} muss eindeutig sein.'
    invalidJsonJwtExceptionMessage                                    = 'Ungültiger JSON-Wert in JWT gefunden'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'Kein Algorithmus im JWT-Header angegeben.'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'Die Eigenschaft OpenApi-Version ist obligatorisch.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = 'Der Grenzwert darf für {0} nicht 0 oder weniger sein.'
    timerDoesNotExistExceptionMessage                                 = "Timer '{0}' existiert nicht."
    openApiGenerationDocumentErrorMessage                             = 'Fehler beim Generieren des OpenAPI-Dokuments:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "Die Route '[{0}] {1}' enthält bereits einen benutzerdefinierten Zugriff mit dem Namen '{2}'."
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = 'Die maximale Anzahl gleichzeitiger WebSocket-Threads darf nicht kleiner als das Minimum von {0} sein, aber erhalten: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: Middleware bereits definiert.'
    invalidAtomCharacterExceptionMessage                              = 'Ungültiges Atomzeichen: {0}'
    invalidCronAtomFormatExceptionMessage                             = 'Ungültiges Cron-Atom-Format gefunden: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "Der Cache-Speicher mit dem Namen '{0}' wurde nicht gefunden, als versucht wurde, das zwischengespeicherte Element '{1}' abzurufen."
    headerMustHaveNameInEncodingContextExceptionMessage               = 'Ein Header muss einen Namen haben, wenn er im Codierungskontext verwendet wird.'
    moduleDoesNotContainFunctionExceptionMessage                      = 'Modul {0} enthält keine Funktion {1} zur Umwandlung in eine Route.'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'Der Pfad zum Symbol für die GUI existiert nicht: {0}'
    noTitleSuppliedForPageExceptionMessage                            = 'Kein Titel für die Seite {0} angegeben.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'Zertifikat für Nicht-HTTPS/WSS-Endpunkt bereitgestellt.'
    cannotLockNullObjectExceptionMessage                              = 'Kann ein null-Objekt nicht sperren.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui ist derzeit nur für Windows PowerShell und PowerShell 7+ unter Windows verfügbar.'
    unlockSecretButNoScriptBlockExceptionMessage                      = 'Unlock secret für benutzerdefinierten Secret Vault-Typ angegeben, aber kein Unlock ScriptBlock bereitgestellt.'
    invalidIpAddressExceptionMessage                                  = 'Die angegebene IP-Adresse ist ungültig: {0}'
    maxDaysInvalidExceptionMessage                                    = 'MaxDays muss 0 oder größer sein, aber erhalten: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "Kein Remove ScriptBlock für das Entfernen von Geheimnissen im Tresor '{0}' bereitgestellt."
    noSecretExpectedForNoSignatureExceptionMessage                    = 'Es wurde erwartet, dass kein Geheimnis für keine Signatur angegeben wird.'
    noCertificateFoundExceptionMessage                                = "Es wurde kein Zertifikat in {0}{1} für '{2}' gefunden."
    minValueInvalidExceptionMessage                                   = "Der Mindestwert '{0}' für {1} ist ungültig, sollte größer oder gleich {2} sein"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = 'Der Zugriff erfordert eine Authentifizierung auf den Routen.'
    noSecretForHmac384ExceptionMessage                                = 'Es wurde kein Geheimnis für den HMAC384-Hash angegeben.'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'Die Unterstützung der lokalen Windows-Authentifizierung gilt nur für Windows.'
    definitionTagNotDefinedExceptionMessage                           = 'Definitionstag {0} ist nicht definiert.'
    noComponentInDefinitionExceptionMessage                           = 'Es ist keine Komponente des Typs {0} mit dem Namen {1} in der Definition {2} verfügbar.'
    noSmtpHandlersDefinedExceptionMessage                             = 'Es wurden keine SMTP-Handler definiert.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'Session Middleware wurde bereits initialisiert.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "Die wiederverwendbare Komponente 'pathItems' ist in OpenAPI v3.0 nicht verfügbar."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = 'Das *-Wildcard für Header ist nicht mit dem AutoHeaders-Schalter kompatibel.'
    noDataForFileUploadedExceptionMessage                             = "Keine Daten für die Datei '{0}' wurden in der Anfrage hochgeladen."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSE kann nur auf Anfragen mit einem Accept-Header-Wert von text/event-stream konfiguriert werden.'
    noSessionAvailableToSaveExceptionMessage                          = 'Keine Sitzung verfügbar zum Speichern.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "Wenn der Parameterstandort 'Path' ist, ist der Schalterparameter 'Required' erforderlich."
    noOpenApiUrlSuppliedExceptionMessage                              = 'Keine OpenAPI-URL für {0} angegeben.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = 'Maximale gleichzeitige Zeitpläne müssen >=1 sein, aber erhalten: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Snapins werden nur in Windows PowerShell unterstützt.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = 'Das Protokollieren im Ereignisanzeige wird nur auf Windows unterstützt.'
    parametersMutuallyExclusiveExceptionMessage                       = "Die Parameter '{0}' und '{1}' schließen sich gegenseitig aus."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = 'Das PathItems-Feature wird in OpenAPI v3.0.x nicht unterstützt.'
    openApiParameterRequiresNameExceptionMessage                      = 'Der OpenApi-Parameter erfordert einen angegebenen Namen.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = 'Die maximale Anzahl gleichzeitiger Aufgaben darf nicht kleiner als das Minimum von {0} sein, aber erhalten: {1}'
    noSemaphoreFoundExceptionMessage                                  = "Kein Semaphor mit dem Namen '{0}' gefunden."
    singleValueForIntervalExceptionMessage                            = 'Sie können nur einen einzelnen {0}-Wert angeben, wenn Sie Intervalle verwenden.'
    jwtNotYetValidExceptionMessage                                    = 'Der JWT ist noch nicht gültig.'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[Verb] {0}: Bereits für {1} definiert.'
    noSecretNamedMountedExceptionMessage                              = "Kein Geheimnis mit dem Namen '{0}' wurde eingebunden."
    moduleOrVersionNotFoundExceptionMessage                           = 'Modul oder Version nicht gefunden auf {0}: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'Kein Skriptblock angegeben.'
    noSecretVaultRegisteredExceptionMessage                           = "Kein Geheimnistresor mit dem Namen '{0}' registriert."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'Ein Name ist für den Endpunkt erforderlich, wenn der RedirectTo-Parameter angegeben ist.'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "Das OpenAPI-Objekt 'license' erfordert die Eigenschaft 'name'. Verwenden Sie den Parameter -LicenseName."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: Der angegebene Quellpfad für die statische Route existiert nicht: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = 'Kein Name für die Trennung vom WebSocket angegeben.'
    certificateExpiredExceptionMessage                                = "Das Zertifikat '{0}' ist abgelaufen: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = 'Das Ablaufdatum zum Entsperren des Geheimnis-Tresors liegt in der Vergangenheit (UTC): {0}'
    invalidWebExceptionTypeExceptionMessage                           = 'Die Ausnahme hat einen ungültigen Typ. Er sollte entweder WebException oder HttpRequestException sein, aber es wurde {0} erhalten'
    invalidSecretValueTypeExceptionMessage                            = 'Der Geheimniswert hat einen ungültigen Typ. Erwartete Typen: String, SecureString, HashTable, Byte[] oder PSCredential. Aber erhalten wurde: {0}.'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = 'Der explizite TLS-Modus wird nur auf SMTPS- und TCPS-Endpunkten unterstützt.'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "Der Parameter 'DiscriminatorMapping' kann nur verwendet werden, wenn 'DiscriminatorProperty' vorhanden ist."
    scriptErrorExceptionMessage                                       = "Fehler '{0}' im Skript {1} {2} (Zeile {3}) Zeichen {4} beim Ausführen von {5} auf {6} Objekt '{7}' Klasse: {8} Basisklasse: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = 'Ein Intervallwert kann nicht für jedes Quartal angegeben werden.'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[Aufgabenplaner] {0}: Der Wert für EndTime muss in der Zukunft liegen.'
    invalidJwtSignatureSuppliedExceptionMessage                       = 'Ungültige JWT-Signatur angegeben.'
    noSetScriptBlockForVaultExceptionMessage                          = "Kein Set ScriptBlock für das Aktualisieren/Erstellen von Geheimnissen im Tresor '{0}' bereitgestellt."
    accessMethodNotExistForMergingExceptionMessage                    = 'Zugriffsmethode zum Zusammenführen nicht vorhanden: {0}.'
    defaultAuthNotInListExceptionMessage                              = "Die Standardauthentifizierung '{0}' befindet sich nicht in der angegebenen Authentifizierungsliste."
    parameterHasNoNameExceptionMessage                                = "Der Parameter hat keinen Namen. Bitte geben Sie dieser Komponente einen Namen mit dem 'Name'-Parameter."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: Bereits für {2} definiert.'
    fileWatcherAlreadyDefinedExceptionMessage                         = "Ein Dateiwächter mit dem Namen '{0}' wurde bereits definiert."
    noServiceHandlersDefinedExceptionMessage                          = 'Es wurden keine Service-Handler definiert.'
    secretRequiredForCustomSessionStorageExceptionMessage             = 'Ein Geheimnis ist erforderlich, wenn benutzerdefinierter Sitzungspeicher verwendet wird.'
    secretManagementModuleNotInstalledExceptionMessage                = 'Das Modul Microsoft.PowerShell.SecretManagement ist nicht installiert.'
    noPathSuppliedForRouteExceptionMessage                            = 'Kein Pfad für die Route bereitgestellt.'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "Die Validierung eines Schemas, das 'anyof' enthält, wird nicht unterstützt."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'Die IIS-Authentifizierungsunterstützung gilt nur für Windows.'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'OAuth2 InnerScheme kann nur entweder Basic oder Form-Authentifizierung sein, aber erhalten: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = 'Kein Routenpfad für die Seite {0} angegeben.'
    cacheStorageNotFoundForExistsExceptionMessage                     = "Der Cache-Speicher mit dem Namen '{0}' wurde nicht gefunden, als versucht wurde zu überprüfen, ob das zwischengespeicherte Element '{1}' existiert."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: Handler bereits definiert.'
    sessionsNotConfiguredExceptionMessage                             = 'Sitzungen wurden nicht konfiguriert.'
    propertiesTypeObjectAssociationExceptionMessage                   = 'Nur Eigenschaften vom Typ Object können mit {0} verknüpft werden.'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = 'Sitzungen sind erforderlich, um die sitzungsbeständige Authentifizierung zu verwenden.'
    invalidPathWildcardOrDirectoryExceptionMessage                    = 'Der angegebene Pfad darf kein Platzhalter oder Verzeichnis sein: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = 'Zugriffsmethode bereits definiert: {0}.'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "Die Parameter 'Value' oder 'ExternalValue' sind obligatorisch."
    maximumConcurrentTasksInvalidExceptionMessage                     = 'Die maximale Anzahl gleichzeitiger Aufgaben muss >=1 sein, aber erhalten: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = 'Die Eigenschaft kann nicht erstellt werden, weil kein Typ definiert ist.'
    authMethodNotExistForMergingExceptionMessage                      = 'Die Authentifizierungsmethode existiert nicht zum Zusammenführen: {0}'
    maxValueInvalidExceptionMessage                                   = "Der Maximalwert '{0}' für {1} ist ungültig, sollte kleiner oder gleich {2} sein"
    endpointAlreadyDefinedExceptionMessage                            = "Ein Endpunkt mit dem Namen '{0}' wurde bereits definiert."
    eventAlreadyRegisteredExceptionMessage                            = 'Ereignis {0} bereits registriert: {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "Ein Parameter namens '{0}' wurde in der Anfrage nicht angegeben oder es sind keine Daten verfügbar."
    cacheStorageNotFoundForSetExceptionMessage                        = "Der Cache-Speicher mit dem Namen '{0}' wurde nicht gefunden, als versucht wurde, das zwischengespeicherte Element '{1}' zu setzen."
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: Bereits definiert.'
    valueForUsingVariableNotFoundExceptionMessage                     = "Der Wert für '`$using:{0}' konnte nicht gefunden werden."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = 'Das Dokumentationstool RapidPdf unterstützt OpenAPI 3.1 nicht.'
    oauth2ClientSecretRequiredExceptionMessage                        = 'OAuth2 erfordert ein Client Secret, wenn PKCE nicht verwendet wird.'
    invalidBase64JwtExceptionMessage                                  = 'Ungültiger Base64-codierter Wert in JWT gefunden'
    noSessionToCalculateDataHashExceptionMessage                      = 'Keine Sitzung verfügbar, um den Datenhash zu berechnen.'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "Der Cache-Speicher mit dem Namen '{0}' wurde nicht gefunden, als versucht wurde, das zwischengespeicherte Element '{1}' zu entfernen."
    csrfMiddlewareNotInitializedExceptionMessage                      = 'CSRF Middleware wurde nicht initialisiert.'
    infoTitleMandatoryMessage                                         = 'info.title ist obligatorisch.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = 'Der Typ {0} kann nur einem Objekt zugeordnet werden.'
    userFileDoesNotExistExceptionMessage                              = 'Die Benutzerdaten-Datei existiert nicht: {0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = 'Der Route-Parameter benötigt einen gültigen, nicht leeren ScriptBlock.'
    nextTriggerCalculationErrorExceptionMessage                       = 'Es scheint, als ob beim Berechnen des nächsten Trigger-Datums und der nächsten Triggerzeit etwas schief gelaufen wäre: {0}'
    cannotLockValueTypeExceptionMessage                               = 'Kann [ValueType] nicht sperren.'
    failedToCreateOpenSslCertExceptionMessage                         = 'Erstellung des OpenSSL-Zertifikats fehlgeschlagen: {0}.'
    jwtExpiredExceptionMessage                                        = 'Der JWT ist abgelaufen.'
    openingGuiMessage                                                 = 'Die GUI wird geöffnet.'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = 'Mehrfachtyp-Eigenschaften erfordern OpenApi-Version 3.1 oder höher.'
    noNameForWebSocketRemoveExceptionMessage                          = 'Kein Name für das Entfernen des WebSocket angegeben.'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize muss 0 oder größer sein, aber erhalten: {0}'
    iisShutdownMessage                                                = '(IIS Herunterfahren)'
    cannotUnlockValueTypeExceptionMessage                             = 'Kann [ValueType] nicht entsperren.'
    noJwtSignatureForAlgorithmExceptionMessage                        = 'Keine JWT-Signatur für {0} angegeben.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = 'Die maximale Anzahl gleichzeitiger WebSocket-Threads muss >=1 sein, aber erhalten: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = 'Die Bestätigungsnachricht wird nur auf SMTP- und TCP-Endpunkten unterstützt.'
    failedToConnectToUrlExceptionMessage                              = 'Verbindung mit der URL fehlgeschlagen: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = 'Fehler beim Erwerb des Mutex-Besitzes. Mutex-Name: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'Sitzungen sind erforderlich, um OAuth2 mit PKCE zu verwenden.'
    failedToConnectToWebSocketExceptionMessage                        = 'Verbindung zum WebSocket fehlgeschlagen: {0}'
    unsupportedObjectExceptionMessage                                 = 'Nicht unterstütztes Objekt'
    failedToParseAddressExceptionMessage                              = "Konnte '{0}' nicht als gültige IP/Host:Port-Adresse analysieren"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'Muss mit Administratorrechten ausgeführt werden, um auf Nicht-Localhost-Adressen zu lauschen.'
    specificationMessage                                              = 'Spezifikation'
    cacheStorageNotFoundForClearExceptionMessage                      = "Der Cache-Speicher mit dem Namen '{0}' wurde nicht gefunden, als versucht wurde, den Cache zu leeren."
    restartingServerMessage                                           = 'Server wird neu gestartet...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "Ein Intervall kann nicht angegeben werden, wenn der Parameter 'Every' auf None gesetzt ist."
    unsupportedJwtAlgorithmExceptionMessage                           = 'Der JWT-Algorithmus wird derzeit nicht unterstützt: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'WebSockets wurden nicht konfiguriert, um Signalnachrichten zu senden.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = 'Eine angegebene Hashtable-Middleware enthält einen ungültigen Logik-Typ. Erwartet wurde ein ScriptBlock, aber erhalten wurde: {0}.'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = 'Maximale gleichzeitige Zeitpläne dürfen nicht kleiner als das Minimum von {0} sein, aber erhalten: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = 'Fehler beim Erwerb des Semaphor-Besitzes. Semaphor-Name: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = 'Die Eigenschaftsparameter können nicht verwendet werden, wenn die Eigenschaft keinen Namen hat.'
    customSessionStorageMethodNotImplementedExceptionMessage          = "Der benutzerdefinierte Sitzungspeicher implementiert die erforderliche Methode '{0}()' nicht."
    authenticationMethodDoesNotExistExceptionMessage                  = 'Authentifizierungsmethode existiert nicht: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'Das Webhooks-Feature wird in OpenAPI v3.0.x nicht unterstützt.'
    invalidContentTypeForSchemaExceptionMessage                       = "Ungültiger 'content-type' im Schema gefunden: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "Kein Unlock ScriptBlock für das Entsperren des Tresors '{0}' bereitgestellt."
    definitionTagMessage                                              = 'Definition {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'Fehler beim Öffnen des Runspace-Pools: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'Fehler beim Schließen des RunspacePools: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[Verb] {0}: Keine Logik übergeben'
    noMutexFoundExceptionMessage                                      = "Kein Mutex mit dem Namen '{0}' gefunden."
    documentationMessage                                              = 'Dokumentation'
    timerAlreadyDefinedExceptionMessage                               = '[Timer] {0}: Timer bereits definiert.'
    invalidPortExceptionMessage                                       = 'Der Port kann nicht negativ sein: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = 'Der Name des Ansichtsordners existiert bereits: {0}'
    noNameForWebSocketResetExceptionMessage                           = 'Kein Name für das Zurücksetzen des WebSocket angegeben.'
    mergeDefaultAuthNotInListExceptionMessage                         = "Die MergeDefault-Authentifizierung '{0}' befindet sich nicht in der angegebenen Authentifizierungsliste."
    descriptionRequiredExceptionMessage                               = 'Eine Beschreibung ist erforderlich.'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'Der Seitenname sollte einen gültigen alphanumerischen Wert haben: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = 'Der Standardwert ist kein Boolean und gehört nicht zum Enum.'
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'Das OpenApi-Komponentenschema {0} existiert nicht.'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[Timer] {0}: {1} muss größer als 0 sein.'
    taskTimedOutExceptionMessage                                      = 'Aufgabe ist nach {0}ms abgelaufen.'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = '[Aufgabenplaner] {0}: StartTime kann nicht nach EndTime liegen.'
    infoVersionMandatoryMessage                                       = 'info.version ist obligatorisch.'
    cannotUnlockNullObjectExceptionMessage                            = 'Kann ein null-Objekt nicht entsperren.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = 'Ein nicht leerer ScriptBlock ist für das benutzerdefinierte Authentifizierungsschema erforderlich.'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = 'Für die Authentifizierungsmethode ist ein nicht leerer ScriptBlock erforderlich.'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "Die Validierung eines Schemas, das 'oneof' enthält, wird nicht unterstützt."
    routeParameterCannotBeNullExceptionMessage                        = "Der Parameter 'Route' darf nicht null sein."
    cacheStorageAlreadyExistsExceptionMessage                         = "Ein Cache-Speicher mit dem Namen '{0}' existiert bereits."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "Die angegebene Ausgabemethode für die Logging-Methode '{0}' erfordert einen gültigen ScriptBlock."
    scopedVariableAlreadyDefinedExceptionMessage                      = 'Die Bereichsvariable ist bereits definiert: {0}.'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = 'OAuth2 erfordert die Angabe einer Autorisierungs-URL.'
    pathNotExistExceptionMessage                                      = 'Pfad existiert nicht: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = 'Es wurde kein Domänenservername für die Windows-AD-Authentifizierung angegeben.'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = 'Das angegebene Datum liegt nach der Endzeit des Aufgabenplaners bei {0}'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = 'Das *-Wildcard für Methoden ist nicht mit dem AutoMethods-Schalter kompatibel.'
    cannotSupplyIntervalForYearExceptionMessage                       = 'Ein Intervallwert kann nicht für jedes Jahr angegeben werden.'
    missingComponentsMessage                                          = 'Fehlende Komponente(n)'
    invalidStrictTransportSecurityDurationExceptionMessage            = 'Ungültige Strict-Transport-Security-Dauer angegeben: {0}. Sie sollte größer als 0 sein.'
    noSecretForHmac512ExceptionMessage                                = 'Es wurde kein Geheimnis für den HMAC512-Hash angegeben.'
    daysInMonthExceededExceptionMessage                               = '{0} hat nur {1} Tage, aber {2} wurden angegeben'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'Ein nicht leerer ScriptBlock ist für die benutzerdefinierte Protokollierungsmethode erforderlich.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = 'Das Encoding-Attribut gilt nur für multipart und application/x-www-form-urlencoded Anfragekörper.'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = 'Das angegebene Datum liegt vor der Startzeit des Aufgabenplaners bei {0}'
    unlockSecretRequiredExceptionMessage                              = "Eine 'UnlockSecret'-Eigenschaft ist erforderlich, wenn Microsoft.PowerShell.SecretStore verwendet wird."
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: Keine Logik übergeben.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = 'Für den Inhaltstyp {0} ist bereits ein Body-Parser definiert.'
    invalidJwtSuppliedExceptionMessage                                = 'Ungültiger JWT angegeben.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'Sitzungen sind erforderlich, um Flash-Nachrichten zu verwenden.'
    semaphoreAlreadyExistsExceptionMessage                            = 'Ein Semaphor mit folgendem Namen existiert bereits: {0}'
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = 'Ungültiger JWT-Header-Algorithmus angegeben.'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "Der OAuth2-Anbieter unterstützt den für die Verwendung eines InnerScheme erforderlichen 'password'-Grant-Typ nicht."
    invalidAliasFoundExceptionMessage                                 = 'Ungültiges {0}-Alias gefunden: {1}'
    scheduleDoesNotExistExceptionMessage                              = "Aufgabenplaner '{0}' existiert nicht."
    accessMethodNotExistExceptionMessage                              = 'Zugriffsmethode nicht vorhanden: {0}.'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "Der OAuth2-Anbieter unterstützt den 'code'-Antworttyp nicht."
    untestedPowerShellVersionWarningMessage                           = '[WARNUNG] Pode {0} wurde nicht auf PowerShell {1} getestet, da diese Version bei der Veröffentlichung von Pode nicht verfügbar war.'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "Ein Geheimtresor mit dem Namen '{0}' wurde bereits beim automatischen Importieren von Geheimtresoren registriert."
    schemeRequiresValidScriptBlockExceptionMessage                    = "Das bereitgestellte Schema für den Authentifizierungsvalidator '{0}' erfordert einen gültigen ScriptBlock."
    serverLoopingMessage                                              = 'Server-Schleife alle {0} Sekunden'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'Zertifikat-Thumbprints/Name werden nur unter Windows unterstützt.'
    sseConnectionNameRequiredExceptionMessage                         = "Ein SSE-Verbindungsname ist erforderlich, entweder von -Name oder `$WebEvent.Sse.Namee"
    invalidMiddlewareTypeExceptionMessage                             = 'Eines der angegebenen Middleware-Objekte ist ein ungültiger Typ. Erwartet wurde entweder ein ScriptBlock oder ein Hashtable, aber erhalten wurde: {0}.'
    noSecretForJwtSignatureExceptionMessage                           = 'Es wurde kein Geheimnis für die JWT-Signatur angegeben.'
    modulePathDoesNotExistExceptionMessage                            = 'Der Modulpfad existiert nicht: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[Aufgabe] {0}: Aufgabe bereits definiert.'
    verbAlreadyDefinedExceptionMessage                                = '[Verb] {0}: Bereits definiert.'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'Clientzertifikate werden nur auf HTTPS-Endpunkten unterstützt.'
    endpointNameNotExistExceptionMessage                              = "Der Endpunkt mit dem Namen '{0}' existiert nicht"
    middlewareNoLogicSuppliedExceptionMessage                         = '[Middleware]: Kein Logik-ScriptBlock bereitgestellt.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'Ein ScriptBlock ist erforderlich, um mehrere authentifizierte Benutzer zu einem Objekt zusammenzuführen, wenn Valid All ist.'
    secretVaultAlreadyRegisteredExceptionMessage                      = "Ein Geheimnis-Tresor mit dem Namen '{0}' wurde bereits registriert{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "WARNUNG: Titel, Version und Beschreibung in 'Enable-PodeOpenApi' sind veraltet. Bitte verwenden Sie stattdessen 'Add-PodeOAInfo'."
    undefinedOpenApiReferencesMessage                                 = 'Nicht definierte OpenAPI-Referenzen:'
    doneMessage                                                       = 'Fertig'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = 'Diese Version des Swagger-Editors unterstützt OpenAPI 3.1 nicht.'
    durationMustBeZeroOrGreaterExceptionMessage                       = 'Die Dauer muss 0 oder größer sein, aber erhalten: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = 'Der Ansichtsordnerpfad existiert nicht: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "Der Parameter 'Discriminator' ist nicht mit 'allOf' kompatibel."
    noNameForWebSocketSendMessageExceptionMessage                     = 'Kein Name für das Senden einer Nachricht an den WebSocket angegeben.'
    hashtableMiddlewareNoLogicExceptionMessage                        = 'Eine angegebene Hashtable-Middleware enthält keine definierte Logik.'
    openApiInfoMessage                                                = 'OpenAPI-Informationen:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "Das bereitgestellte '{0}'-Schema für den Authentifizierungsvalidator '{1}' erfordert einen gültigen ScriptBlock."
    sseFailedToBroadcastExceptionMessage                              = 'SSE konnte aufgrund des definierten SSE-Broadcast-Levels für {0}: {1} nicht übertragen werden.'
    adModuleWindowsOnlyExceptionMessage                               = 'Active Directory-Modul nur unter Windows verfügbar.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = 'Ungültige Access-Control-Max-Age-Dauer angegeben: {0}. Sollte größer als 0 sein.'
    openApiDefinitionAlreadyExistsExceptionMessage                    = 'Die OpenAPI-Definition mit dem Namen {0} existiert bereits.'
    renamePodeOADefinitionTagExceptionMessage                     = "Rename-PodeOADefinitionTag kann nicht innerhalb eines 'ScriptBlock' von Select-PodeOADefinition verwendet werden."
    fnDoesNotAcceptArrayAsPipelineInputExceptionMessage               = "Die Funktion '{0}' akzeptiert kein Array als Pipeline-Eingabe."
    loggingAlreadyEnabledExceptionMessage                             = "Das Logging '{0}' wurde bereits aktiviert."
    invalidEncodingExceptionMessage                                   = 'Ungültige Codierung: {0}'
    syslogProtocolExceptionMessage                                    = 'Das Syslog-Protokoll kann nur RFC3164 oder RFC5424 verwenden.'
}