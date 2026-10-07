<#
.SYNOPSIS
    YouDlp Dashboard - Outil de calcul et récupération des heures de téléchargement
.DESCRIPTION
    Analyse l'historique complet, calcule les durées des fichiers sur le disque,
    et permet la récupération (backfill) des durées YouTube pour les vidéos passées.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "YouDlp - Calculateur d'heures de téléchargement"

function Format-TimeSpanPretty([TimeSpan]$ts) {
    $parts = @()
    if ($ts.Days -gt 0) { $parts += "$($ts.Days) jour$(if($ts.Days -gt 1){'s'})" }
    if ($ts.Hours -gt 0) { $parts += "$($ts.Hours) heure$(if($ts.Hours -gt 1){'s'})" }
    if ($ts.Minutes -gt 0) { $parts += "$($ts.Minutes) minute$(if($ts.Minutes -gt 1){'s'})" }
    $parts += "$($ts.Seconds) seconde$(if($ts.Seconds -gt 1){'s'})"
    return ($parts -join ", ")
}

$baseDir = Resolve-Path "$PSScriptRoot\.."
$histPath = "$baseDir\db\history.txt"
$iniPath = "$baseDir\config.ini"

# Lecture des dossiers de config.ini
$pathMP4 = "E:\Reste\Upload"
$pathMP3 = "E:\Reste\Podcast"
if (Test-Path $iniPath) {
    $iniContent = Get-Content $iniPath
    foreach ($line in $iniContent) {
        if ($line -match "^PathMP4\s*=\s*(.+)$") { $pathMP4 = $matches[1].Trim() }
        if ($line -match "^PathMP3\s*=\s*(.+)$") { $pathMP3 = $matches[1].Trim() }
    }
}

Clear-Host
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "             🎬 YouDlp Dashboard - Calculateur d'Heures                  " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""

if (!(Test-Path $histPath)) {
    Write-Host "❌ Fichier d'historique introuvable à : $histPath" -ForegroundColor Red
    Write-Host ""
    pause
    exit
}

# 1. Analyse de db/history.txt
$lines = Get-Content $histPath
$totalSec = 0
$countTotal = 0
$countWithDuration = 0
$countZero = 0
$countMP4 = 0
$countMP3 = 0

foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "\|\|\|"
    if ($parts.Length -ge 4) {
        $countTotal++
        $fmt = $parts[3].ToLower()
        if ($fmt -eq "mp3") { $countMP3++ } else { $countMP4++ }

        $sec = 0
        if ($parts.Length -ge 5 -and [int]::TryParse($parts[4], [ref]$sec) -and $sec -gt 0) {
            $totalSec += $sec
            $countWithDuration++
        } else {
            $countZero++
        }
    }
}

$tsRecorded = [TimeSpan]::FromSeconds($totalSec)

Write-Host "📊 1. HISTORIQUE ENREGISTRÉ DANS LA BASE (db/history.txt) :" -ForegroundColor Green
Write-Host "   - Total d'éléments dans l'historique : $countTotal (Vidéos MP4 : $countMP4 | Audio MP3 : $countMP3)" -ForegroundColor White
Write-Host "   - Entrées avec durée déjà renseignée : $countWithDuration" -ForegroundColor Gray
Write-Host "   - Entrées sans durée enregistrée (0) : $countZero (enregistrées avant l'ajout du chrono)" -ForegroundColor Yellow
Write-Host "   ------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "   ⏱️  DURÉE TOTALE ENREGISTRÉE : $([Math]::Round($tsRecorded.TotalHours, 2)) heures" -ForegroundColor Yellow -NoNewline
Write-Host " ($totalSec secondes)" -ForegroundColor Gray
Write-Host "   👉 En clair : $(Format-TimeSpanPretty $tsRecorded)" -ForegroundColor Cyan
Write-Host ""

# 2. Analyse des fichiers présents sur le disque
Write-Host "💾 2. FICHIERS MÉDIA RÉELLEMENT PRÉSENTS SUR LE DISQUE :" -ForegroundColor Green
$probeExe = "E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin\ffprobe.exe"
if (!(Test-Path $probeExe)) {
    $probeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue
    if ($probeCmd) { $probeExe = $probeCmd.Source }
}

$foldersToScan = @($pathMP4, $pathMP3) | Select-Object -Unique | Where-Object { Test-Path $_ }
$diskSec = 0
$diskFilesCount = 0

if ($foldersToScan.Count -gt 0 -and (Test-Path $probeExe)) {
    foreach ($folder in $foldersToScan) {
        $files = Get-ChildItem -Path $folder -File -Recurse -Include *.mp4, *.mkv, *.webm, *.mp3, *.m4a, *.opus -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $diskFilesCount++
            try {
                $durStr = & $probeExe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $f.FullName 2>$null
                $durFloat = 0.0
                if ([double]::TryParse($durStr, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$durFloat)) {
                    $diskSec += [int][Math]::Round($durFloat)
                }
            } catch {}
        }
    }
    $tsDisk = [TimeSpan]::FromSeconds($diskSec)
    Write-Host "   - Fichiers analysés dans vos dossiers : $diskFilesCount" -ForegroundColor White
    Write-Host "   ⏱️  DURÉE DES FICHIERS SUR LE DISQUE : $([Math]::Round($tsDisk.TotalHours, 2)) heures" -ForegroundColor Yellow
    Write-Host "   👉 En clair : $(Format-TimeSpanPretty $tsDisk)" -ForegroundColor Cyan
} else {
    Write-Host "   (ffprobe non disponible ou dossiers inaccessibles)" -ForegroundColor Gray
}
Write-Host ""

# 3. Proposition de récupération complète des 903 vidéos sans durée
Write-Host "🔄 3. RÉCUPÉRATION COMPLÈTE DU TEMPS DE L'HISTORIQUE (BACKFILL) :" -ForegroundColor Green
Write-Host "   Vous avez $countZero vidéos téléchargées dans le passé qui affichent 0s car le" -ForegroundColor White
Write-Host "   dashboard n'enregistrait pas encore la durée au moment du téléchargement." -ForegroundColor White
Write-Host "   Il est possible d'interroger automatiquement YouTube via yt-dlp pour récupérer" -ForegroundColor White
Write-Host "   les durées exactes de toutes ces vidéos et mettre à jour 'db/history.txt' !" -ForegroundColor White
Write-Host ""
Write-Host "   [1] Quitter (calcul terminé)" -ForegroundColor White
Write-Host "   [2] Lancer la récupération automatique des durées manquantes via yt-dlp" -ForegroundColor Cyan
Write-Host ""

$choice = Read-Host "Votre choix (1 ou 2)"
if ($choice -ne "2") {
    Write-Host "`nAu revoir !" -ForegroundColor Yellow
    exit
}

# Lancement du Backfill
$ytdlpExe = "yt-dlp"
$ytdlpCmd = Get-Command yt-dlp -ErrorAction SilentlyContinue
if ($ytdlpCmd) { $ytdlpExe = $ytdlpCmd.Source }
else { $ytdlpExe = "E:\App\Pc\Installer\Cmd\Path\yt-dlp.exe" }

if (!(Test-Path $ytdlpExe)) {
    Write-Host "❌ yt-dlp introuvable à : $ytdlpExe" -ForegroundColor Red
    pause
    exit
}

# Backup de history.txt
$backupFile = "$baseDir\db\history.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Copy-Item $histPath $backupFile -Force
Write-Host "`n💾 Sauvegarde de l'historique créée : $backupFile" -ForegroundColor Gray
Write-Host "🚀 Démarrage de la récupération en arrière-plan..." -ForegroundColor Green
Write-Host "(Vous pouvez appuyer sur Ctrl+C pour arrêter à tout moment sans perdre le travail effectué)`n" -ForegroundColor DarkGray

$updatedLines = @()
$processed = 0
$recoveredCount = 0
$extraSec = 0

for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line)) {
        $updatedLines += $line
        continue
    }

    $parts = $line -split "\|\|\|"
    if ($parts.Length -ge 4) {
        $sec = 0
        $needsFetch = ($parts.Length -lt 5) -or (![int]::TryParse($parts[4], [ref]$sec)) -or ($sec -le 0)
        $vidId = $parts[2]

        if ($needsFetch -and $vidId -and $vidId.Length -ge 5) {
            $processed++
            Write-Host "[$processed/$countZero] Récupération pour '$($parts[0])' ($vidId)... " -ForegroundColor White -NoNewline
            
            try {
                $durRaw = & $ytdlpExe --skip-download --print "%(duration)s" --no-warnings "https://www.youtube.com/watch?v=$vidId" 2>$null
                $durVal = 0
                if ($durRaw -and [int]::TryParse($durRaw.Trim(), [ref]$durVal) -and $durVal -gt 0) {
                    $sec = $durVal
                    $extraSec += $durVal
                    $recoveredCount++
                    Write-Host "OK ($durVal s)" -ForegroundColor Green
                } else {
                    Write-Host "Ignoré" -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "Erreur" -ForegroundColor Red
            }

            # Reconstituer la ligne
            $channel = if ($parts.Length -ge 6) { $parts[5] } else { "" }
            $newLine = "$($parts[0])|||$($parts[1])|||$($parts[2])|||$($parts[3])|||$sec|||$channel"
            $updatedLines += $newLine
            
            # Sauvegarde intermédiaire toutes les 10 vidéos
            if ($processed % 10 -eq 0) {
                [System.IO.File]::WriteAllLines($histPath, $updatedLines + $lines[($i+1)..($lines.Length-1)], [System.Text.Encoding]::UTF8)
            }
        } else {
            $updatedLines += $line
        }
    } else {
        $updatedLines += $line
    }
}

# Sauvegarde finale
[System.IO.File]::WriteAllLines($histPath, $updatedLines, [System.Text.Encoding]::UTF8)

$totalSecFinal = $totalSec + $extraSec
$tsFinal = [TimeSpan]::FromSeconds($totalSecFinal)

Write-Host ""
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host "🎉 RÉCUPÉRATION TERMINÉE !" -ForegroundColor Green
Write-Host "   - Vidéos récupérées : $recoveredCount" -ForegroundColor White
Write-Host "   - NOUVELLE DURÉE TOTALE DE L'HISTORIQUE : $([Math]::Round($tsFinal.TotalHours, 2)) heures" -ForegroundColor Yellow
Write-Host "   👉 En clair : $(Format-TimeSpanPretty $tsFinal)" -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "La base 'db/history.txt' a été mise à jour. Le dashboard affichera désormais ces statistiques complètes !" -ForegroundColor Green
Write-Host ""
pause
