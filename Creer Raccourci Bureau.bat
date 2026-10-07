@echo off
setlocal
cd /d "%~dp0"

echo Creation du raccourci sur le Bureau...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$sh = New-Object -ComObject WScript.Shell; " ^
    "$desktop = [Environment]::GetFolderPath('Desktop'); " ^
    "$sc = $sh.CreateShortcut($desktop + '\YouDlp Dashboard.lnk'); " ^
    "$sc.TargetPath = '%~dp0YouDlp-Dashboard.exe'; " ^
    "$sc.WorkingDirectory = '%~dp0'; " ^
    "$sc.IconLocation = '%~dp0a.ico,0'; " ^
    "$sc.Description = 'YouDlp Dashboard - Gestionnaire de telechargement YouTube'; " ^
    "$sc.Save(); " ^
    "Write-Output '[OK] Raccourci cree sur le Bureau : ' ($desktop + '\YouDlp Dashboard.lnk')"

@pause
