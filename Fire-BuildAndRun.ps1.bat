@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%BuildAndRun.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

:: �G���[���̂݃E�B���h�E����Ȃ��i�G���[�\���p�ɒ�~�j
if errorlevel 1 (
    echo [ERROR] BuildAndRun �ŃG���[���������܂����BExitCode=%ERRORLEVEL%
    echo ��̃G���[���b�Z�[�W���m�F���Ă��������B�����L�[�������ƏI�����܂�...
    pause >nul
    exit /b %ERRORLEVEL%
)

endlocal
