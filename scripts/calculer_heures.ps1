# ==============================================================================
# Calculateur de Duree Totale YouDlp
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   YouDlp - Analyse et Calcul de la Duree Totale" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$shell = New-Object -ComObject Shell.Application
$foldersCache = @{}

function Get-FolderObj($dir) {
    if (-not $foldersCache.ContainsKey($dir)) {
        if (Test-Path $dir) {
            $foldersCache[$dir] = $shell.Namespace($dir)
        } else {
            $foldersCache[$dir] = $null
        }
    }
    return $foldersCache[$dir]
}

function Get-MediaDurationSec($filePath) {
    if (-not (Test-Path $filePath)) { return 0 }
    $dir = Split-Path -Parent $filePath
    $name = Split-Path -Leaf $filePath
    $fObj = Get-FolderObj $dir
    if (-not $fObj) { return 0 }
    $item = $fObj.ParseName($name)
    if (-not $item) { return 0 }
    $d = $fObj.GetDetailsOf($item, 27)
    if ($d -match "(\d+):(\d+):(\d+)") {
        return [int]$matches[1]*3600 + [int]$matches[2]*60 + [int]$matches[3]
    } elseif ($d -match "(\d+):(\d+)") {
        return [int]$matches[1]*60 + [int]$matches[2]
    }
    return 0
}

function Format-Sec($seconds) {
    $h = [math]::Floor($seconds / 3600)
    $m = [math]::Floor(($seconds % 3600) / 60)
    $s = $seconds % 60
    return ("{0}h {1}m {2}s" -f $h, $m, $s)
}

# 1. Analyse du dossier Upload (Videos)
$uploadDir = "E:\Reste\Upload"
$uploadSec = 0
$uploadCount = 0
if (Test-Path $uploadDir) {
    $vFiles = Get-ChildItem -Path $uploadDir -File -Include *.mp4,*.mkv,*.webm -Recurse -ErrorAction SilentlyContinue
    $uploadCount = $vFiles.Count
    foreach ($f in $vFiles) {
        $uploadSec += (Get-MediaDurationSec $f.FullName)
    }
}
Write-Host ("Videos (Upload)    : {0} fichiers -> " -f $uploadCount) -NoNewline -ForegroundColor White
Write-Host (Format-Sec $uploadSec) -ForegroundColor Yellow

# 2. Analyse du dossier Podcast (Musiques)
$podcastDir = "E:\Reste\Podcast"
$podcastSec = 0
$podcastCount = 0
if (Test-Path $podcastDir) {
    $mFiles = Get-ChildItem -Path $podcastDir -File -Include *.mp3,*.m4a,*.opus -Recurse -ErrorAction SilentlyContinue
    $podcastCount = $mFiles.Count
    foreach ($f in $mFiles) {
        $podcastSec += (Get-MediaDurationSec $f.FullName)
    }
}
Write-Host ("Musiques (Podcast) : {0} fichiers -> " -f $podcastCount) -NoNewline -ForegroundColor White
Write-Host (Format-Sec $podcastSec) -ForegroundColor Yellow

# Total physique
$totalDiskSec = $uploadSec + $podcastSec
$totalDiskFiles = $uploadCount + $podcastCount
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("TOTAL DISQUE ACTUEL : {0} fichiers -> " -f $totalDiskFiles) -NoNewline -ForegroundColor Green
Write-Host (Format-Sec $totalDiskSec) ("({0} heures)" -f [math]::Round($totalDiskSec / 3600, 2)) -ForegroundColor Green
Write-Host ""

# 3. Scan et injection des durees dans db/history.txt
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$histPath = Join-Path $scriptDir "..\db\history.txt"
if (-not (Test-Path $histPath)) {
    $histPath = "$PWD\db\history.txt"
}

if (Test-Path $histPath) {
    Write-Host "Analyse et enrichissement de db\history.txt..." -ForegroundColor Cyan
    $lines = [System.IO.File]::ReadAllLines($histPath, [System.Text.Encoding]::UTF8)
    $newLines = New-Object System.Collections.Generic.List[string]
    $updatedCount = 0
    $totalHistSec = 0
    $sep = "|||"

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Split([string[]]@("|||"), [System.StringSplitOptions]::None)
        if ($parts.Count -ge 4) {
            $title = $parts[0]
            $path = $parts[1]
            $id = $parts[2]
            $fmt = $parts[3]
            $dur = "0"
            if ($parts.Count -ge 5) {
                $dur = $parts[4]
            }

            if ($dur -eq "0" -or [string]::IsNullOrWhiteSpace($dur)) {
                $foundSec = 0
                if (Test-Path $path) {
                    $foundSec = Get-MediaDurationSec $path
                } else {
                    $searchDir = if ($fmt -eq "mp3") { $podcastDir } else { $uploadDir }
                    $candidate = Get-ChildItem -Path $searchDir -Filter "*$id*" -File -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($candidate) {
                        $foundSec = Get-MediaDurationSec $candidate.FullName
                        $path = $candidate.FullName
                    }
                }
                if ($foundSec -gt 0) {
                    $dur = $foundSec.ToString()
                    $updatedCount++
                }
            }

            $numVal = 0
            if ([int]::TryParse($dur, [ref]$numVal)) {
                $totalHistSec += $numVal
            }

            $combined = $title + $sep + $path + $sep + $id + $sep + $fmt + $sep + $dur
            $newLines.Add($combined)
        } else {
            $newLines.Add($line)
        }
    }

    [System.IO.File]::WriteAllLines($histPath, $newLines.ToArray(), [System.Text.Encoding]::UTF8)
    Write-Host "Historique mis a jour avec succes !" -ForegroundColor Green
    Write-Host ("   - Fichiers physiques reconnus et enrichis : {0}" -f $updatedCount) -ForegroundColor White
    Write-Host "   - Duree totale connue dans l'historique : " -NoNewline -ForegroundColor White
    Write-Host (Format-Sec $totalHistSec) ("({0} heures)" -f [math]::Round($totalHistSec / 3600, 2)) -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
