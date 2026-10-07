$compiler = "E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Ahk2Exe.exe"
$binBase = "E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Unicode 64-bit.bin"

if (!(Test-Path $compiler)) {
    Write-Error "Compiler not found at $compiler"
    exit 1
}

# 1. Standalone
Write-Host "Compiling Standalone..."
$proc1 = Start-Process -FilePath $compiler -ArgumentList "/in `"$PSScriptRoot\..\main.ahk`" /out `"$PSScriptRoot\..\YouDlp-Dashboard-Standalone.exe`" /icon `"$PSScriptRoot\..\a.ico`" /bin `"$binBase`"" -PassThru -Wait
Copy-Item "$PSScriptRoot\..\YouDlp-Dashboard-Standalone.exe" "$PSScriptRoot\..\YouDlp-Dashboard.exe" -Force

# 2. Lite
Write-Host "Compiling Lite..."
$proc2 = Start-Process -FilePath $compiler -ArgumentList "/in `"$PSScriptRoot\..\main_lite.ahk`" /out `"$PSScriptRoot\..\YouDlp-Dashboard-Lite.exe`" /icon `"$PSScriptRoot\..\a.ico`" /bin `"$binBase`"" -PassThru -Wait

# 3. Release folder
$releaseDir = "$PSScriptRoot\..\Release"
if (!(Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
}
Copy-Item "$PSScriptRoot\..\YouDlp-Dashboard-Standalone.exe" "$releaseDir\" -Force
Copy-Item "$PSScriptRoot\..\YouDlp-Dashboard-Lite.exe" "$releaseDir\" -Force

Write-Host "Compilation finished successfully!"
