@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%BuildAndRun.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

:: エラー時のみウィンドウを閉じない（エラー表示用に停止）
if errorlevel 1 (
    echo [ERROR] BuildAndRun でエラーが発生しました。ExitCode=%ERRORLEVEL%
    echo 上のエラーメッセージを確認してください。何かキーを押すと終了します...
    pause >nul
    exit /b %ERRORLEVEL%
)

endlocal
