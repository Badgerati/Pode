ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = Active DirectoryモジュールはWindowsでのみ利用可能です
adModuleNotInstalledMessage = Active Directoryモジュールがインストールされていません
secretManagementModuleNotInstalledMessage = Microsoft.PowerShell.SecretManagementモジュールがインストールされていません
secretVaultAlreadyRegisteredMessage = シークレットボールト'{0}'は既に登録されています（シークレットボールトの自動インポート中）
failedToOpenRunspacePoolMessage = RunspacePoolのオープンに失敗しました: {0}
cronExpressionInvalidMessage = Cron式は5つの部分で構成される必要があります: {0}
invalidAliasFoundMessage = 無効な{0}エイリアスが見つかりました: {1}
invalidAtomCharacterMessage = 無効なアトム文字: {0}
minValueGreaterThanMaxMessage = {0}の最小値は最大値を超えることはできません
minValueInvalidMessage = {1}の最小値'{0}'は無効です。{2}以上でなければなりません
maxValueInvalidMessage = {1}の最大値'{0}'は無効です。{2}以下でなければなりません
valueOutOfRangeMessage = {1}の値'{0}'は無効です。{2}から{3}の間でなければなりません
daysInMonthExceededMessage = {0}は{1}日しかありませんが、{2}が指定されました
nextTriggerCalculationErrorMessage = 次のトリガー日時の計算中に問題が発生したようです: {0}
incompatiblePodeDllMessage = 既存の互換性のないPode.DLLバージョン{0}がロードされています。バージョン{1}が必要です。新しいPowershell/pwshセッションを開いて再試行してください。
endpointNotExistMessage = プロトコル'{0}'とアドレス'{1}'またはローカルアドレス'{2}'のエンドポイントが存在しません
endpointNameNotExistMessage = 名前'{0}'のエンドポイントが存在しません
failedToConnectToUrlMessage = URLへの接続に失敗しました: {0}
failedToParseAddressMessage = '{0}'を有効なIP/ホスト:ポートアドレスとして解析できませんでした
invalidIpAddressMessage = 提供されたIPアドレスは無効です: {0}
invalidPortMessage = ポートは負であってはなりません: {0}
pathNotExistMessage = パスが存在しません: {0}
'@