ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = Active Directory module only available on Windows
adModuleNotInstalledMessage = Active Directory module is not installed
secretManagementModuleNotInstalledMessage = Microsoft.PowerShell.SecretManagement module not installed
secretVaultAlreadyRegisteredMessage = A Secret Vault with the name '{0}' has already been registered while auto-importing Secret Vaults
failedToOpenRunspacePoolMessage = Failed to open RunspacePool: {0}
cronExpressionInvalidMessage = Cron expression should only consist of 5 parts: {0}
invalidAliasFoundMessage = Invalid {0} alias found: {1}
invalidAtomCharacterMessage = Invalid atom character: {0}
minValueGreaterThanMaxMessage = Min value for {0} should not be greater than the max value
minValueInvalidMessage = Min value '{0}' for {1} is invalid, should be greater than/equal to {2}
maxValueInvalidMessage = Max value '{0}' for {1} is invalid, should be less than/equal to {2}
valueOutOfRangeMessage = Value '{0}' for {1} is invalid, should be between {2} and {3}
daysInMonthExceededMessage = {0} only has {1} days, but {2} was supplied
nextTriggerCalculationErrorMessage = Looks like something went wrong trying to calculate the next trigger datetime: {0}
incompatiblePodeDllMessage = An existing incompatible Pode.DLL version {0} is loaded. Version {1} is required. Open a new Powershell/pwsh session and retry.
endpointNotExistMessage = Endpoint with protocol '{0}' and address '{1}' or local address '{2}' does not exist
endpointNameNotExistMessage = Endpoint with name '{0}' does not exist
failedToConnectToUrlMessage = Failed to connect to URL: {0}
failedToParseAddressMessage = Failed to parse '{0}' as a valid IP/Host:Port address
invalidIpAddressMessage = The IP address supplied is invalid: {0}
invalidPortMessage = The port cannot be negative: {0}
pathNotExistMessage = Path does not exist: {0}
'@