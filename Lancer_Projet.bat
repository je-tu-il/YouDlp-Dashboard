@echo off
chcp 65001 >nul
cd /d "%~dp0"

set "APP_TITLE=YouDlp"
title %APP_TITLE%

echo ========================================================
echo   %APP_TITLE%
echo ========================================================
echo.
REM --- VERIFICATION AUTOHOTKEY V1.1 ---
set "AHK_BIN="
for %%P in (
    "AutoHotkey.exe"
    "%ProgramFiles%\AutoHotkey\AutoHotkeyU64.exe"
    "%ProgramFiles%\AutoHotkey\AutoHotkey.exe"
    "%ProgramFiles%\AutoHotkey\v1.1\AutoHotkeyU64.exe"
    "%LocalAppData%\Programs\AutoHotkey\AutoHotkeyU64.exe"
    "%LocalAppData%\Programs\AutoHotkey\v1.1\AutoHotkeyU64.exe"
) do (
    if not defined AHK_BIN (
        where %%~P >nul 2>&1 && set "AHK_BIN=%%~P"
        if exist %%P set "AHK_BIN=%%~P"
    )
)

if not defined AHK_BIN goto NO_AHK

powershell -NoProfile -Command "if ('%AHK_BIN%' -ne '') { $v = (Get-Item '%AHK_BIN%').VersionInfo.ProductVersion; if ($v -and $v -like '1.1*') { exit 0 } }; exit 1" >nul 2>&1
if errorlevel 1 goto AHK_V2_OR_INVALID
goto RUN_AHK

:NO_AHK
:AHK_V2_OR_INVALID
echo ========================================================
echo   [ATTENTION] AutoHotkey v1.1 est requis
echo ========================================================
echo AutoHotkey v1.1 n'a pas ete detecte sur ce systeme.
echo (La version 2.x n'est pas compatible avec la syntaxe de ce script).
echo.
echo Ouverture de la page officielle de telechargement AutoHotkey v1.1...
start https://www.autohotkey.com/download/1.1/
echo.
pause
exit /b 1

:RUN_AHK
echo [*] Ouverture automatique du navigateur : http://localhost:65432...
start "" cmd /c "timeout /t 2 /nobreak >nul & start http://localhost:65432"
echo [*] Lancement de main.ahk...
start "" "%AHK_BIN%" "%~dp0main.ahk"
exit /b 0
