ConvertFrom-StringData -StringData @'
adModuleWindowsOnlyMessage = وحدة Active Directory متاحة فقط على نظام Windows
adModuleNotInstalledMessage = وحدة Active Directory غير مثبتة
secretManagementModuleNotInstalledMessage = وحدة Microsoft.PowerShell.SecretManagement غير مثبتة
secretVaultAlreadyRegisteredMessage = تم تسجيل خزنة سرية بالاسم '{0}' بالفعل أثناء الاستيراد التلقائي للخزن السرية
failedToOpenRunspacePoolMessage = فشل في فتح RunspacePool: {0}
cronExpressionInvalidMessage = يجب أن تتكون تعبير Cron فقط من 5 أجزاء: {0}
invalidAliasFoundMessage = تم العثور على اسم مستعار غير صالح {0}: {1}
invalidAtomCharacterMessage = حرف ذري غير صالح: {0}
minValueGreaterThanMaxMessage = يجب ألا تكون القيمة الدنيا لـ {0} أكبر من القيمة القصوى
minValueInvalidMessage = القيمة الدنيا '{0}' لـ {1} غير صالحة، يجب أن تكون أكبر من أو تساوي {2}
maxValueInvalidMessage = القيمة القصوى '{0}' لـ {1} غير صالحة، يجب أن تكون أقل من أو تساوي {2}
valueOutOfRangeMessage = القيمة '{0}' لـ {1} غير صالحة، يجب أن تكون بين {2} و {3}
daysInMonthExceededMessage = {0} يحتوي فقط على {1} أيام، ولكن تم توفير {2}
nextTriggerCalculationErrorMessage = يبدو أن هناك خطأ ما عند محاولة حساب تاريخ ووقت التشغيل التالي: {0}
incompatiblePodeDllMessage = تم تحميل إصدار غير متوافق موجود من Pode.DLL {0}. الإصدار {1} مطلوب. افتح جلسة Powershell/pwsh جديدة وحاول مرة أخرى.
endpointNotExistMessage = لا يوجد نقطة نهاية بالبروتوكول '{0}' والعنوان '{1}' أو العنوان المحلي '{2}'
endpointNameNotExistMessage = لا يوجد نقطة نهاية بالاسم '{0}'
failedToConnectToUrlMessage = فشل الاتصال بعنوان URL: {0}
failedToParseAddressMessage = فشل في تحليل '{0}' كعنوان IP/Host:Port صالح
invalidIpAddressMessage = عنوان IP المقدم غير صالح: {0}
invalidPortMessage = لا يمكن أن يكون المنفذ سالبًا: {0}
pathNotExistMessage = المسار غير موجود: {0}
'@