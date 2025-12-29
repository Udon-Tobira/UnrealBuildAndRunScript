@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%BuildAndTest.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

if errorlevel 1 (
    echo [ERROR] BuildAndTest failed. ExitCode=%ERRORLEVEL%
    echo See the error output above. Press any key to exit...
    pause >nul
    exit /b %ERRORLEVEL%
)

endlocal
