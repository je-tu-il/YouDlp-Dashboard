@echo off
setlocal
cd /d "%~dp0"
title YouDlp Dashboard Launcher

:: 1. Verifier si YouDlp-Dashboard.exe existe
if exist "%~dp0YouDlp-Dashboard.exe" (
    start "" "%~dp0YouDlp-Dashboard.exe"
    exit /b 0
)

:: 2. Fallback AutoHotkey.exe pour lancer main.ahk
set "AHK_EXE="
if exist "E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\AutoHotkey.exe" set "AHK_EXE=E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\AutoHotkey.exe"
if not defined AHK_EXE (
    where AutoHotkey.exe >nul 2>&1 && for /f "delims=" %%I in ('where AutoHotkey.exe') do set "AHK_EXE=%%I"
)

if defined AHK_EXE (
    start "" "%AHK_EXE%" "%~dp0main.ahk"
    exit /b 0
)

echo [ERREUR] Impossible de trouver YouDlp-Dashboard.exe ou AutoHotkey.exe.
echo Veuillez verifier les fichiers du projet.
pause
