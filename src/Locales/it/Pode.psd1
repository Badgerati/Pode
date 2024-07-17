@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'La convalida dello schema richiede PowerShell versione 6.1.0 o superiore.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = 'È necessario un percorso o un ScriptBlock per ottenere i valori di accesso personalizzati.'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID: {0} deve essere univoco e non può essere applicato a una matrice.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "Non è stato definito un endpoint denominato '{0}' per il reindirizzamento."
    filesHaveChangedMessage                                           = 'I seguenti file sono stati modificati:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'IIS ASPNETCORE_TOKEN è mancante.'
    minValueGreaterThanMaxExceptionMessage                            = 'Il valore minimo per {0} non deve essere maggiore del valore massimo.'
    noLogicPassedForRouteExceptionMessage                             = "Nessuna logica passata per la 'route': {0}"
    scriptPathDoesNotExistExceptionMessage                            = 'Il percorso dello script non esiste: {0}'
    mutexAlreadyExistsExceptionMessage                                = 'Un mutex con il seguente nome esiste già: {0}'
    listeningOnEndpointsMessage                                       = 'In ascolto sui seguenti {0} endpoint [{1} thread]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = "La funzione {0} non è supportata in un contesto 'serverless'."
    expectedNoJwtSignatureSuppliedExceptionMessage                    = 'La firma JWT è inaspettata.'
    secretAlreadyMountedExceptionMessage                              = "Un 'Secret' con il nome '{0}' è già stato montato."
    failedToAcquireLockExceptionMessage                               = "Impossibile acquisire un blocco sull'oggetto."
    noPathSuppliedForStaticRouteExceptionMessage                      = "[{0}]: Nessun percorso fornito per la 'route' statica."
    invalidHostnameSuppliedExceptionMessage                           = 'Nome host fornito non valido: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = 'Metodo di autenticazione già definito: {0}'
    csrfCookieRequiresSecretExceptionMessage                          = "Quando si usano i cookie per CSRF, è necessario un 'Secret'. Puoi fornire uno o impostare il 'Secret' a livello globale - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = "È richiesto uno 'ScriptBlock' non vuoto per creare una 'route'."
    noPropertiesMutuallyExclusiveExceptionMessage                     = "Il parametro 'NoProperties' è mutuamente esclusivo con 'Properties', 'MinProperties' e 'MaxProperties'."
    incompatiblePodeDllExceptionMessage                               = "È caricata una versione incompatibile esistente di 'Pode.DLL' {0}. È richiesta la versione {1}. Apri una nuova sessione Powershell/pwsh e riprova."
    accessMethodDoesNotExistExceptionMessage                          = 'Il metodo di accesso non esiste: {0}.'
    scheduleAlreadyDefinedExceptionMessage                            = '[Schedulatore] {0}: Pianificazione già definita.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = 'Il valore dei secondi non può essere 0 o inferiore per {0}'
    pathToLoadNotFoundExceptionMessage                                = 'Percorso per caricare {0} non trovato: {1}'
    failedToImportModuleExceptionMessage                              = 'Importazione del modulo non riuscita: {0}'
    endpointNotExistExceptionMessage                                  = "'Endpoint' con protocollo '{0}' e indirizzo '{1}' o indirizzo locale '{2}' non esiste."
    terminatingMessage                                                = 'Terminazione...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = "Nessun comando fornito per convertirlo in 'route'."
    invalidTaskTypeExceptionMessage                                   = 'Il tipo di attività non è valido, previsto [System.Threading.Tasks.Task] o [hashtable].'
    alreadyConnectedToWebSocketExceptionMessage                       = "Già connesso al WebSocket con il nome '{0}'"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'Il controllo di fine messaggio CRLF è supportato solo sugli endpoint TCP.'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema' deve essere abilitato utilizzando 'Enable-PodeOpenApi -EnableSchemaValidation'"
    adModuleNotInstalledExceptionMessage                              = 'Il modulo Active Directory non è installato.'
    cronExpressionInvalidExceptionMessage                             = "L'espressione Cron dovrebbe essere composta solo da 5 parti: {0}"
    noSessionToSetOnResponseExceptionMessage                          = "Non c'è nessuna sessione disponibile per la risposta."
    valueOutOfRangeExceptionMessage                                   = "Il valore '{0}' per {1} non è valido, dovrebbe essere compreso tra {2} e {3}"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'Metodo di registrazione già definito: {0}'
    noSecretForHmac256ExceptionMessage                                = "Nessun segreto fornito per l'hash HMAC256."
    eolPowerShellWarningMessage                                       = '[ATTENZIONE] Pode {0} non è stato testato su PowerShell {1}, perche è EOL.'
    runspacePoolFailedToLoadExceptionMessage                          = 'Impossibile caricare RunspacePool per {0}.'
    noEventRegisteredExceptionMessage                                 = 'Nessun evento {0} registrato: {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[Schedulatore] {0}: Non può avere un limite negativo.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'Lo stile della richiesta OpenAPI non può essere {0} per un parametro {1}.'
    openApiDocumentNotCompliantExceptionMessage                       = 'Il documento non è conforme con le specificazioni OpenAPI.'
    taskDoesNotExistExceptionMessage                                  = "L'attività '{0}' non esiste."
    scopedVariableNotFoundExceptionMessage                            = 'Variabile di ambito non trovata: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = 'Le sessioni sono necessarie per utilizzare CSRF a meno che non si vogliano usare i cookie.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'È richiesto uno ScriptBlock non vuoto per il metodo di registrazione.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = 'Quando vengono passate le Credenziali, il carattere jolly * per le Intestazioni sarà considerato come una stringa letterale e non come un carattere jolly.'
    podeNotInitializedExceptionMessage                                = 'Pode non è stato inizializzato.'
    multipleEndpointsForGuiMessage                                    = 'Sono stati definiti più endpoint, solo il primo sarà utilizzato per la GUI.'
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID: {0} deve essere univoco.'
    invalidJsonJwtExceptionMessage                                    = 'Valore JSON non valido trovato in JWT'
    noAlgorithmInJwtHeaderExceptionMessage                            = "Nessun algoritmo fornito nell'header JWT."
    openApiVersionPropertyMandatoryExceptionMessage                   = 'La proprietà versione OpenAPI è obbligatoria.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = 'Il valore limite non può essere 0 o inferiore per {0}'
    timerDoesNotExistExceptionMessage                                 = "Timer '{0}' non esiste."
    openApiGenerationDocumentErrorMessage                             = 'Errore nella generazione del documento OpenAPI:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "Il percorso '[{0}] {1}' contiene già un accesso personalizzato con nome '{2}'"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = 'Il numero massimo di thread WebSocket simultanei non può essere inferiore al minimo di {0}, ma è stato ottenuto: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: Middleware già definito.'
    invalidAtomCharacterExceptionMessage                              = "Carattere cron 'atom' non valido: {0}"
    invalidCronAtomFormatExceptionMessage                             = "Formato cron 'atom' non valido trovato: {0}"
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "Memoria cache con nome '{0}' non trovata durante il tentativo di recuperare l'elemento memorizzato nella cache '{1}'."
    headerMustHaveNameInEncodingContextExceptionMessage               = "L'intestazione deve avere un nome quando viene utilizzata in un contesto di codifica."
    moduleDoesNotContainFunctionExceptionMessage                      = "Il modulo {0} non contiene la funzione {1} da convertire in una 'route'."
    pathToIconForGuiDoesNotExistExceptionMessage                      = "Il percorso dell'icona per la GUI non esiste: {0}"
    noTitleSuppliedForPageExceptionMessage                            = 'Nessun titolo fornito per la pagina {0}.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'Certificato fornito per un endpoint non HTTPS/WSS.'
    cannotLockNullObjectExceptionMessage                              = 'Non è possibile bloccare un oggetto nullo.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui è attualmente disponibile solo per Windows PowerShell e PowerShell 7+ su Windows OS.'
    unlockSecretButNoScriptBlockExceptionMessage                      = "'Secret' di sblocco fornito per tipo di 'Secret Vault' personalizzata, ma nessun ScriptBlock di sblocco è fornito."
    invalidIpAddressExceptionMessage                                  = "L'indirizzo IP fornito non è valido: {0}"
    maxDaysInvalidExceptionMessage                                    = 'MaxDays deve essere 0 o superiore, ma è stato ottenuto: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "Nessun ScriptBlock fornito per rimuovere 'Secret Vault' '{0}'"
    noSecretExpectedForNoSignatureExceptionMessage                    = "Non era previsto alcun 'Secret' per nessuna firma."
    noCertificateFoundExceptionMessage                                = "Nessun certificato trovato in {0}{1} per '{2}'"
    minValueInvalidExceptionMessage                                   = "Il valore minimo '{0}' per {1} non è valido, dovrebbe essere maggiore o uguale a {2}"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = "L'accesso richiede l'autenticazione sulle rotte."
    noSecretForHmac384ExceptionMessage                                = "Nessun 'Secret' fornito per l'hash HMAC384."
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = "Il supporto per l'autenticazione locale di Windows è solo per Windows OS."
    definitionTagNotDefinedExceptionMessage                           = 'Tag di definizione {0} non existe.'
    noComponentInDefinitionExceptionMessage                           = 'Nessun componente del tipo {0} chiamato {1} è disponibile nella definizione {2}.'
    noSmtpHandlersDefinedExceptionMessage                             = 'Non sono stati definiti gestori SMTP.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'Il Middleware della sessione è già stato inizializzato.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "La funzione del componente riutilizzabile 'pathItems' non è disponibile in OpenAPI v3.0."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = "Il carattere jolly * per le Intestazioni è incompatibile con l'opzione AutoHeaders."
    noDataForFileUploadedExceptionMessage                             = "Nessun dato per il file '{0}' è stato caricato nella richiesta."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSE può essere configurato solo su richieste con un valore di intestazione Accept di text/event-stream.'
    noSessionAvailableToSaveExceptionMessage                          = 'Nessuna sessione disponibile per il salvataggio.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "Se la posizione del parametro è 'Path', il parametro switch 'Required' è obbligatorio."
    noOpenApiUrlSuppliedExceptionMessage                              = 'Nessun URL OpenAPI fornito per {0}.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = 'Il numero massimo di schedulazioni concorrenti deve essere >=1 ma invece è: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Gli Snapin sono supportati solo con Windows PowerShell.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = 'La registrazione nel Visualizzatore eventi è supportata solo su Windows OS.'
    parametersMutuallyExclusiveExceptionMessage                       = "I parametri '{0}' e '{1}' sono mutuamente esclusivi."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = "La funzionalità 'PathItems' non è supportata in OpenAPI v3.0.x"
    openApiParameterRequiresNameExceptionMessage                      = 'Il parametro OpenAPI richiede che un nome sia specificato.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = 'Il numero massimo di attività simultanee non può essere inferiore al minimo di {0}, ma è stato fornito: {1}'
    noSemaphoreFoundExceptionMessage                                  = "Nessun semaforo trovato chiamato '{0}'"
    singleValueForIntervalExceptionMessage                            = 'Puoi fornire solo un singolo valore {0} quando si utilizzano gli intervalli.'
    jwtNotYetValidExceptionMessage                                    = "JWT non è ancora valido per l'uso."
    verbAlreadyDefinedForUrlExceptionMessage                          = '[Verbo] {0}: Già definito per {1}'
    noSecretNamedMountedExceptionMessage                              = "Nessun 'Secret' con il nome '{0}' è stato montato."
    moduleOrVersionNotFoundExceptionMessage                           = 'Modulo o versione non trovati su {0}: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = "Nessun 'ScriptBlock' fornito."
    noSecretVaultRegisteredExceptionMessage                           = "Nessuna 'Secret Vault' con il nome '{0}' è stato registrata."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = "È richiesto un nome per l'endpoint se viene fornito il parametro 'RedirectTo'."
    openApiLicenseObjectRequiresNameExceptionMessage                  = "L'oggetto OpenAPI 'license' richiede la proprietà 'name'. Utilizzare il parametro -LicenseName."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = "{0}: Il percorso sorgente fornito per la 'route' statica non esiste: {1}"
    noNameForWebSocketDisconnectExceptionMessage                      = 'Nessun nome fornito per disconnettere il WebSocket.'
    certificateExpiredExceptionMessage                                = "Il certificato '{0}' è scaduto: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = "La data di scadenza per sbloccare la 'Secret Vault' è nel passato (UTC): {0}"
    invalidWebExceptionTypeExceptionMessage                           = "L'eccezione è di un tipo non valido, dovrebbe essere WebException o HttpRequestException, ma invece è: {0}"
    invalidSecretValueTypeExceptionMessage                            = "Il valore 'Secret' è di un tipo non valido. Tipi previsti: String, SecureString, HashTable, Byte[] o PSCredential. Ma ottenuto: {0}"
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = 'La modalità TLS esplicita è supportata solo sugli endpoint SMTPS e TCPS.'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "Il parametro 'DiscriminatorMapping' può essere utilizzato solo quando è presente 'DiscriminatorProperty'."
    scriptErrorExceptionMessage                                       = "Errore '{0}' nello script {1} {2} (riga {3}) carattere {4} eseguendo {5} su {6} oggetto '{7}' Classe: {8} Classe di base: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = 'Impossibile fornire un valore di intervallo per ogni trimestre.'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[Schedulatore] {0}: Il valore di EndTime deve essere nel futuro.'
    invalidJwtSignatureSuppliedExceptionMessage                       = 'Firma JWT fornita non valida.'
    noSetScriptBlockForVaultExceptionMessage                          = "Nessun 'ScriptBlock' fornito per aggiornare/creare 'Secret Vault' '{0}'"
    accessMethodNotExistForMergingExceptionMessage                    = "Il metodo di accesso non esiste per l'unione: {0}"
    defaultAuthNotInListExceptionMessage                              = "L'autenticazione predefinita '{0}' non è nella lista di autenticazione fornita."
    parameterHasNoNameExceptionMessage                                = "Il parametro non ha un nome. Assegna un nome a questo componente usando il parametro 'Name'."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: Già definito per {2}'
    fileWatcherAlreadyDefinedExceptionMessage                         = "Un 'FileWatcher' con il nome '{0}' è già stato definito."
    noServiceHandlersDefinedExceptionMessage                          = 'Non sono stati definiti gestori di servizio.'
    secretRequiredForCustomSessionStorageExceptionMessage             = "Un 'Secret' è riquesto quando si utilizza l'archiviazione delle sessioni personalizzata."
    secretManagementModuleNotInstalledExceptionMessage                = 'Il modulo Microsoft.PowerShell.SecretManagement non è installato.'
    noPathSuppliedForRouteExceptionMessage                            = "Nessun percorso fornito per la 'route'."
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "La validazione di uno schema che include 'anyof' non è supportata."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = "Il supporto per l'autenticazione IIS è solo per Windows OS."
    oauth2InnerSchemeInvalidExceptionMessage                          = 'OAuth2 InnerScheme può essere solo di tipo Basic o Form, ma non di tipo: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = "Nessun percorso di 'route' fornito per la pagina {0}."
    cacheStorageNotFoundForExistsExceptionMessage                     = "Memoria cache con nome '{0}' non trovata durante il tentativo di verificare se l'elemento memorizzato nella cache '{1}' esiste."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: Handler già definito.'
    sessionsNotConfiguredExceptionMessage                             = 'Le sessioni non sono state configurate.'
    propertiesTypeObjectAssociationExceptionMessage                   = "Solo le proprietà di tipo 'Object' possono essere associate a {0}."
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = "Sono necessarie sessioni per utilizzare l'autenticazione persistente della sessione."
    invalidPathWildcardOrDirectoryExceptionMessage                    = 'Il percorso fornito non può essere un carattere jolly o una directory: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = 'Metodo di accesso già definito: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "I parametri 'Value' o 'ExternalValue' sono obbligatori."
    maximumConcurrentTasksInvalidExceptionMessage                     = 'Il numero massimo di attività simultanee deve essere >=1, {0} non è valido.'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = 'Impossibile creare la proprietà perché manca la definizione di tipo.'
    authMethodNotExistForMergingExceptionMessage                      = 'Il metodo di autenticazione non esiste per la aggregazione: {0}'
    maxValueInvalidExceptionMessage                                   = "Il valore massimo '{0}' per {1} non è valido, dovrebbe essere minore o uguale a {2}"
    endpointAlreadyDefinedExceptionMessage                            = "Un endpoint denominato '{0}' è già stato definito."
    eventAlreadyRegisteredExceptionMessage                            = 'Evento {0} già registrato: {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "Un parametro chiamato '{0}' non è stato fornito nella richiesta o non ci sono dati disponibili."
    cacheStorageNotFoundForSetExceptionMessage                        = "Memoria cache con nome '{0}' non trovata durante il tentativo di impostare l'elemento memorizzato nella cache '{1}'."
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: Già definito.'
    errorLoggingAlreadyEnabledExceptionMessage                        = 'La registrazione degli errori è già abilitata.'
    valueForUsingVariableNotFoundExceptionMessage                     = "Impossibile trovare il valore per '`$using:{0}'."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = 'Lo strumento di documentazione RapidPdf non supporta OpenAPI 3.1'
    oauth2ClientSecretRequiredExceptionMessage                        = 'OAuth2 richiede un Client Secret quando non si utilizza PKCE.'
    invalidBase64JwtExceptionMessage                                  = 'Valore codificato Base64 non valido trovato in JWT'
    noSessionToCalculateDataHashExceptionMessage                      = "Nessuna sessione disponibile per calcolare l'hash dei dati."
    cacheStorageNotFoundForRemoveExceptionMessage                     = "Memoria cache con nome '{0}' non trovata durante il tentativo di rimuovere l'elemento memorizzato nella cache '{1}'."
    csrfMiddlewareNotInitializedExceptionMessage                      = 'Il Middleware CSRF non è stato inizializzato.'
    infoTitleMandatoryMessage                                         = 'info.title è obbligatorio.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = 'Il tipo {0} può essere associato solo a un oggetto.'
    userFileDoesNotExistExceptionMessage                              = 'Il file utente non esiste: {0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = "Il parametro della 'route' richiede uno ScriptBlock valido e non vuoto."
    nextTriggerCalculationErrorExceptionMessage                       = 'Sembra che ci sia stato un errore nel tentativo di calcolare la prossima data e ora del trigger: {0}'
    cannotLockValueTypeExceptionMessage                               = 'Non è possibile bloccare un [ValueType].'
    failedToCreateOpenSslCertExceptionMessage                         = 'Impossibile creare il certificato OpenSSL: {0}'
    jwtExpiredExceptionMessage                                        = 'JWT è scaduto.'
    openingGuiMessage                                                 = 'Apertura della GUI.'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = 'Le proprietà multi-tipo richiedono OpenAPI versione 3.1 o superiore.'
    noNameForWebSocketRemoveExceptionMessage                          = 'Nessun nome fornito per rimuovere il WebSocket.'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize deve essere 0 o superiore, ma è stato ottenuto: {0}'
    iisShutdownMessage                                                = '(Chiusura IIS)'
    cannotUnlockValueTypeExceptionMessage                             = 'Non è possibile sbloccare un [ValueType].'
    noJwtSignatureForAlgorithmExceptionMessage                        = 'Nessuna firma JWT fornita per {0}.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = 'Il numero massimo di thread WebSocket simultanei deve essere >=1, ma è stato ottenuto: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = 'Il messaggio di conferma è supportato solo sugli endpoint SMTP e TCP.'
    failedToConnectToUrlExceptionMessage                              = "Impossibile connettersi all'URL: {0}"
    failedToAcquireMutexOwnershipExceptionMessage                     = 'Impossibile acquisire la proprietà del mutex. Nome del mutex: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'Sono necessarie sessioni per utilizzare OAuth2 con PKCE'
    failedToConnectToWebSocketExceptionMessage                        = 'Connessione al WebSocket non riuscita: {0}'
    unsupportedObjectExceptionMessage                                 = 'Oggetto non supportato'
    failedToParseAddressExceptionMessage                              = "Impossibile analizzare '{0}' come indirizzo IP/Host:Port valido"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'Deve essere eseguito con privilegi di amministratore per usare indirizzi non locali.'
    specificationMessage                                              = 'Specifica'
    cacheStorageNotFoundForClearExceptionMessage                      = "Memoria cache con nome '{0}' non trovata durante il tentativo di cancellare la cache."
    restartingServerMessage                                           = 'Riavvio del server...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "Impossibile fornire un intervallo quando il parametro 'Every' è 'None'."
    unsupportedJwtAlgorithmExceptionMessage                           = "L'algoritmo JWT non è attualmente supportato: {0}"
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'I WebSockets non sono configurati per inviare messaggi di segnale.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = "Un Middleware di tipo Hashtable fornito ha un tipo di logica non valido. Previsto 'ScriptBlock', invece di: {0}"
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = 'Il numero di schedulazioni concorrenti massime non può essere inferiore al minimo di {0}. Valore passato: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = 'Impossibile acquisire la proprietà del semaforo. Nome del semaforo: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = "I parametri 'Properties' non possono essere utilizzati se la proprietà non ha un nome."
    customSessionStorageMethodNotImplementedExceptionMessage          = "L'archiviazione delle sessioni personalizzata non implementa il metodo richiesto '{0}()'."
    authenticationMethodDoesNotExistExceptionMessage                  = 'Il metodo di autenticazione non esiste: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'La funzionalità Webhooks non è supportata in OpenAPI v3.0.x'
    invalidContentTypeForSchemaExceptionMessage                       = "'content-type' non valido trovato per lo schema: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "Nessun 'ScriptBlock' di sblocco fornito per sbloccare la 'Secret Vault' '{0}'"
    definitionTagMessage                                              = 'Definizione {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'Impossibile aprire RunspacePool: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'Impossibile chiudere RunspacePool: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[Verbo] {0}: Nessuna logica passata'
    noMutexFoundExceptionMessage                                      = "Nessun mutex trovato chiamato '{0}'"
    documentationMessage                                              = 'Documentazione'
    timerAlreadyDefinedExceptionMessage                               = '[Timer] {0}: Timer già definito.'
    invalidPortExceptionMessage                                       = 'La porta non può essere un numero negativo: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = "Il nome della cartella 'Views' esiste già: {0}"
    noNameForWebSocketResetExceptionMessage                           = 'Nessun nome fornito per reimpostare il WebSocket.'
    mergeDefaultAuthNotInListExceptionMessage                         = "L'autenticazione MergeDefault '{0}' non è nella lista di autenticazione fornita."
    descriptionRequiredExceptionMessage                               = 'È necessaria una descrizione.'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'Il nome della pagina dovrebbe essere un valore alfanumerico valido: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = "Il valore predefinito non è un booleano e non fa parte dell'enum."
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'Lo schema del componente OpenAPI {0} non esiste.'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[Timer] {0}: {1} deve essere maggiore di 0.'
    taskTimedOutExceptionMessage                                      = "Il 'Task' è scaduto dopo {0}ms."
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[Schedulatore] {0}: Non può avere un 'StartTime' sucessivo a 'EndTime'"
    infoVersionMandatoryMessage                                       = 'info.version è obbligatorio.'
    cannotUnlockNullObjectExceptionMessage                            = 'Non è possibile sbloccare un oggetto nullo.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = 'È richiesto uno ScriptBlock non vuoto per lo schema di autenticazione personalizzato.'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = 'È necessario un ScriptBlock non vuoto per il metodo di autenticazione.'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "La validazione di uno schema che include 'oneof' non è supportata."
    routeParameterCannotBeNullExceptionMessage                        = "Il parametro 'Route' non può essere null."
    cacheStorageAlreadyExistsExceptionMessage                         = "Memoria cache con nome '{0}' esiste già."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "Il metodo di output fornito per il metodo di registrazione '{0}' richiede un ScriptBlock valido."
    scopedVariableAlreadyDefinedExceptionMessage                      = 'Variabile con ambito già definita: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = "OAuth2 richiede che venga fornita un'URL di autorizzazione"
    pathNotExistExceptionMessage                                      = 'Il percorso non esiste: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = "Non è stato fornito alcun nome di server di dominio per l'autenticazione AD di Windows"
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = "La data fornita è successiva all'ora di fine del programma a {0}"
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = "Il carattere jolly * per i Metodi è incompatibile con l'opzione AutoMethods."
    cannotSupplyIntervalForYearExceptionMessage                       = 'Impossibile fornire un valore di intervallo per ogni anno.'
    missingComponentsMessage                                          = 'Componenti mancanti'
    invalidStrictTransportSecurityDurationExceptionMessage            = 'Durata Strict-Transport-Security non valida fornita: {0}. Deve essere maggiore di 0.'
    noSecretForHmac512ExceptionMessage                                = "Nessun 'secret' fornito per l'hash HMAC512."
    daysInMonthExceededExceptionMessage                               = '{0} ha solo {1} giorni, ma è stato fornito {2}.'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'È richiesto uno ScriptBlock non vuoto per il metodo di registrazione personalizzato.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = "L'attributo di codifica si applica solo ai corpi delle richieste multipart e application/x-www-form-urlencoded."
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = "La data fornita è precedente all'ora di inizio del programma a {0}"
    unlockSecretRequiredExceptionMessage                              = "È necessaria una proprietà 'UnlockSecret' quando si utilizza Microsoft.PowerShell.SecretStore"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: Nessuna logica passata.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = 'Un body-parser è già definito per il tipo di contenuto {0}.'
    invalidJwtSuppliedExceptionMessage                                = 'JWT fornito non valido.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'Le sessioni sono necessarie per utilizzare i messaggi di tipo Flash.'
    semaphoreAlreadyExistsExceptionMessage                            = 'Un semaforo con il seguente nome esiste già: {0}'
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = "Algoritmo dell'header JWT fornito non valido."
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "Il provider OAuth2 non supporta il tipo di concessione 'password' richiesto dall'utilizzo di un InnerScheme."
    invalidAliasFoundExceptionMessage                                 = 'Alias {0} non valido trovato: {1}'
    scheduleDoesNotExistExceptionMessage                              = "Il programma '{0}' non esiste."
    accessMethodNotExistExceptionMessage                              = 'Il metodo di accesso non esiste: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "Il provider OAuth2 non supporta il tipo di risposta 'code'."
    untestedPowerShellVersionWarningMessage                           = '[ATTENZIONE] Pode {0} non è stato testato su PowerShell {1}, poiché non era disponibile quando Pode è stato rilasciato.'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "Una 'Secret Vault' con il nome '{0}' è già stata registrata durante l'importazione automatica delle 'Secret Vaults'."
    schemeRequiresValidScriptBlockExceptionMessage                    = "Lo schema fornito per il validatore di autenticazione '{0}' richiede uno ScriptBlock valido."
    serverLoopingMessage                                              = 'Ciclo del server ogni {0} secondi'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'Impronte digitali/nome del certificato supportati solo su Windows OS.'
    sseConnectionNameRequiredExceptionMessage                         = "È richiesto un nome di connessione SSE, sia da -Name che da `$WebEvent.Sse.Name"
    invalidMiddlewareTypeExceptionMessage                             = 'Uno dei Middleware forniti è di un tipo non valido. Previsto ScriptBlock o Hashtable, ma ottenuto: {0}'
    noSecretForJwtSignatureExceptionMessage                           = "Nessun 'secret' fornito per la firma JWT."
    modulePathDoesNotExistExceptionMessage                            = 'Il percorso del modulo non esiste: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[Attività] {0}: Attività già definita.'
    verbAlreadyDefinedExceptionMessage                                = '[Verbo] {0}: Già definito'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'I certificati client sono supportati solo sugli endpoint HTTPS.'
    endpointNameNotExistExceptionMessage                              = "Endpoint con nome '{0}' non esiste."
    middlewareNoLogicSuppliedExceptionMessage                         = '[Middleware]: Nessuna logica fornita nello ScriptBlock.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = "È richiesto uno ScriptBlock per unire più utenti autenticati in un unico oggetto quando 'Valid' è uguale a 'All'."
    secretVaultAlreadyRegisteredExceptionMessage                      = "Una 'Secret Vault' con il nome '{0}' è già stato registrata{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "ATTENZIONE: Titolo, Versione e Descrizione su 'Enable-PodeOpenApi' sono deprecati. Si prega di utilizzare 'Add-PodeOAInfo' invece."
    undefinedOpenApiReferencesMessage                                 = 'Riferimenti OpenAPI non definiti:'
    doneMessage                                                       = 'Fatto'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = 'Questa versione di Swagger-Editor non supporta OpenAPI 3.1'
    durationMustBeZeroOrGreaterExceptionMessage                       = 'La durata deve essere 0 o superiore, non {0}s'
    viewsPathDoesNotExistExceptionMessage                             = 'Il percorso delle Views non esiste: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "Il parametro 'Discriminator' è incompatibile con 'allOf'."
    noNameForWebSocketSendMessageExceptionMessage                     = 'Nessun nome fornito per inviare un messaggio al WebSocket.'
    hashtableMiddlewareNoLogicExceptionMessage                        = 'Un Middleware di tipo Hashtable fornito non ha una logica definita.'
    openApiInfoMessage                                                = 'Informazioni OpenAPI:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "Lo schema '{0}' fornito per il validatore di autenticazione '{1}' richiede uno ScriptBlock valido."
    sseFailedToBroadcastExceptionMessage                              = 'SSE non è riuscito a trasmettere a causa del livello di trasmissione SSE definito per {0}: {1}.'
    adModuleWindowsOnlyExceptionMessage                               = 'Il modulo Active Directory è disponibile solo su Windows OS.'
    requestLoggingAlreadyEnabledExceptionMessage                      = 'La registrazione delle richieste è già abilitata.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = 'Durata non valida fornita per Access-Control-Max-Age: {0}. Deve essere maggiore di 0.'
    openApiDefinitionAlreadyExistsExceptionMessage                    = 'La definizione OpenAPI denominata {0} esiste già.'
    renamePodeOADefinitionTagExceptionMessage                         = "Rename-PodeOADefinitionTag non può essere utilizzato all'interno di un 'ScriptBlock' di Select-PodeOADefinition."
    UnsupportedSerializationTypeExceptionMessage                      = 'Tipo di serializzazione non supportato: {0}'
    GetRequestBodyNotAllowedExceptionMessage                          = 'Le operazioni GET non possono avere un corpo della richiesta.'
    InvalidQueryFormatExceptionMessage                                = 'La query fornita ha un formato non valido.'
    asyncIdDoesNotExistExceptionMessage                               = 'Async {0} non esiste.'
}