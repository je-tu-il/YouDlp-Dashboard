@echo off
setlocal
cd /d "%~dp0"
title Compilation des Releases - YouDlp Dashboard

echo ============================================================
echo      Compilation des 2 Releases YouDlp Dashboard
echo ============================================================
echo.

set "COMPILER=E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Ahk2Exe.exe"
set "BIN_BASE=E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Unicode 64-bit.bin"

if not exist "%COMPILER%" (
    echo [ERREUR] Ahk2Exe.exe introuvable : %COMPILER%
    pause
    exit /b 1
)

:: 1. Verifier les binaires
if not exist "bin\yt-dlp.exe" (
    echo [INFO] Copie de yt-dlp.exe dans bin...
    mkdir "bin" 2>nul
    if exist "E:\App\Pc\Installer\Cmd\Path\yt-dlp.exe" copy /y "E:\App\Pc\Installer\Cmd\Path\yt-dlp.exe" "bin\yt-dlp.exe" >nul
)

if not exist "bin\ffmpeg.exe" (
    echo [INFO] Copie de ffmpeg.exe dans bin...
    mkdir "bin" 2>nul
    if exist "E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin\ffmpeg.exe" copy /y "E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin\ffmpeg.exe" "bin\ffmpeg.exe" >nul
)

:: Fermer les instances en cours
taskkill /f /im "YouDlp-Dashboard.exe" >nul 2>&1
taskkill /f /im "YouDlp-Dashboard-Standalone.exe" >nul 2>&1
taskkill /f /im "YouDlp-Dashboard-Lite.exe" >nul 2>&1

:: 2. Compiler la version Standalone (Full)
echo [1/2] Compilation de la version Standalone (Full : yt-dlp + ffmpeg embarques)...
"%COMPILER%" /in "%~dp0main.ahk" /out "%~dp0YouDlp-Dashboard-Standalone.exe" /icon "%~dp0a.ico" /bin "%BIN_BASE%"
copy /y "%~dp0YouDlp-Dashboard-Standalone.exe" "%~dp0YouDlp-Dashboard.exe" >nul

:: 3. Compiler la version Lite
echo [2/2] Compilation de la version Lite (Ultra-legere : utilise les outils du PATH)...
"%COMPILER%" /in "%~dp0main_lite.ahk" /out "%~dp0YouDlp-Dashboard-Lite.exe" /icon "%~dp0a.ico" /bin "%BIN_BASE%"

:: 4. Copier dans Release/
mkdir "%~dp0Release" 2>nul
copy /y "%~dp0YouDlp-Dashboard-Standalone.exe" "%~dp0Release\" >nul
copy /y "%~dp0YouDlp-Dashboard-Lite.exe" "%~dp0Release\" >nul

echo.
echo ============================================================
echo [SUCCES] Les 2 executables ont ete generes et places dans :
echo   - Release\YouDlp-Dashboard-Standalone.exe (~110 Mo)
echo   - Release\YouDlp-Dashboard-Lite.exe (~1.4 Mo)
echo   - YouDlp-Dashboard.exe (racine)
echo ============================================================
echo.
pause
