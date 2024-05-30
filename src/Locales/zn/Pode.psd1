ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = Active Directory模块仅在Windows上可用
adModuleNotInstalledMessage = Active Directory模块未安装
secretManagementModuleNotInstalledMessage = Microsoft.PowerShell.SecretManagement模块未安装
secretVaultAlreadyRegisteredMessage = 在自动导入秘密库时，名为'{0}'的秘密库已注册
failedToOpenRunspacePoolMessage = 无法打开RunspacePool: {0}
cronExpressionInvalidMessage = Cron表达式应仅由5部分组成: {0}
invalidAliasFoundMessage = 找到无效的{0}别名：{1}
invalidAtomCharacterMessage = 无效的原子字符：{0}
minValueGreaterThanMaxMessage = {0}的最小值不应大于最大值
minValueInvalidMessage = {1}的最小值'{0}'无效，应大于或等于{2}
maxValueInvalidMessage = {1}的最大值'{0}'无效，应小于或等于{2}
valueOutOfRangeMessage = {1}的值'{0}'无效，应介于{2}和{3}之间
daysInMonthExceededMessage = {0}只有{1}天，但提供了{2}
nextTriggerCalculationErrorMessage = 计算下一个触发日期时间时似乎出了问题：{0}
incompatiblePodeDllMessage = 已加载现有的不兼容Pode.DLL版本{0}。需要版本{1}。请打开一个新的Powershell/pwsh会话并重试。
endpointNotExistMessage = 协议为'{0}'且地址为'{1}'或本地地址为'{2}'的端点不存在
endpointNameNotExistMessage = 名称为'{0}'的端点不存在
failedToConnectToUrlMessage = 无法连接到URL: {0}
failedToParseAddressMessage = 无法将'{0}'解析为有效的IP/主机：端口地址
invalidIpAddressMessage = 提供的IP地址无效:{0}
invalidPortMessage = 端口不能为负：{0}
pathNotExistMessage = 路径不存在：{0}
'@