' BiliBiliToolPro daily check-in hidden launcher (async, for Startup folder)
Set ws = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
base = fso.GetParentFolderName(WScript.ScriptFullName)
ws.Run """" & base & "\run-daily.bat""", 0, False