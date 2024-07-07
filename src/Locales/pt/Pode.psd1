@{
    schemaValidationRequiresPowerShell610ExceptionMessage             = 'A validação do esquema requer a versão 6.1.0 ou superior do PowerShell.'
    customAccessPathOrScriptBlockRequiredExceptionMessage             = 'É necessário um Caminho ou ScriptBlock para obter os valores de acesso personalizados.'
    operationIdMustBeUniqueForArrayExceptionMessage                   = 'OperationID: {0} deve ser único e não pode ser aplicado a uma matriz.'
    endpointNotDefinedForRedirectingExceptionMessage                  = "Não foi definido um ponto de extremidade chamado '{0}' para redirecionamento."
    filesHaveChangedMessage                                           = 'Os seguintes arquivos foram alterados:'
    iisAspnetcoreTokenMissingExceptionMessage                         = 'IIS ASPNETCORE_TOKEN está ausente.'
    minValueGreaterThanMaxExceptionMessage                            = 'O valor mínimo para {0} não deve ser maior que o valor máximo.'
    noLogicPassedForRouteExceptionMessage                             = 'Nenhuma lógica passada para a Rota: {0}'
    scriptPathDoesNotExistExceptionMessage                            = 'O caminho do script não existe: {0}'
    mutexAlreadyExistsExceptionMessage                                = 'Já existe um mutex com o seguinte nome: {0}'
    listeningOnEndpointsMessage                                       = 'Ouvindo nos seguintes {0} endpoint(s) [{1} thread(s)]:'
    unsupportedFunctionInServerlessContextExceptionMessage            = 'A função {0} não é suportada em um contexto serverless.'
    expectedNoJwtSignatureSuppliedExceptionMessage                    = 'Esperava-se que nenhuma assinatura JWT fosse fornecida.'
    secretAlreadyMountedExceptionMessage                              = "Um Segredo com o nome '{0}' já foi montado."
    failedToAcquireLockExceptionMessage                               = 'Falha ao adquirir um bloqueio no objeto.'
    noPathSuppliedForStaticRouteExceptionMessage                      = '[{0}]: Nenhum caminho fornecido para a Rota Estática.'
    invalidHostnameSuppliedExceptionMessage                           = 'Nome de host fornecido inválido: {0}'
    authMethodAlreadyDefinedExceptionMessage                          = 'Método de autenticação já definido: {0}'
    csrfCookieRequiresSecretExceptionMessage                          = "Ao usar cookies para CSRF, é necessário um Segredo. Você pode fornecer um Segredo ou definir o segredo global do Cookie - (Set-PodeCookieSecret '<value>' -Global)"
    nonEmptyScriptBlockRequiredForPageRouteExceptionMessage           = 'Um ScriptBlock não vazio é necessário para criar uma Rota de Página.'
    noPropertiesMutuallyExclusiveExceptionMessage                     = "O parâmetro 'NoProperties' é mutuamente exclusivo com 'Properties', 'MinProperties' e 'MaxProperties'."
    incompatiblePodeDllExceptionMessage                               = 'Uma versão incompatível existente do Pode.DLL {0} está carregada. É necessária a versão {1}. Abra uma nova sessão do Powershell/pwsh e tente novamente.'
    accessMethodDoesNotExistExceptionMessage                          = 'O método de acesso não existe: {0}.'
    scheduleAlreadyDefinedExceptionMessage                            = '[Cronograma] {0}: Cronograma já definida.'
    secondsValueCannotBeZeroOrLessExceptionMessage                    = 'O valor dos segundos não pode ser 0 ou inferior para {0}'
    pathToLoadNotFoundExceptionMessage                                = 'Caminho para carregar {0} não encontrado: {1}'
    failedToImportModuleExceptionMessage                              = 'Falha ao importar módulo: {0}'
    endpointNotExistExceptionMessage                                  = "O ponto de extremidade com o protocolo '{0}' e endereço '{1}' ou endereço local '{2}' não existe."
    terminatingMessage                                                = 'Terminando...'
    noCommandsSuppliedToConvertToRoutesExceptionMessage               = 'Nenhum comando fornecido para converter em Rotas.'
    invalidTaskTypeExceptionMessage                                   = 'O tipo de tarefa é inválido, esperado [System.Threading.Tasks.Task] ou [hashtable].'
    alreadyConnectedToWebSocketExceptionMessage                       = "Já conectado ao websocket com o nome '{0}'"
    crlfMessageEndCheckOnlySupportedOnTcpEndpointsExceptionMessage    = 'A verificação de fim de mensagem CRLF é suportada apenas em endpoints TCP.'
    testPodeOAComponentSchemaNeedToBeEnabledExceptionMessage          = "'Test-PodeOAComponentSchema' precisa ser habilitado usando 'Enable-PodeOpenApi -EnableSchemaValidation'"
    adModuleNotInstalledExceptionMessage                              = 'O módulo Active Directory não está instalado.'
    cronExpressionInvalidExceptionMessage                             = 'A expressão Cron deve consistir apenas em 5 partes: {0}'
    noSessionToSetOnResponseExceptionMessage                          = 'Não há sessão disponível para definir na resposta.'
    valueOutOfRangeExceptionMessage                                   = "O valor '{0}' para {1} é inválido, deve estar entre {2} e {3}"
    loggingMethodAlreadyDefinedExceptionMessage                       = 'Método de registro já definido: {0}'
    noSecretForHmac256ExceptionMessage                                = 'Nenhum segredo fornecido para o hash HMAC256.'
    eolPowerShellWarningMessage                                       = '[AVISO] Pode {0} não foi testado no PowerShell {1}, pois está em EOL.'
    runspacePoolFailedToLoadExceptionMessage                          = '{0} Falha ao carregar RunspacePool.'
    noEventRegisteredExceptionMessage                                 = 'Nenhum evento {0} registrado: {1}'
    scheduleCannotHaveNegativeLimitExceptionMessage                   = '[Cronograma] {0}: Não pode ter um limite negativo.'
    openApiRequestStyleInvalidForParameterExceptionMessage            = 'O estilo da solicitação OpenApi não pode ser {0} para um parâmetro {1}.'
    openApiDocumentNotCompliantExceptionMessage                       = 'O documento OpenAPI não está em conformidade.'
    taskDoesNotExistExceptionMessage                                  = "A tarefa '{0}' não existe."
    scopedVariableNotFoundExceptionMessage                            = 'Variável de escopo não encontrada: {0}'
    sessionsRequiredForCsrfExceptionMessage                           = 'Sessões são necessárias para usar CSRF, a menos que você queira usar cookies.'
    nonEmptyScriptBlockRequiredForLoggingMethodExceptionMessage       = 'Um ScriptBlock não vazio é necessário para o método de registro.'
    credentialsPassedWildcardForHeadersLiteralExceptionMessage        = 'Quando as Credenciais são passadas, o caractere curinga * para os Cabeçalhos será interpretado como uma string literal e não como um caractere curinga.'
    podeNotInitializedExceptionMessage                                = 'Pode não foi inicializado.'
    multipleEndpointsForGuiMessage                                    = 'Múltiplos endpoints definidos, apenas o primeiro será usado para a GUI.'
    operationIdMustBeUniqueExceptionMessage                           = 'OperationID: {0} deve ser único.'
    invalidJsonJwtExceptionMessage                                    = 'Valor JSON inválido encontrado no JWT'
    noAlgorithmInJwtHeaderExceptionMessage                            = 'Nenhum algoritmo fornecido no Cabeçalho JWT.'
    openApiVersionPropertyMandatoryExceptionMessage                   = 'A propriedade da versão do OpenApi é obrigatória.'
    limitValueCannotBeZeroOrLessExceptionMessage                      = 'O valor limite não pode ser 0 ou inferior para {0}'
    timerDoesNotExistExceptionMessage                                 = "O temporizador '{0}' não existe."
    openApiGenerationDocumentErrorMessage                             = 'Erro no documento de geração do OpenAPI:'
    routeAlreadyContainsCustomAccessExceptionMessage                  = "A rota '[{0}] {1}' já contém Acesso Personalizado com o nome '{2}'"
    maximumConcurrentWebSocketThreadsLessThanMinimumExceptionMessage  = 'O número máximo de threads concorrentes do WebSocket não pode ser menor que o mínimo de {0}, mas foi obtido: {1}'
    middlewareAlreadyDefinedExceptionMessage                          = '[Middleware] {0}: Middleware já definido.'
    invalidAtomCharacterExceptionMessage                              = 'Caractere atômico inválido: {0}'
    invalidCronAtomFormatExceptionMessage                             = 'Formato de átomo cron inválido encontrado: {0}'
    cacheStorageNotFoundForRetrieveExceptionMessage                   = "Armazenamento em cache com o nome '{0}' não encontrado ao tentar recuperar o item em cache '{1}'."
    headerMustHaveNameInEncodingContextExceptionMessage               = 'O cabeçalho deve ter um nome quando usado em um contexto de codificação.'
    moduleDoesNotContainFunctionExceptionMessage                      = 'O módulo {0} não contém a função {1} para converter em uma Rota.'
    pathToIconForGuiDoesNotExistExceptionMessage                      = 'O caminho para o ícone da interface gráfica não existe: {0}'
    noTitleSuppliedForPageExceptionMessage                            = 'Nenhum título fornecido para a página {0}.'
    certificateSuppliedForNonHttpsWssEndpointExceptionMessage         = 'Certificado fornecido para endpoint que não é HTTPS/WSS.'
    cannotLockNullObjectExceptionMessage                              = 'Não é possível bloquear um objeto nulo.'
    showPodeGuiOnlyAvailableOnWindowsExceptionMessage                 = 'Show-PodeGui está atualmente disponível apenas para Windows PowerShell e PowerShell 7+ no Windows.'
    unlockSecretButNoScriptBlockExceptionMessage                      = 'Segredo de desbloqueio fornecido para tipo de Cofre Secreto personalizado, mas nenhum ScriptBlock de desbloqueio fornecido.'
    invalidIpAddressExceptionMessage                                  = 'O endereço IP fornecido é inválido: {0}'
    maxDaysInvalidExceptionMessage                                    = 'MaxDays deve ser igual ou maior que 0, mas foi obtido: {0}'
    noRemoveScriptBlockForVaultExceptionMessage                       = "Nenhum ScriptBlock fornecido para remover segredos do cofre '{0}'"
    noSecretExpectedForNoSignatureExceptionMessage                    = 'Não era esperado nenhum segredo para nenhuma assinatura.'
    noCertificateFoundExceptionMessage                                = "Nenhum certificado encontrado em {0}{1} para '{2}'"
    minValueInvalidExceptionMessage                                   = "O valor mínimo '{0}' para {1} é inválido, deve ser maior ou igual a {2}"
    accessRequiresAuthenticationOnRoutesExceptionMessage              = 'O acesso requer autenticação nas rotas.'
    noSecretForHmac384ExceptionMessage                                = 'Nenhum segredo fornecido para o hash HMAC384.'
    windowsLocalAuthSupportIsForWindowsOnlyExceptionMessage           = 'O suporte à Autenticação Local do Windows é apenas para Windows.'
    definitionTagNotDefinedExceptionMessage                           = 'A tag de definição {0} não existe.'
    noComponentInDefinitionExceptionMessage                           = 'Nenhum componente do tipo {0} chamado {1} está disponível na definição {2}.'
    noSmtpHandlersDefinedExceptionMessage                             = 'Nenhum manipulador SMTP definido.'
    sessionMiddlewareAlreadyInitializedExceptionMessage               = 'O Middleware de Sessão já foi inicializado.'
    reusableComponentPathItemsNotAvailableInOpenApi30ExceptionMessage = "O recurso de componente reutilizável 'pathItems' não está disponível no OpenAPI v3.0."
    wildcardHeadersIncompatibleWithAutoHeadersExceptionMessage        = 'O caractere curinga * para os Cabeçalhos é incompatível com a chave AutoHeaders.'
    noDataForFileUploadedExceptionMessage                             = "Nenhum dado para o arquivo '{0}' foi enviado na solicitação."
    sseOnlyConfiguredOnEventStreamAcceptHeaderExceptionMessage        = 'SSE só pode ser configurado em solicitações com um valor de cabeçalho Accept de text/event-stream.'
    noSessionAvailableToSaveExceptionMessage                          = 'Não há sessão disponível para salvar.'
    pathParameterRequiresRequiredSwitchExceptionMessage               = "Se a localização do parâmetro for 'Path', o parâmetro de switch 'Required' é obrigatório."
    noOpenApiUrlSuppliedExceptionMessage                              = 'Nenhuma URL do OpenAPI fornecida para {0}.'
    maximumConcurrentSchedulesInvalidExceptionMessage                 = 'As cronogramas simultâneas máximas devem ser >=1, mas obtidas: {0}'
    snapinsSupportedOnWindowsPowershellOnlyExceptionMessage           = 'Os Snapins são suportados apenas no Windows PowerShell.'
    eventViewerLoggingSupportedOnWindowsOnlyExceptionMessage          = 'O registro no Visualizador de Eventos é suportado apenas no Windows.'
    parametersMutuallyExclusiveExceptionMessage                       = "Os parâmetros '{0}' e '{1}' são mutuamente exclusivos."
    pathItemsFeatureNotSupportedInOpenApi30ExceptionMessage           = 'O recurso PathItems não é suportado no OpenAPI v3.0.x'
    openApiParameterRequiresNameExceptionMessage                      = 'O parâmetro OpenApi requer um nome especificado.'
    maximumConcurrentTasksLessThanMinimumExceptionMessage             = 'O número máximo de tarefas concorrentes não pode ser menor que o mínimo de {0}, mas foi obtido: {1}'
    noSemaphoreFoundExceptionMessage                                  = "Nenhum semáforo encontrado chamado '{0}'"
    singleValueForIntervalExceptionMessage                            = 'Você pode fornecer apenas um único valor {0} ao usar intervalos.'
    jwtNotYetValidExceptionMessage                                    = 'O JWT ainda não é válido para uso.'
    verbAlreadyDefinedForUrlExceptionMessage                          = '[Verbo] {0}: Já definido para {1}'
    noSecretNamedMountedExceptionMessage                              = "Nenhum Segredo com o nome '{0}' foi montado."
    moduleOrVersionNotFoundExceptionMessage                           = 'Módulo ou versão não encontrada em {0}: {1}@{2}'
    noScriptBlockSuppliedExceptionMessage                             = 'Nenhum ScriptBlock fornecido.'
    noSecretVaultRegisteredExceptionMessage                           = "Nenhum Cofre de Segredos com o nome '{0}' foi registrado."
    nameRequiredForEndpointIfRedirectToSuppliedExceptionMessage       = 'Um nome é necessário para o endpoint se o parâmetro RedirectTo for fornecido.'
    openApiLicenseObjectRequiresNameExceptionMessage                  = "O objeto OpenAPI 'license' requer a propriedade 'name'. Use o parâmetro -LicenseName."
    sourcePathDoesNotExistForStaticRouteExceptionMessage              = '{0}: O caminho de origem fornecido para a Rota Estática não existe: {1}'
    noNameForWebSocketDisconnectExceptionMessage                      = 'Nenhum nome fornecido para desconectar do WebSocket.'
    certificateExpiredExceptionMessage                                = "O certificado '{0}' expirou: {1}"
    secretVaultUnlockExpiryDateInPastExceptionMessage                 = 'A data de expiração de desbloqueio do Cofre de Segredos está no passado (UTC): {0}'
    invalidWebExceptionTypeExceptionMessage                           = 'A exceção é de um tipo inválido, deve ser WebException ou HttpRequestException, mas foi obtido: {0}'
    invalidSecretValueTypeExceptionMessage                            = 'O valor do segredo é de um tipo inválido. Tipos esperados: String, SecureString, HashTable, Byte[] ou PSCredential. Mas obtido: {0}'
    explicitTlsModeOnlySupportedOnSmtpsTcpsEndpointsExceptionMessage  = 'O modo TLS explícito é suportado apenas em endpoints SMTPS e TCPS.'
    discriminatorMappingRequiresDiscriminatorPropertyExceptionMessage = "O parâmetro 'DiscriminatorMapping' só pode ser usado quando 'DiscriminatorProperty' está presente."
    scriptErrorExceptionMessage                                       = "Erro '{0}' no script {1} {2} (linha {3}) caractere {4} executando {5} em {6} objeto '{7}' Classe: {8} ClasseBase: {9}"
    cannotSupplyIntervalForQuarterExceptionMessage                    = 'Não é possível fornecer um valor de intervalo para cada trimestre.'
    scheduleEndTimeMustBeInFutureExceptionMessage                     = '[Cronograma] {0}: O valor de EndTime deve estar no futuro.'
    invalidJwtSignatureSuppliedExceptionMessage                       = 'Assinatura JWT fornecida inválida.'
    noSetScriptBlockForVaultExceptionMessage                          = "Nenhum ScriptBlock fornecido para atualizar/criar segredos no cofre '{0}'"
    accessMethodNotExistForMergingExceptionMessage                    = 'O método de acesso não existe para a mesclagem: {0}'
    defaultAuthNotInListExceptionMessage                              = "A Autenticação Default '{0}' não está na lista de Autenticação fornecida."
    parameterHasNoNameExceptionMessage                                = "O parâmetro não tem nome. Dê um nome a este componente usando o parâmetro 'Name'."
    methodPathAlreadyDefinedForUrlExceptionMessage                    = '[{0}] {1}: Já definido para {2}'
    fileWatcherAlreadyDefinedExceptionMessage                         = "Um Observador de Arquivos chamado '{0}' já foi definido."
    noServiceHandlersDefinedExceptionMessage                          = 'Nenhum manipulador de serviço definido.'
    secretRequiredForCustomSessionStorageExceptionMessage             = 'Um segredo é necessário ao usar armazenamento de sessão personalizado.'
    secretManagementModuleNotInstalledExceptionMessage                = 'O módulo Microsoft.PowerShell.SecretManagement não está instalado.'
    noPathSuppliedForRouteExceptionMessage                            = 'Nenhum caminho fornecido para a Rota.'
    validationOfAnyOfSchemaNotSupportedExceptionMessage               = "A validação de um esquema que inclui 'anyof' não é suportada."
    iisAuthSupportIsForWindowsOnlyExceptionMessage                    = 'O suporte à Autenticação IIS é apenas para Windows.'
    oauth2InnerSchemeInvalidExceptionMessage                          = 'O OAuth2 InnerScheme só pode ser um de autenticação Basic ou Form, mas foi obtido: {0}'
    noRoutePathSuppliedForPageExceptionMessage                        = 'Nenhum caminho de rota fornecido para a página {0}.'
    cacheStorageNotFoundForExistsExceptionMessage                     = "Armazenamento em cache com o nome '{0}' não encontrado ao tentar verificar se o item em cache '{1}' existe."
    handlerAlreadyDefinedExceptionMessage                             = '[{0}] {1}: Manipulador já definido.'
    sessionsNotConfiguredExceptionMessage                             = 'As sessões não foram configuradas.'
    propertiesTypeObjectAssociationExceptionMessage                   = 'Apenas propriedades do tipo Objeto podem ser associadas com {0}.'
    sessionsRequiredForSessionPersistentAuthExceptionMessage          = 'Sessões são necessárias para usar a autenticação persistente por sessão.'
    invalidPathWildcardOrDirectoryExceptionMessage                    = 'O caminho fornecido não pode ser um curinga ou um diretório: {0}'
    accessMethodAlreadyDefinedExceptionMessage                        = 'Método de acesso já definido: {0}'
    parametersValueOrExternalValueMandatoryExceptionMessage           = "Os parâmetros 'Value' ou 'ExternalValue' são obrigatórios."
    maximumConcurrentTasksInvalidExceptionMessage                     = 'O número máximo de tarefas concorrentes deve ser >=1, mas foi obtido: {0}'
    cannotCreatePropertyWithoutTypeExceptionMessage                   = 'Não é possível criar a propriedade porque nenhum tipo é definido.'
    authMethodNotExistForMergingExceptionMessage                      = 'O método de autenticação não existe para mesclagem: {0}'
    maxValueInvalidExceptionMessage                                   = "O valor máximo '{0}' para {1} é inválido, deve ser menor ou igual a {2}"
    endpointAlreadyDefinedExceptionMessage                            = "Um ponto de extremidade chamado '{0}' já foi definido."
    eventAlreadyRegisteredExceptionMessage                            = 'Evento {0} já registrado: {1}'
    parameterNotSuppliedInRequestExceptionMessage                     = "Um parâmetro chamado '{0}' não foi fornecido na solicitação ou não há dados disponíveis."
    cacheStorageNotFoundForSetExceptionMessage                        = "Armazenamento em cache com o nome '{0}' não encontrado ao tentar definir o item em cache '{1}'."
    methodPathAlreadyDefinedExceptionMessage                          = '[{0}] {1}: Já definido.'
    errorLoggingAlreadyEnabledExceptionMessage                        = 'O registro de erros já está habilitado.'
    valueForUsingVariableNotFoundExceptionMessage                     = "Valor para '`$using:{0}' não pôde ser encontrado."
    rapidPdfDoesNotSupportOpenApi31ExceptionMessage                   = 'A ferramenta de documentos RapidPdf não suporta OpenAPI 3.1'
    oauth2ClientSecretRequiredExceptionMessage                        = 'OAuth2 requer um Client Secret quando não se usa PKCE.'
    invalidBase64JwtExceptionMessage                                  = 'Valor codificado Base64 inválido encontrado no JWT'
    noSessionToCalculateDataHashExceptionMessage                      = 'Nenhuma sessão disponível para calcular o hash dos dados.'
    cacheStorageNotFoundForRemoveExceptionMessage                     = "Armazenamento em cache com o nome '{0}' não encontrado ao tentar remover o item em cache '{1}'."
    csrfMiddlewareNotInitializedExceptionMessage                      = 'O Middleware CSRF não foi inicializado.'
    infoTitleMandatoryMessage                                         = 'info.title é obrigatório.'
    typeCanOnlyBeAssociatedWithObjectExceptionMessage                 = 'O tipo {0} só pode ser associado a um Objeto.'
    userFileDoesNotExistExceptionMessage                              = 'O arquivo do usuário não existe: {0}'
    routeParameterNeedsValidScriptblockExceptionMessage               = 'O parâmetro da Rota precisa de um ScriptBlock válido e não vazio.'
    nextTriggerCalculationErrorExceptionMessage                       = 'Parece que algo deu errado ao tentar calcular a próxima data e hora do gatilho: {0}'
    cannotLockValueTypeExceptionMessage                               = 'Não é possível bloquear um [ValueType].'
    failedToCreateOpenSslCertExceptionMessage                         = 'Falha ao criar o certificado OpenSSL: {0}'
    jwtExpiredExceptionMessage                                        = 'O JWT expirou.'
    openingGuiMessage                                                 = 'Abrindo a GUI.'
    multiTypePropertiesRequireOpenApi31ExceptionMessage               = 'Propriedades de múltiplos tipos requerem a versão 3.1 ou superior do OpenApi.'
    noNameForWebSocketRemoveExceptionMessage                          = 'Nenhum nome fornecido para remover o WebSocket.'
    maxSizeInvalidExceptionMessage                                    = 'MaxSize deve ser igual ou maior que 0, mas foi obtido: {0}'
    iisShutdownMessage                                                = '(Desligamento do IIS)'
    cannotUnlockValueTypeExceptionMessage                             = 'Não é possível desbloquear um [ValueType].'
    noJwtSignatureForAlgorithmExceptionMessage                        = 'Nenhuma assinatura JWT fornecida para {0}.'
    maximumConcurrentWebSocketThreadsInvalidExceptionMessage          = 'O número máximo de threads concorrentes do WebSocket deve ser >=1, mas foi obtido: {0}'
    acknowledgeMessageOnlySupportedOnSmtpTcpEndpointsExceptionMessage = 'A mensagem de reconhecimento é suportada apenas em endpoints SMTP e TCP.'
    failedToConnectToUrlExceptionMessage                              = 'Falha ao conectar ao URL: {0}'
    failedToAcquireMutexOwnershipExceptionMessage                     = 'Falha ao adquirir a propriedade do mutex. Nome do mutex: {0}'
    sessionsRequiredForOAuth2WithPKCEExceptionMessage                 = 'Sessões são necessárias para usar OAuth2 com PKCE'
    failedToConnectToWebSocketExceptionMessage                        = 'Falha ao conectar ao WebSocket: {0}'
    unsupportedObjectExceptionMessage                                 = 'Objeto não suportado'
    failedToParseAddressExceptionMessage                              = "Falha ao analisar '{0}' como um endereço IP/Host:Port válido"
    mustBeRunningWithAdminPrivilegesExceptionMessage                  = 'Deve estar sendo executado com privilégios de administrador para escutar endereços que não sejam localhost.'
    specificationMessage                                              = 'Especificação'
    cacheStorageNotFoundForClearExceptionMessage                      = "Armazenamento em cache com o nome '{0}' não encontrado ao tentar limpar o cache."
    restartingServerMessage                                           = 'Reiniciando o servidor...'
    cannotSupplyIntervalWhenEveryIsNoneExceptionMessage               = "Não é possível fornecer um intervalo quando o parâmetro 'Every' está definido como None."
    unsupportedJwtAlgorithmExceptionMessage                           = 'O algoritmo JWT não é atualmente suportado: {0}'
    websocketsNotConfiguredForSignalMessagesExceptionMessage          = 'WebSockets não estão configurados para enviar mensagens de sinal.'
    invalidLogicTypeInHashtableMiddlewareExceptionMessage             = 'Um Middleware do tipo Hashtable fornecido tem um tipo de lógica inválido. Esperado ScriptBlock, mas obtido: {0}'
    maximumConcurrentSchedulesLessThanMinimumExceptionMessage         = 'As cronogramas simultâneas máximas não podem ser inferiores ao mínimo de {0}, mas obtidas: {1}'
    failedToAcquireSemaphoreOwnershipExceptionMessage                 = 'Falha ao adquirir a propriedade do semáforo. Nome do semáforo: {0}'
    propertiesParameterWithoutNameExceptionMessage                    = 'Os parâmetros Properties não podem ser usados se a propriedade não tiver um nome.'
    customSessionStorageMethodNotImplementedExceptionMessage          = "O armazenamento de sessão personalizado não implementa o método requerido '{0}()'."
    authenticationMethodDoesNotExistExceptionMessage                  = 'O método de autenticação não existe: {0}'
    webhooksFeatureNotSupportedInOpenApi30ExceptionMessage            = 'O recurso Webhooks não é suportado no OpenAPI v3.0.x'
    invalidContentTypeForSchemaExceptionMessage                       = "'content-type' inválido encontrado para o esquema: {0}"
    noUnlockScriptBlockForVaultExceptionMessage                       = "Nenhum ScriptBlock de desbloqueio fornecido para desbloquear o cofre '{0}'"
    definitionTagMessage                                              = 'Definição {0}:'
    failedToOpenRunspacePoolExceptionMessage                          = 'Falha ao abrir o RunspacePool: {0}'
    failedToCloseRunspacePoolExceptionMessage                         = 'Falha ao fechar RunspacePool: {0}'
    verbNoLogicPassedExceptionMessage                                 = '[Verbo] {0}: Nenhuma lógica passada'
    noMutexFoundExceptionMessage                                      = "Nenhum mutex encontrado chamado '{0}'"
    documentationMessage                                              = 'Documentação'
    timerAlreadyDefinedExceptionMessage                               = '[Temporizador] {0}: Temporizador já definido.'
    invalidPortExceptionMessage                                       = 'A porta não pode ser negativa: {0}'
    viewsFolderNameAlreadyExistsExceptionMessage                      = 'O nome da pasta Views já existe: {0}'
    noNameForWebSocketResetExceptionMessage                           = 'Nenhum nome fornecido para redefinir o WebSocket.'
    mergeDefaultAuthNotInListExceptionMessage                         = "A Autenticação MergeDefault '{0}' não está na lista de Autenticação fornecida."
    descriptionRequiredExceptionMessage                               = 'É necessária uma descrição.'
    pageNameShouldBeAlphaNumericExceptionMessage                      = 'O nome da página deve ser um valor alfanumérico válido: {0}'
    defaultValueNotBooleanOrEnumExceptionMessage                      = 'O valor padrão não é booleano e não faz parte do enum.'
    openApiComponentSchemaDoesNotExistExceptionMessage                = 'O esquema do componente OpenApi {0} não existe.'
    timerParameterMustBeGreaterThanZeroExceptionMessage               = '[Temporizador] {0}: {1} deve ser maior que 0.'
    taskTimedOutExceptionMessage                                      = 'A tarefa expirou após {0}ms.'
    scheduleStartTimeAfterEndTimeExceptionMessage                     = "[Cronograma] {0}: Não pode ter um 'StartTime' após o 'EndTime'"
    infoVersionMandatoryMessage                                       = 'info.version é obrigatório.'
    cannotUnlockNullObjectExceptionMessage                            = 'Não é possível desbloquear um objeto nulo.'
    nonEmptyScriptBlockRequiredForCustomAuthExceptionMessage          = 'É necessário um ScriptBlock não vazio para o esquema de autenticação personalizado.'
    nonEmptyScriptBlockRequiredForAuthMethodExceptionMessage          = 'Um ScriptBlock não vazio é necessário para o método de autenticação.'
    validationOfOneOfSchemaNotSupportedExceptionMessage               = "A validação de um esquema que inclui 'oneof' não é suportada."
    routeParameterCannotBeNullExceptionMessage                        = "O parâmetro 'Route' não pode ser nulo."
    cacheStorageAlreadyExistsExceptionMessage                         = "Armazenamento em cache com o nome '{0}' já existe."
    loggingMethodRequiresValidScriptBlockExceptionMessage             = "O método de saída fornecido para o método de registro '{0}' requer um ScriptBlock válido."
    scopedVariableAlreadyDefinedExceptionMessage                      = 'Variável de escopo já definida: {0}'
    oauth2RequiresAuthorizeUrlExceptionMessage                        = 'OAuth2 requer que seja fornecida uma URL de Autorização'
    pathNotExistExceptionMessage                                      = 'O caminho não existe: {0}'
    noDomainServerNameForWindowsAdAuthExceptionMessage                = 'Nenhum nome de servidor de domínio foi fornecido para a autenticação AD do Windows'
    suppliedDateAfterScheduleEndTimeExceptionMessage                  = 'A data fornecida é posterior ao horário de término da cronograma em {0}'
    wildcardMethodsIncompatibleWithAutoMethodsExceptionMessage        = 'O caractere curinga * para os Métodos é incompatível com a chave AutoMethods.'
    cannotSupplyIntervalForYearExceptionMessage                       = 'Não é possível fornecer um valor de intervalo para cada ano.'
    missingComponentsMessage                                          = 'Componente(s) ausente(s)'
    invalidStrictTransportSecurityDurationExceptionMessage            = 'Duração inválida fornecida para Strict-Transport-Security: {0}. Deve ser maior que 0.'
    noSecretForHmac512ExceptionMessage                                = 'Nenhum segredo fornecido para o hash HMAC512.'
    daysInMonthExceededExceptionMessage                               = '{0} tem apenas {1} dias, mas {2} foi fornecido.'
    nonEmptyScriptBlockRequiredForCustomLoggingExceptionMessage       = 'Um ScriptBlock não vazio é necessário para o método de registro personalizado.'
    encodingAttributeOnlyAppliesToMultipartExceptionMessage           = 'O atributo de codificação só se aplica a corpos de solicitação multipart e application/x-www-form-urlencoded.'
    suppliedDateBeforeScheduleStartTimeExceptionMessage               = 'A data fornecida é anterior ao horário de início da cronograma em {0}'
    unlockSecretRequiredExceptionMessage                              = "É necessária uma propriedade 'UnlockSecret' ao usar Microsoft.PowerShell.SecretStore"
    noLogicPassedForMethodRouteExceptionMessage                       = '[{0}] {1}: Nenhuma lógica passada.'
    bodyParserAlreadyDefinedForContentTypeExceptionMessage            = 'Um body-parser já está definido para o tipo de conteúdo {0}.'
    invalidJwtSuppliedExceptionMessage                                = 'JWT fornecido inválido.'
    sessionsRequiredForFlashMessagesExceptionMessage                  = 'Sessões são necessárias para usar mensagens Flash.'
    semaphoreAlreadyExistsExceptionMessage                            = 'Já existe um semáforo com o seguinte nome: {0}'
    invalidJwtHeaderAlgorithmSuppliedExceptionMessage                 = 'Algoritmo de cabeçalho JWT fornecido inválido.'
    oauth2ProviderDoesNotSupportPasswordGrantTypeExceptionMessage     = "O provedor OAuth2 não suporta o grant_type 'password' necessário ao usar um InnerScheme."
    invalidAliasFoundExceptionMessage                                 = 'Alias {0} inválido encontrado: {1}'
    scheduleDoesNotExistExceptionMessage                              = "A cronograma '{0}' não existe."
    accessMethodNotExistExceptionMessage                              = 'O método de acesso não existe: {0}'
    oauth2ProviderDoesNotSupportCodeResponseTypeExceptionMessage      = "O provedor OAuth2 não suporta o response_type 'code'."
    untestedPowerShellVersionWarningMessage                           = '[AVISO] Pode {0} não foi testado no PowerShell {1}, pois não estava disponível quando o Pode foi lançado.'
    secretVaultAlreadyRegisteredAutoImportExceptionMessage            = "Um Cofre de Segredos com o nome '{0}' já foi registrado durante a importação automática de Cofres de Segredos."
    schemeRequiresValidScriptBlockExceptionMessage                    = "O esquema fornecido para o validador de autenticação '{0}' requer um ScriptBlock válido."
    serverLoopingMessage                                              = 'Looping do servidor a cada {0} segundos'
    certificateThumbprintsNameSupportedOnWindowsExceptionMessage      = 'Impressões digitais/nome do certificado são suportados apenas no Windows.'
    sseConnectionNameRequiredExceptionMessage                         = "Um nome de conexão SSE é necessário, seja de -Name ou `$WebEvent.Sse.Name."
    invalidMiddlewareTypeExceptionMessage                             = 'Um dos Middlewares fornecidos é de um tipo inválido. Esperado ScriptBlock ou Hashtable, mas obtido: {0}'
    noSecretForJwtSignatureExceptionMessage                           = 'Nenhum segredo fornecido para a assinatura JWT.'
    modulePathDoesNotExistExceptionMessage                            = 'O caminho do módulo não existe: {0}'
    taskAlreadyDefinedExceptionMessage                                = '[Tarefa] {0}: Tarefa já definida.'
    verbAlreadyDefinedExceptionMessage                                = '[Verbo] {0}: Já definido'
    clientCertificatesOnlySupportedOnHttpsEndpointsExceptionMessage   = 'Certificados de cliente são suportados apenas em endpoints HTTPS.'
    endpointNameNotExistExceptionMessage                              = "O ponto de extremidade com o nome '{0}' não existe."
    middlewareNoLogicSuppliedExceptionMessage                         = '[Middleware]: Nenhuma lógica fornecida no ScriptBlock.'
    scriptBlockRequiredForMergingUsersExceptionMessage                = 'É necessário um ScriptBlock para mesclar vários usuários autenticados em 1 objeto quando Valid é All.'
    secretVaultAlreadyRegisteredExceptionMessage                      = "Um Cofre de Segredos com o nome '{0}' já foi registrado{1}."
    deprecatedTitleVersionDescriptionWarningMessage                   = "AVISO: Título, Versão e Descrição em 'Enable-PodeOpenApi' estão obsoletos. Utilize 'Add-PodeOAInfo' em vez disso."
    undefinedOpenApiReferencesMessage                                 = 'Referências OpenAPI indefinidas:'
    doneMessage                                                       = 'Concluído'
    swaggerEditorDoesNotSupportOpenApi31ExceptionMessage              = 'Esta versão do Swagger-Editor não suporta OpenAPI 3.1'
    durationMustBeZeroOrGreaterExceptionMessage                       = 'A duração deve ser 0 ou maior, mas foi obtido: {0}s'
    viewsPathDoesNotExistExceptionMessage                             = 'O caminho das Views não existe: {0}'
    discriminatorIncompatibleWithAllOfExceptionMessage                = "O parâmetro 'Discriminator' é incompatível com 'allOf'."
    noNameForWebSocketSendMessageExceptionMessage                     = 'Nenhum nome fornecido para enviar mensagem ao WebSocket.'
    hashtableMiddlewareNoLogicExceptionMessage                        = 'Um Middleware do tipo Hashtable fornecido não tem lógica definida.'
    openApiInfoMessage                                                = 'Informações OpenAPI:'
    invalidSchemeForAuthValidatorExceptionMessage                     = "O esquema '{0}' fornecido para o validador de autenticação '{1}' requer um ScriptBlock válido."
    sseFailedToBroadcastExceptionMessage                              = 'SSE falhou em transmitir devido ao nível de transmissão SSE definido para {0}: {1}.'
    adModuleWindowsOnlyExceptionMessage                               = 'O módulo Active Directory está disponível apenas no Windows.'
    requestLoggingAlreadyEnabledExceptionMessage                      = 'O registro de solicitações já está habilitado.'
    invalidAccessControlMaxAgeDurationExceptionMessage                = 'Duração inválida fornecida para Access-Control-Max-Age: {0}. Deve ser maior que 0.'
    NonHashtableArrayElementExceptionMessage                          = 'A matriz contém um elemento que não é uma tabela hash'
    InputNotHashtableOrArrayOfHashtablesExceptionMessage              = 'A entrada não é uma tabela hash ou uma matriz de tabelas hash'
}

