@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%BuildAndRun.ps1"

set "NO_PAUSE="
set "FORWARD_ARGS="

:parse_args
if "%~1"=="" goto run
if /I "%~1"=="--no-pause" (set "NO_PAUSE=1" & shift & goto parse_args)
if /I "%~1"=="/NoPause" (set "NO_PAUSE=1" & shift & goto parse_args)
set "FORWARD_ARGS=%FORWARD_ARGS% %1"
shift
goto parse_args

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %FORWARD_ARGS%

:: Keep the window open on error so the message is visible.
if errorlevel 1 (
    echo [ERROR] BuildAndRun failed. ExitCode=%ERRORLEVEL%
    echo See the error output above.
    if not defined NO_PAUSE (
        echo Press any key to exit...
        pause >nul
    )
    exit /b %ERRORLEVEL%
)

endlocal
