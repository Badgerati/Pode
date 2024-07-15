@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'La validation du schéma nécessite PowerShell version 6.1.0 ou supérieure.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = "Un chemin ou un ScriptBlock est requis pour obtenir les valeurs d'accès personnalisées."
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID : {0} doit être unique et ne peut pas être appliqué à un tableau.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "Un point de terminaison nommé '{0}' n'a pas été défini pour la redirection."
    filesHaveChangedMessage                                           = 'Les fichiers suivants ont été modifiés :'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'Le jeton IIS ASPNETCORE_TOKEN est manquant.'
    minValueGreaterThanMaxExceptionMessage                            = 'La valeur minimale pour {0} ne doit pas être supérieure à la valeur maximale.'
    noLogicPassedForRouteExceptionMessage                             = 'Aucune logique passée pour la Route: {0}'
    scriptPathDoesNotExistExceptionMessage                            = "Le chemin du script n'existe pas : {0}"
    mutexAlreadyExistsExceptionMessage                                = 'Un mutex avec le nom suivant existe déjà: {0}'
    listeningOnEndpointsMessage                                       = 'Écoute sur les {0} point(s) de terminaison suivant(s) [{1} thread(s)] :'
    unsupportedFunctionInServerlessContextExceptionMessage            = "La fonction {0} n'est pas prise en charge dans un contexte sans serveur."
    expectedNoJwtSignatureSuppliedExceptionMessage                    = "Aucune signature JWT n'était attendue."
    secretAlreadyMountedExceptionMessage                              = "Un Secret avec le nom '{0}' a déjà été monté."
    failedToAcquireLockExceptionMessage                               = "Impossible d'acquérir un verrou sur l'objet."
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: Aucun chemin fourni pour la Route statique.'
    invalidHostnameSuppliedExceptionMessage                           = "Nom d'hôte fourni invalide: {0}"
    authMethodAlreadyDefinedExceptionMessage                          = "Méthode d'authentification déjà définie : {0}"
    csrfCookieRequiresSecretExceptionMessage                          = "Lors de l'utilisation de cookies pour CSRF, un Secret est requis. Vous pouvez soit fournir un Secret, soit définir le Secret global du Cookie - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = 'Un ScriptBlock non vide est requis pour créer une route de page.'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "Le paramètre 'NoProperties' est mutuellement exclusif avec 'Properties', 'MinProperties' et 'MaxProperties'."
    incompatiblePodeDllExceptionMessage                               = 'Une version incompatible existante de Pode.DLL {0} est chargée. La version {1} est requise. Ouvrez une nouvelle session Powershell/pwsh et réessayez.'
    accessMethodDoesNotExistExceptionMessage                          = "La méthode d'accès n'existe pas : {0}."
    scheduleAlreadyDefinedExceptionMessage                            = '[Horaire] {0}: Horaire déjà défini.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = 'La valeur en secondes ne peut pas être 0 ou inférieure pour {0}'
    pathToLoadNotFoundExceptionMessage                                = 'Chemin à charger {0} non trouvé : {1}'
    failedToImportModuleExceptionMessage                              = "Échec de l'importation du module : {0}"
    endpointNotExistExceptionMessage                                  = "Un point de terminaison avec le protocole '{0}' et l'adresse '{1}' ou l'adresse locale '{2}' n'existe pas."
    terminatingMessage                                                = 'Terminaison...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = 'Aucune commande fournie pour convertir en routes.'
    invalidTaskTypeExceptionMessage                                   = "Le type de tâche n'est pas valide, attendu [System.Threading.Tasks.Task] ou [hashtable]."
    alreadyConnectedToWebSocketExceptionMessage                       = "Déjà connecté au WebSocket avec le nom '{0}'"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = "La vérification de fin de message CRLF n'est prise en charge que sur les points de terminaison TCP."
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema' doit être activé en utilisant 'Enable-PodeOpenApi -EnableSchemaValidation'"
    adModuleNotInstalledExceptionMessage                              = "Le module Active Directory n'est pas installé."
    cronExpressionInvalidExceptionMessage                             = "L'expression Cron doit uniquement comporter 5 parties : {0}"
    noSessionToSetOnResponseExceptionMessage                          = 'Aucune session disponible pour être définie sur la réponse.'
    valueOutOfRangeExceptionMessage                                   = "La valeur '{0}' pour {1} n'est pas valide, elle doit être comprise entre {2} et {3}"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'Méthode de journalisation déjà définie: {0}'
    noSecretForHmac256ExceptionMessage                                = 'Aucun secret fourni pour le hachage HMAC256.'
    eolPowerShellWarningMessage                                       = "[AVERTISSEMENT] Pode {0} n'a pas été testé sur PowerShell {1}, car il est en fin de vie."
    runspacePoolFailedToLoadExceptionMessage                          = "{0} RunspacePool n'a pas pu être chargé."
    noEventRegisteredExceptionMessage                                 = 'Aucun événement {0} enregistré : {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[Horaire] {0}: Ne peut pas avoir de limite négative.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'Le style de la requête OpenApi ne peut pas être {0} pour un paramètre {1}.'
    openApiDocumentNotCompliantExceptionMessage                       = "Le document OpenAPI n'est pas conforme."
    taskDoesNotExistExceptionMessage                                  = "La tâche '{0}' n'existe pas."
    scopedVariableNotFoundExceptionMessage                            = "Variable d'étendue non trouvée : {0}"
    sessionsRequiredForCsrfExceptionMessage                           = 'Des sessions sont nécessaires pour utiliser CSRF sauf si vous souhaitez utiliser des cookies.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'Un ScriptBlock non vide est requis pour la méthode de journalisation.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = 'Lorsque des Identifiants sont passés, le caractère générique * pour les En-têtes sera pris comme une chaîne littérale et non comme un caractère générique.'
    podeNotInitializedExceptionMessage                                = "Pode n'a pas été initialisé."
    multipleEndpointsForGuiMessage                                    = "Plusieurs points de terminaison définis, seul le premier sera utilisé pour l'interface graphique."
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID : {0} doit être unique.'
    invalidJsonJwtExceptionMessage                                    = 'Valeur JSON non valide trouvée dans le JWT'
    noAlgorithmInJwtHeaderExceptionMessage                            = "Aucun algorithme fourni dans l'en-tête JWT."
    openApiVersionPropertyMandatoryExceptionMessage                   = 'La propriété Version OpenApi est obligatoire.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = 'La valeur de la limite ne peut pas être 0 ou inférieure pour {0}'
    timerDoesNotExistExceptionMessage                                 = "Minuteur '{0}' n'existe pas."
    openApiGenerationDocumentErrorMessage                             = 'Erreur de génération du document OpenAPI :'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "La route '[{0}] {1}' contient déjà un accès personnalisé avec le nom '{2}'"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = 'Le nombre maximum de threads WebSocket simultanés ne peut pas être inférieur au minimum de {0}, mais a obtenu : {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: Middleware déjà défini.'
    invalidAtomCharacterExceptionMessage                              = "Caractère d'atome cron non valide : {0}"
    invalidCronAtomFormatExceptionMessage                             = "Format d'atome cron invalide trouvé: {0}"
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "Le stockage de cache nommé '{0}' est introuvable lors de la tentative de récupération de l'élément mis en cache '{1}'."
    headerMustHaveNameInEncodingContextExceptionMessage               = "L'en-tête doit avoir un nom lorsqu'il est utilisé dans un contexte de codage."
    moduleDoesNotContainFunctionExceptionMessage                      = 'Le module {0} ne contient pas la fonction {1} à convertir en une Route.'
    pathToIconForGuiDoesNotExistExceptionMessage                      = "Le chemin vers l'icône pour l'interface graphique n'existe pas: {0}"
    noTitleSuppliedForPageExceptionMessage                            = 'Aucun titre fourni pour la page {0}.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'Certificat fourni pour un point de terminaison non HTTPS/WSS.'
    cannotLockNullObjectExceptionMessage                              = 'Impossible de verrouiller un objet nul.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui est actuellement disponible uniquement pour Windows PowerShell et PowerShell 7+ sur Windows.'
    unlockSecretButNoScriptBlockExceptionMessage                      = 'Secret de déverrouillage fourni pour le type de coffre-fort personnalisé, mais aucun ScriptBlock de déverrouillage fourni.'
    invalidIpAddressExceptionMessage                                  = "L'adresse IP fournie n'est pas valide : {0}"
    maxDaysInvalidExceptionMessage                                    = 'MaxDays doit être égal ou supérieur à 0, mais a obtenu: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "Aucun ScriptBlock de suppression fourni pour supprimer des secrets du coffre '{0}'"
    noSecretExpectedForNoSignatureExceptionMessage                    = 'Aucun secret attendu pour aucune signature.'
    noCertificateFoundExceptionMessage                                = "Aucun certificat n'a été trouvé dans {0}{1} pour '{2}'"
    minValueInvalidExceptionMessage                                   = "La valeur minimale '{0}' pour {1} n'est pas valide, elle doit être supérieure ou égale à {2}"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = "L'accès nécessite une authentification sur les routes."
    noSecretForHmac384ExceptionMessage                                = 'Aucun secret fourni pour le hachage HMAC384.'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = "Le support de l'authentification locale Windows est uniquement pour Windows."
    definitionTagNotDefinedExceptionMessage                           = 'Tag de définition {0} non défini.'
    noComponentInDefinitionExceptionMessage                           = "Aucun composant du type {0} nommé {1} n'est disponible dans la définition {2}."
    noSmtpHandlersDefinedExceptionMessage                             = 'Aucun gestionnaire SMTP défini.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'Le Middleware de session a déjà été initialisé.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "La fonctionnalité du composant réutilisable 'pathItems' n'est pas disponible dans OpenAPI v3.0."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = 'Le caractère générique * pour les En-têtes est incompatible avec le commutateur AutoHeaders.'
    noDataForFileUploadedExceptionMessage                             = "Aucune donnée pour le fichier '{0}' n'a été téléchargée dans la demande."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = "SSE ne peut être configuré que sur les requêtes avec une valeur d'en-tête Accept de text/event-stream."
    noSessionAvailableToSaveExceptionMessage                          = 'Aucune session disponible pour sauvegarder.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "Si l'emplacement du paramètre est 'Path', le paramètre switch 'Required' est obligatoire."
    noOpenApiUrlSuppliedExceptionMessage                              = 'Aucune URL OpenAPI fournie pour {0}.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = 'Les horaires simultanés maximum doivent être >=1 mais obtenu: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Les Snapins sont uniquement pris en charge sur Windows PowerShell.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = "La journalisation dans le Visualisateur d'événements n'est prise en charge que sous Windows."
    parametersMutuallyExclusiveExceptionMessage                       = "Les paramètres '{0}' et '{1}' sont mutuellement exclusifs."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = "La fonction PathItems n'est pas prise en charge dans OpenAPI v3.0.x"
    openApiParameterRequiresNameExceptionMessage                      = 'Le paramètre OpenApi nécessite un nom spécifié.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = 'Le nombre maximum de tâches simultanées ne peut pas être inférieur au minimum de {0}, mais a obtenu : {1}'
    noSemaphoreFoundExceptionMessage                                  = "Aucun sémaphore trouvé appelé '{0}'"
    singleValueForIntervalExceptionMessage                            = "Vous ne pouvez fournir qu'une seule valeur {0} lorsque vous utilisez des intervalles."
    jwtNotYetValidExceptionMessage                                    = "Le JWT n'est pas encore valide pour une utilisation."
    verbAlreadyDefinedForUrlExceptionMessage                          = '[Verbe] {0} : Déjà défini pour {1}'
    noSecretNamedMountedExceptionMessage                              = "Aucun Secret nommé '{0}' n'a été monté."
    moduleOrVersionNotFoundExceptionMessage                           = 'Module ou version introuvable sur {0} : {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'Aucun ScriptBlock fourni.'
    noSecretVaultRegisteredExceptionMessage                           = "Aucun coffre-fort de secrets enregistré sous le nom '{0}'."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'Un nom est requis pour le point de terminaison si le paramètre RedirectTo est fourni.'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "L'objet OpenAPI 'license' nécessite la propriété 'name'. Utilisez le paramètre -LicenseName."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = "{0}: Le chemin source fourni pour la Route statique n'existe pas: {1}"
    noNameForWebSocketDisconnectExceptionMessage                      = 'Aucun Nom fourni pour déconnecter le WebSocket.'
    certificateExpiredExceptionMessage                                = "Le certificat '{0}' a expiré: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = "La date d'expiration du déverrouillage du Coffre-Fort de Secrets est dans le passé (UTC) : {0}"
    invalidWebExceptionTypeExceptionMessage                           = "L'exception est d'un type non valide, doit être soit WebException soit HttpRequestException, mais a obtenu : {0}"
    invalidSecretValueTypeExceptionMessage                            = "La valeur du secret est d'un type non valide. Types attendus : String, SecureString, HashTable, Byte[], ou PSCredential. Mais a obtenu : {0}"
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = "Le mode TLS explicite n'est pris en charge que sur les points de terminaison SMTPS et TCPS."
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "Le paramètre 'DiscriminatorMapping' ne peut être utilisé que lorsque 'DiscriminatorProperty' est présent."
    scriptErrorExceptionMessage                                       = "Erreur '{0}' dans le script {1} {2} (ligne {3}) char {4} en exécutant {5} sur l'objet {6} '{7}' Classe : {8} ClasseBase : {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = "Impossible de fournir une valeur d'intervalle pour chaque trimestre."
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[Horaire] {0}: La valeur de EndTime doit être dans le futur.'
    invalidJwtSignatureSuppliedExceptionMessage                       = 'Signature JWT fournie invalide.'
    noSetScriptBlockForVaultExceptionMessage                          = "Aucun ScriptBlock de configuration fourni pour mettre à jour/créer des secrets dans le coffre '{0}'"
    accessMethodNotExistForMergingExceptionMessage                    = "La méthode d'accès n'existe pas pour la fusion : {0}"
    defaultAuthNotInListExceptionMessage                              = "L'authentification par défaut '{0}' n'est pas dans la liste d'authentification fournie."
    parameterHasNoNameExceptionMessage                                = "Le paramètre n'a pas de nom. Veuillez donner un nom à ce composant en utilisant le paramètre 'Name'."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1} : Déjà défini pour {2}'
    fileWatcherAlreadyDefinedExceptionMessage                         = "Un Observateur de fichiers nommé '{0}' a déjà été défini."
    noServiceHandlersDefinedExceptionMessage                          = 'Aucun gestionnaire de service défini.'
    secretRequiredForCustomSessionStorageExceptionMessage             = "Un secret est requis lors de l'utilisation d'un stockage de session personnalisé."
    secretManagementModuleNotInstalledExceptionMessage                = "Le module Microsoft.PowerShell.SecretManagement n'est pas installé."
    noPathSuppliedForRouteExceptionMessage                            = 'Aucun chemin fourni pour la route.'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "La validation d'un schéma qui inclut 'anyof' n'est pas prise en charge."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = "Le support de l'authentification IIS est uniquement pour Windows."
    oauth2InnerSchemeInvalidExceptionMessage                          = 'Le OAuth2 InnerScheme ne peut être que Basic ou Form, mais obtenu : {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = 'Aucun chemin de route fourni pour la page {0}.'
    cacheStorageNotFoundForExistsExceptionMessage                     = "Le stockage de cache nommé '{0}' est introuvable lors de la tentative de vérification de l'existence de l'élément mis en cache '{1}'."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: Handler déjà défini.'
    sessionsNotConfiguredExceptionMessage                             = "Les sessions n'ont pas été configurées."
    propertiesTypeObjectAssociationExceptionMessage                   = 'Seules les propriétés de type Objet peuvent être associées à {0}.'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = "Des sessions sont nécessaires pour utiliser l'authentification persistante par session."
    invalidPathWildcardOrDirectoryExceptionMessage                    = 'Le chemin fourni ne peut pas être un caractère générique ou un répertoire : {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = "Méthode d'accès déjà définie : {0}"
    parametersValueOrExternalValueMandatoryExceptionMessage           = "Les paramètres 'Value' ou 'ExternalValue' sont obligatoires."
    maximumConcurrentTasksInvalidExceptionMessage                     = 'Le nombre maximum de tâches simultanées doit être >=1, mais a obtenu : {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = "Impossible de créer la propriété car aucun type n'est défini."
    authMethodNotExistForMergingExceptionMessage                      = "La méthode d'authentification n'existe pas pour la fusion : {0}"
    maxValueInvalidExceptionMessage                                   = "La valeur maximale '{0}' pour {1} n'est pas valide, elle doit être inférieure ou égale à {2}"
    endpointAlreadyDefinedExceptionMessage                            = "Un point de terminaison nommé '{0}' a déjà été défini."
    eventAlreadyRegisteredExceptionMessage                            = 'Événement {0} déjà enregistré : {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "Un paramètre nommé '{0}' n'a pas été fourni dans la demande ou aucune donnée n'est disponible."
    cacheStorageNotFoundForSetExceptionMessage                        = "Le stockage de cache nommé '{0}' est introuvable lors de la tentative de définition de l'élément mis en cache '{1}'."
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1} : Déjà défini.'
    valueForUsingVariableNotFoundExceptionMessage                     = "Valeur pour '`$using:{0}' introuvable."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = "L'outil de documentation RapidPdf ne prend pas en charge OpenAPI 3.1"
    oauth2ClientSecretRequiredExceptionMessage                        = "OAuth2 nécessite un Client Secret lorsque PKCE n'est pas utilisé."
    invalidBase64JwtExceptionMessage                                  = 'Valeur encodée en Base64 non valide trouvée dans le JWT'
    noSessionToCalculateDataHashExceptionMessage                      = 'Aucune session disponible pour calculer le hachage de données.'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "Le stockage de cache nommé '{0}' est introuvable lors de la tentative de suppression de l'élément mis en cache '{1}'."
    csrfMiddlewareNotInitializedExceptionMessage                      = "Le Middleware CSRF n'a pas été initialisé."
    infoTitleMandatoryMessage                                         = 'info.title est obligatoire.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = "Le type {0} ne peut être associé qu'à un Objet."
    userFileDoesNotExistExceptionMessage                              = "Le fichier utilisateur n'existe pas : {0}"
    routeParameterNeedsValidScriptblockExceptionMessage               = 'Le paramètre de la route nécessite un ScriptBlock valide et non vide.'
    nextTriggerCalculationErrorExceptionMessage                       = 'Il semble que quelque chose ait mal tourné lors de la tentative de calcul de la prochaine date et heure de déclenchement : {0}'
    cannotLockValueTypeExceptionMessage                               = 'Impossible de verrouiller un [ValueType].'
    failedToCreateOpenSslCertExceptionMessage                         = 'Échec de la création du certificat OpenSSL : {0}'
    jwtExpiredExceptionMessage                                        = 'Le JWT a expiré.'
    openingGuiMessage                                                 = "Ouverture de l'interface graphique."
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = 'Les propriétés multi-types nécessitent OpenApi Version 3.1 ou supérieure.'
    noNameForWebSocketRemoveExceptionMessage                          = 'Aucun Nom fourni pour supprimer le WebSocket.'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize doit être égal ou supérieur à 0, mais a obtenu: {0}'
    iisShutdownMessage                                                = "(Arrêt de l'IIS)"
    cannotUnlockValueTypeExceptionMessage                             = 'Impossible de déverrouiller un [ValueType].'
    noJwtSignatureForAlgorithmExceptionMessage                        = 'Aucune signature JWT fournie pour {0}.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = 'Le nombre maximum de threads WebSocket simultanés doit être >=1, mais a obtenu : {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = "Le message de reconnaissance n'est pris en charge que sur les points de terminaison SMTP et TCP."
    failedToConnectToUrlExceptionMessage                              = "Échec de la connexion à l'URL : {0}"
    failedToAcquireMutexOwnershipExceptionMessage                     = "Échec de l'acquisition de la propriété du mutex. Nom du mutex: {0}"
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'Des sessions sont nécessaires pour utiliser OAuth2 avec PKCE.'
    failedToConnectToWebSocketExceptionMessage                        = 'Échec de la connexion au WebSocket : {0}'
    unsupportedObjectExceptionMessage                                 = 'Objet non pris en charge'
    failedToParseAddressExceptionMessage                              = "Échec de l'analyse de '{0}' en tant qu'adresse IP/Hôte:Port valide"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'Doit être exécuté avec des privilèges administratifs pour écouter sur des adresses autres que localhost.'
    specificationMessage                                              = 'Spécification'
    cacheStorageNotFoundForClearExceptionMessage                      = "Le stockage de cache nommé '{0}' est introuvable lors de la tentative de vider le cache."
    restartingServerMessage                                           = 'Redémarrage du serveur...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "Impossible de fournir un intervalle lorsque le paramètre 'Every' est défini sur None."
    unsupportedJwtAlgorithmExceptionMessage                           = "L'algorithme JWT n'est actuellement pas pris en charge : {0}"
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'Les WebSockets ne sont pas configurés pour envoyer des messages de signal.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = 'Un Middleware Hashtable fourni a un type de logique non valide. Attendu ScriptBlock, mais a obtenu : {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = 'Les Horaires simultanés maximum ne peuvent pas être inférieurs au minimum de {0} mais obtenu: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = "Échec de l'acquisition de la propriété du sémaphore. Nom du sémaphore: {0}"
    propertiesParameterWithoutNameExceptionMessage                    = "Les paramètres Properties ne peuvent pas être utilisés si la propriété n'a pas de nom."
    customSessionStorageMethodNotImplementedExceptionMessage          = "Le stockage de session personnalisé n'implémente pas la méthode requise '{0}()'."
    authenticationMethodDoesNotExistExceptionMessage                  = "La méthode d'authentification n'existe pas : {0}"
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = "La fonction Webhooks n'est pas prise en charge dans OpenAPI v3.0.x"
    invalidContentTypeForSchemaExceptionMessage                       = "'content-type' invalide trouvé pour le schéma : {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "Aucun ScriptBlock de déverrouillage fourni pour déverrouiller le coffre '{0}'"
    definitionTagMessage                                              = 'Définition {0} :'
    failedToOpenRunspacePoolExceptionMessage                          = "Échec de l'ouverture de RunspacePool : {0}"
    failedToCloseRunspacePoolExceptionMessage                         = 'Échec de la fermeture du RunspacePool: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[Verbe] {0} : Aucune logique transmise'
    noMutexFoundExceptionMessage                                      = "Aucun mutex trouvé appelé '{0}'"
    documentationMessage                                              = 'Documentation'
    timerAlreadyDefinedExceptionMessage                               = '[Minuteur] {0}: Minuteur déjà défini.'
    invalidPortExceptionMessage                                       = 'Le port ne peut pas être négatif : {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = 'Le nom du dossier Views existe déjà: {0}'
    noNameForWebSocketResetExceptionMessage                           = 'Aucun Nom fourni pour réinitialiser le WebSocket.'
    mergeDefaultAuthNotInListExceptionMessage                         = "L'authentification MergeDefault '{0}' n'est pas dans la liste d'authentification fournie."
    descriptionRequiredExceptionMessage                               = 'Une description est requise.'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'Le nom de la page doit être une valeur alphanumérique valide: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = "La valeur par défaut n'est pas un booléen et ne fait pas partie de l'énumération."
    openApiComponentSchemaDoesNotExistExceptionMessage                = "Le schéma du composant OpenApi {0} n'existe pas."
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[Minuteur] {0}: {1} doit être supérieur à 0.'
    taskTimedOutExceptionMessage                                      = 'La tâche a expiré après {0}ms.'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[Horaire] {0}: Ne peut pas avoir un 'StartTime' après 'EndTime'"
    infoVersionMandatoryMessage                                       = 'info.version est obligatoire.'
    cannotUnlockNullObjectExceptionMessage                            = 'Impossible de déverrouiller un objet nul.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = "Un ScriptBlock non vide est requis pour le schéma d'authentification personnalisé."
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = "Un ScriptBlock non vide est requis pour la méthode d'authentification."
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "La validation d'un schéma qui inclut 'oneof' n'est pas prise en charge."
    routeParameterCannotBeNullExceptionMessage                        = "Le paramètre 'Route' ne peut pas être nul."
    cacheStorageAlreadyExistsExceptionMessage                         = "Un stockage de cache nommé '{0}' existe déjà."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "La méthode de sortie fournie pour la méthode de journalisation '{0}' nécessite un ScriptBlock valide."
    scopedVariableAlreadyDefinedExceptionMessage                      = 'La variable à portée est déjà définie : {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = "OAuth2 nécessite une URL d'autorisation."
    pathNotExistExceptionMessage                                      = "Le chemin n'existe pas : {0}"
    noDomainServerNameForWindowsAdAuthExceptionMessage                = "Aucun nom de serveur de domaine n'a été fourni pour l'authentification Windows AD."
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = "La date fournie est postérieure à l'heure de fin du Horaire à {0}"
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = 'Le caractère générique * pour les Méthodes est incompatible avec le commutateur AutoMethods.'
    cannotSupplyIntervalForYearExceptionMessage                       = "Impossible de fournir une valeur d'intervalle pour chaque année."
    missingComponentsMessage                                          = 'Composant(s) manquant(s)'
    invalidStrictTransportSecurityDurationExceptionMessage            = 'Durée Strict-Transport-Security invalide fournie : {0}. Doit être supérieure à 0.'
    noSecretForHmac512ExceptionMessage                                = 'Aucun secret fourni pour le hachage HMAC512.'
    daysInMonthExceededExceptionMessage                               = "{0} n'a que {1} jours, mais {2} a été fourni."
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'Un ScriptBlock non vide est requis pour la méthode de journalisation personnalisée.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = "L'attribut d'encodage s'applique uniquement aux corps de requête multipart et application/x-www-form-urlencoded."
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = "La date fournie est antérieure à l'heure de début du Horaire à {0}"
    unlockSecretRequiredExceptionMessage                              = "Une propriété 'UnlockSecret' est requise lors de l'utilisation de Microsoft.PowerShell.SecretStore"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: Aucune logique passée.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = 'Un analyseur de corps est déjà défini pour le type de contenu {0}.'
    invalidJwtSuppliedExceptionMessage                                = 'JWT fourni invalide.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'Des sessions sont nécessaires pour utiliser les messages Flash.'
    semaphoreAlreadyExistsExceptionMessage                            = 'Un sémaphore avec le nom suivant existe déjà: {0}'
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = "Algorithme de l'en-tête JWT fourni invalide."
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "Le fournisseur OAuth2 ne supporte pas le type de subvention 'password' requis par l'utilisation d'un InnerScheme."
    invalidAliasFoundExceptionMessage                                 = 'Alias {0} non valide trouvé : {1}'
    scheduleDoesNotExistExceptionMessage                              = "Le Horaire '{0}' n'existe pas."
    accessMethodNotExistExceptionMessage                              = "La méthode d'accès n'existe pas : {0}"
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "Le fournisseur OAuth2 ne supporte pas le type de réponse 'code'."
    untestedPowerShellVersionWarningMessage                           = "[AVERTISSEMENT] Pode {0} n'a pas été testé sur PowerShell {1}, car il n'était pas disponible lors de la sortie de Pode."
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "Un coffre-fort secret avec le nom '{0}' a déjà été enregistré lors de l'importation automatique des coffres-forts secrets."
    schemeRequiresValidScriptBlockExceptionMessage                    = "Le schéma fourni pour le validateur d'authentification '{0}' nécessite un ScriptBlock valide."
    serverLoopingMessage                                              = 'Boucle du serveur toutes les {0} secondes'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'Les empreintes digitales/Noms de certificat ne sont pris en charge que sous Windows.'
    sseConnectionNameRequiredExceptionMessage                         = "Un nom de connexion SSE est requis, soit de -Name soit de `$WebEvent.Sse.Name"
    invalidMiddlewareTypeExceptionMessage                             = "Un des Middlewares fournis est d'un type non valide. Attendu ScriptBlock ou Hashtable, mais a obtenu : {0}"
    noSecretForJwtSignatureExceptionMessage                           = 'Aucun secret fourni pour la signature JWT.'
    modulePathDoesNotExistExceptionMessage                            = "Le chemin du module n'existe pas : {0}"
    taskAlreadyDefinedExceptionMessage                                = '[Tâche] {0} : Tâche déjà définie.'
    verbAlreadyDefinedExceptionMessage                                = '[Verbe] {0} : Déjà défini'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'Les certificats client ne sont pris en charge que sur les points de terminaison HTTPS.'
    endpointNameNotExistExceptionMessage                              = "Un point de terminaison avec le nom '{0}' n'existe pas."
    middlewareNoLogicSuppliedExceptionMessage                         = '[Middleware] : Aucune logique fournie dans le ScriptBlock.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'Un ScriptBlock est requis pour fusionner plusieurs utilisateurs authentifiés en un seul objet lorsque Valid est All.'
    secretVaultAlreadyRegisteredExceptionMessage                      = "Un Coffre-Fort de Secrets avec le nom '{0}' a déjà été enregistré{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "AVERTISSEMENT : Titre, Version et Description sur 'Enable-PodeOpenApi' sont obsolètes. Veuillez utiliser 'Add-PodeOAInfo' à la place."
    undefinedOpenApiReferencesMessage                                 = 'Références OpenAPI non définies :'
    doneMessage                                                       = 'Terminé'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = 'Cette version de Swagger-Editor ne prend pas en charge OpenAPI 3.1'
    durationMustBeZeroOrGreaterExceptionMessage                       = 'La durée doit être égale ou supérieure à 0, mais a obtenu : {0}s'
    viewsPathDoesNotExistExceptionMessage                             = "Le chemin des Views n'existe pas: {0}"
    discriminatorIncompatibleWithAllOfExceptionMessage                = "Le paramètre 'Discriminator' est incompatible avec 'allOf'."
    noNameForWebSocketSendMessageExceptionMessage                     = 'Aucun Nom fourni pour envoyer un message au WebSocket.'
    hashtableMiddlewareNoLogicExceptionMessage                        = "Un Middleware Hashtable fourni n'a aucune logique définie."
    openApiInfoMessage                                                = 'Informations OpenAPI :'
    invalidSchemeForAuthValidatorExceptionMessage                     = "Le schéma '{0}' fourni pour le validateur d'authentification '{1}' nécessite un ScriptBlock valide."
    sseFailedToBroadcastExceptionMessage                              = 'SSE a échoué à diffuser en raison du niveau de diffusion SSE défini pour {0} : {1}.'
    adModuleWindowsOnlyExceptionMessage                               = 'Le module Active Directory est uniquement disponible sur Windows.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = 'Durée Access-Control-Max-Age invalide fournie : {0}. Doit être supérieure à 0.'
    openApiDefinitionAlreadyExistsExceptionMessage                    = 'La définition OpenAPI nommée {0} existe déjà.'
    renamePodeOADefinitionTagExceptionMessage                     = "Rename-PodeOADefinitionTag ne peut pas être utilisé à l'intérieur d'un 'ScriptBlock' de Select-PodeOADefinition."
    fnDoesNotAcceptArrayAsPipelineInputExceptionMessage               = "La fonction '{0}' n'accepte pas un tableau en tant qu'entrée de pipeline."
    loggingAlreadyEnabledExceptionMessage                             = "La journalisation '{0}' a déjà été activée."
    invalidEncodingExceptionMessage                                   = 'Encodage invalide : {0}'
    syslogProtocolExceptionMessage                                    = 'Le protocole Syslog ne peut utiliser que RFC3164 ou RFC5424.'

}

