' BiliBiliToolPro daily check-in hidden launcher (sync, for scheduled task)
' bWaitOnReturn=True: wscript waits for the batch to finish so the task
' can track execution status and apply the ExecutionTimeLimit.
Set ws = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
ws.Run """" & base & "\run-daily.bat""", 0, True