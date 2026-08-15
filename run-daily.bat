@echo off
chcp 65001 >nul
rem ============================================================
rem  BiliBiliToolPro daily check-in runner (portable)
rem  Paths are resolved from this script's own location.
rem  Every step is echoed to .bilitool-run.log for diagnosability.
rem ============================================================
set "APP_DIR=%~dp0win-x64"
set "LOCK=%~dp0.bilitool-running.lock"
set "TRACE=%~dp0.bilitool-run.log"

echo [%date% %time%] run started >> "%TRACE%"

rem Skip if the tool is already running.
rem (tasklist truncates the image name to 24 chars, so match a substring)
tasklist /FI "IMAGENAME eq Ray.BiliBiliTool.Console.exe" 2>nul | find /i "BiliBiliTool" >nul
if not errorlevel 1 (
    echo [%date% %time%] skip: another instance running >> "%TRACE%"
    exit /b 0
)

rem Acquire an atomic lock. A stale lock (crash leftovers) older than
rem 30 minutes is removed first; a fresh lock blocks this run.
powershell -NoProfile -Command "$l='%LOCK%'; if (Test-Path $l) { if ((Get-Item $l).LastWriteTime -lt (Get-Date).AddMinutes(-30)) { Remove-Item $l -Force } else { exit 1 } }; try { $fs=[System.IO.File]::Open($l,[System.IO.FileMode]::CreateNew); $fs.Close() } catch { exit 1 }"
if errorlevel 1 (
    echo [%date% %time%] skip: lock held >> "%TRACE%"
    exit /b 0
)

rem Check the tool binary exists.
if not exist "%APP_DIR%\Ray.BiliBiliTool.Console.exe" (
    echo [%date% %time%] error: exe not found in %APP_DIR% >> "%TRACE%"
    del /q "%LOCK%" 2>nul
    exit /b 1
)

rem Run all tasks under a 1-hour watchdog so it can never hang forever.
rem -WorkingDirectory pins the exe cwd to win-x64 so logs always land in win-x64\Logs.
echo [%date% %time%] starting tasks >> "%TRACE%"
powershell -NoProfile -Command "$p = Start-Process -FilePath '%APP_DIR%\Ray.BiliBiliTool.Console.exe' -ArgumentList '--runTasks=""Daily&Manga&Silver2Coin&VipPrivilege&MangaPrivilege&VipBigPoint&Charge""' -WorkingDirectory '%APP_DIR%' -PassThru -NoNewWindow; if (-not $p.WaitForExit(3600000)) { $p.Kill(); Write-Host '[watchdog] Task exceeded 1 hour, killed.' } else { exit $p.ExitCode }"

rem Send a notification with today's result (also covers abnormal runs).
echo [%date% %time%] notify >> "%TRACE%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0notify.ps1"

rem Keep only the last 30 days of logs (both possible log locations).
powershell -NoProfile -Command "foreach ($d in @('%APP_DIR%\Logs','%~dp0Logs')) { Get-ChildItem $d -Filter 'log*.txt' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue }"

rem Release the lock.
del /q "%LOCK%" 2>nul
echo [%date% %time%] run finished >> "%TRACE%"
exit /b 0