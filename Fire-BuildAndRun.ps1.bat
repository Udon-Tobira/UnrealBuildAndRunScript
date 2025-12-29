@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%BuildAndRun.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

:: Keep the window open on error so the message is visible.
if errorlevel 1 (
    echo [ERROR] BuildAndRun failed. ExitCode=%ERRORLEVEL%
    echo See the error output above.
    echo Press any key to exit...
    pause >nul
    exit /b %ERRORLEVEL%
)

endlocal
