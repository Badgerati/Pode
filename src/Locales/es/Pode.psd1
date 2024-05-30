ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = El módulo de Active Directory solo está disponible en Windows
adModuleNotInstalledMessage = El módulo de Active Directory no está instalado
secretManagementModuleNotInstalledMessage = El módulo Microsoft.PowerShell.SecretManagement no está instalado
secretVaultAlreadyRegisteredMessage = Ya se ha registrado un Bóveda Secreta con el nombre '{0}' al importar automáticamente Bóvedas Secretas
failedToOpenRunspacePoolMessage = Error al abrir RunspacePool: {0}
cronExpressionInvalidMessage = La expresión Cron solo debe consistir en 5 partes: {0}
invalidAliasFoundMessage = Se encontró un alias {0} no válido: {1}
invalidAtomCharacterMessage = Carácter atómico no válido: {0}
minValueGreaterThanMaxMessage = El valor mínimo para {0} no debe ser mayor que el valor máximo
minValueInvalidMessage = El valor mínimo '{0}' para {1} no es válido, debe ser mayor o igual a {2}
maxValueInvalidMessage = El valor máximo '{0}' para {1} no es válido, debe ser menor o igual a {2}
valueOutOfRangeMessage = El valor '{0}' para {1} no es válido, debe estar entre {2} y {3}
daysInMonthExceededMessage = {0} solo tiene {1} días, pero se suministró {2}
nextTriggerCalculationErrorMessage = Parece que algo salió mal al intentar calcular la siguiente fecha y hora del disparador: {0}
incompatiblePodeDllMessage = Se ha cargado una versión incompatible existente de Pode.DLL {0}. Se requiere la versión {1}. Abra una nueva sesión de Powershell/pwsh e intente de nuevo.
endpointNotExistMessage = No existe un punto de conexión con el protocolo '{0}' y la dirección '{1}' o la dirección local '{2}'
endpointNameNotExistMessage = No existe un punto de conexión con el nombre '{0}'
failedToConnectToUrlMessage = Error al conectar con la URL: {0}
failedToParseAddressMessage = Error al analizar '{0}' como una dirección IP/Host:Puerto válida
invalidIpAddressMessage = La dirección IP suministrada no es válida: {0}
invalidPortMessage = El puerto no puede ser negativo: {0}
pathNotExistMessage = La ruta no existe: {0}
'@