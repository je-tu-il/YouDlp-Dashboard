@echo off
setlocal
cd /d "%~dp0"
title Mise a jour de yt-dlp et re-empaquetage

echo ============================================================
echo   Mise a jour de yt-dlp et re-empaquetage YouDlp Dashboard
echo ============================================================
echo.

:: 1. Verifier le binaire local
if not exist "bin\yt-dlp.exe" (
    if exist "E:\App\Pc\Installer\Cmd\Path\yt-dlp.exe" (
        mkdir "bin" 2>nul
        copy /y "E:\App\Pc\Installer\Cmd\Path\yt-dlp.exe" "bin\yt-dlp.exe" >nul
    )
)

if not exist "bin\ffmpeg.exe" (
    if exist "E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin\ffmpeg.exe" (
        mkdir "bin" 2>nul
        copy /y "E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin\ffmpeg.exe" "bin\ffmpeg.exe" >nul
    )
)

:: 2. Mise a jour de yt-dlp
echo [1/3] Mise a jour de yt-dlp...
if exist "bin\yt-dlp.exe" (
    "bin\yt-dlp.exe" -U
) else (
    yt-dlp -U
)
echo.

:: 3. Re-empaquetage
echo [2/3] Re-empaquetage des executables Standalone et Lite...
set "COMPILER=E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Ahk2Exe.exe"
set "BIN_BASE=E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Unicode 64-bit.bin"

if exist "%COMPILER%" (
    taskkill /f /im "YouDlp-Dashboard.exe" >nul 2>&1
    taskkill /f /im "YouDlp-Dashboard-Standalone.exe" >nul 2>&1
    taskkill /f /im "YouDlp-Dashboard-Lite.exe" >nul 2>&1

    "%COMPILER%" /in "%~dp0main.ahk" /out "%~dp0YouDlp-Dashboard-Standalone.exe" /icon "%~dp0a.ico" /bin "%BIN_BASE%"
    copy /y "%~dp0YouDlp-Dashboard-Standalone.exe" "%~dp0YouDlp-Dashboard.exe" >nul
    "%COMPILER%" /in "%~dp0main_lite.ahk" /out "%~dp0YouDlp-Dashboard-Lite.exe" /icon "%~dp0a.ico" /bin "%BIN_BASE%"

    mkdir "%~dp0Release" 2>nul
    copy /y "%~dp0YouDlp-Dashboard-Standalone.exe" "%~dp0Release\" >nul
    copy /y "%~dp0YouDlp-Dashboard-Lite.exe" "%~dp0Release\" >nul

    echo.
    echo [3/3] Re-empaquetage termine avec succes !
    echo Les executables dans la racine et dans Release\ sont a jour.
) else (
    echo [AVERTISSEMENT] Ahk2Exe.exe introuvable pour recompiler les binaires.
    echo yt-dlp.exe dans le dossier bin a ete mis a jour avec succes.
)

echo.
echo Operation terminee.
pause
