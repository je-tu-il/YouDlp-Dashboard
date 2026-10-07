@echo off
chcp 65001 >nul
title YouDlp - Calculateur de Duree
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\calculer_heures.ps1"
echo.
echo Appuyez sur une touche pour quitter...
pause >nul
