@echo off
chcp 65001 >nul
title YouDlp Dashboard - Calculateur d'Heures
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\calculer_heures.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Une erreur est survenue lors de l'exécution du script.
    pause
)
