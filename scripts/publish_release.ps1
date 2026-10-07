# Script de publication automatique de la Release GitHub v1.0.0
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$owner = "je-tu-il"
$repo = "YouDlp-Dashboard"
$tag = "v1.0.0"
$releaseName = "YouDlp Dashboard v1.0.0 - Édition Complète & Standalone"

Write-Host "1. Récupération des informations d'authentification Git..." -ForegroundColor Cyan
$credInput = "protocol=https`nhost=github.com`n`n"
$credOutput = $credInput | git credential fill
$token = ""
foreach ($line in ($credOutput -split "`r?`n")) {
    if ($line.StartsWith("password=")) {
        $token = $line.Substring(9).Trim()
        break
    }
}

if (-not $token) {
    Write-Error "Impossible de récupérer le token GitHub."
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "User-Agent" = "YouDlp-Dashboard-Releaser"
    "Accept" = "application/vnd.github.v3+json"
}

Write-Host "2. Vérification / Création de la Release GitHub $tag..." -ForegroundColor Cyan
$releaseBody = @"
# 🎬 YouDlp Dashboard v1.0.0

Dashboard moderne, ultra-rapide et autonome pour **yt-dlp** et **FFmpeg** sous Windows.

---

### 📦 Deux versions prêtes à l'emploi :

1. **`YouDlp-Dashboard-Standalone.exe`** (Recommandé) :
   - **100% Autonome** : Embarque directement `yt-dlp` et `FFmpeg` dans le binaire.
   - Ne nécessite aucune installation préalable ni outil tiers dans le PATH.
   - Idéal pour une utilisation portable sur n'importe quel PC.

2. **`YouDlp-Dashboard-Lite.exe`** (Ultra-léger ~1.4 Mo) :
   - Utilise le `yt-dlp.exe` et `ffmpeg.exe` installés sur votre système (PATH).

---

### ✨ Fonctionnalités clés :
- 🎨 **Interface Moderne** : Cartes carrées arrondies, vue grille et vue liste compacte.
- ⚡ **Onglet Téléchargement Personnalisé** : Choix de la résolution vidéo (720p HD, 1080p Full HD, Max 4K, 480p), qualité audio (320k HQ, 192k, 128k) et filtre SponsorBlock.
- 📺 **Recherche & Filtrage par Chaîne YouTube** : Détection intelligente des chaînes YouTube et menu déroulant de filtrage avec comptage dynamique.
- 📋 **Menu Contextuel Clic Droit** :
  - ▶️ Lancer la vidéo ou musique
  - 📁 Ouvrir l'emplacement du fichier dans l'Explorateur Windows
  - ⭐ Mettre ou retirer des favoris
  - 📋 Copier l'URL YouTube
  - 🗑️ Retirer de l'historique ou supprimer le fichier disque
- 🔘 **Mode Sélection Multiple & Actions Groupées** : Sélection groupée, favoris en masse et suppression.
- 🔔 **Centre de Notifications & Mises à Jour** : Surveillance hebdomadaire automatique du moteur `yt-dlp` et journal des erreurs en temps réel.
- 🚀 **Performance & Discrétion** : Surveillance du presse-papiers, mode silencieux en arrière-plan et raccourci global `Ctrl+Alt+H`.
"@

$release = $null
try {
    $existing = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases/tags/$tag" -Headers $headers -ErrorAction Stop
    Write-Host "La release $tag existe déjà (ID: $($existing.id))." -ForegroundColor Yellow
    $release = $existing
} catch {
    Write-Host "Création de la release $tag sur GitHub..." -ForegroundColor Green
    $createPayload = @{
        tag_name = $tag
        target_commitish = "main"
        name = $releaseName
        body = $releaseBody
        draft = $false
        prerelease = $false
    } | ConvertTo-Json -Depth 5

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases" -Method Post -Headers $headers -Body $createPayload -ContentType "application/json; charset=utf-8"
    Write-Host "Release créée avec succès ! ID: $($release.id)" -ForegroundColor Green
}

$releaseId = $release.id
$uploadBase = "https://uploads.github.com/repos/$owner/$repo/releases/$releaseId/assets"

$assetsToUpload = @(
    "$PSScriptRoot\..\Release\YouDlp-Dashboard-Standalone.exe",
    "$PSScriptRoot\..\Release\YouDlp-Dashboard-Lite.exe",
    "$PSScriptRoot\..\Release\README.txt"
)

# Récupérer les assets déjà existants pour éviter les doublons
$existingAssets = @{}
try {
    $assetsList = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases/$releaseId/assets" -Headers $headers
    foreach ($a in $assetsList) {
        $existingAssets[$a.name] = $a.id
    }
} catch {}

foreach ($assetPath in $assetsToUpload) {
    if (-not (Test-Path $assetPath)) {
        Write-Warning "Fichier introuvable : $assetPath"
        continue
    }

    $fileName = [System.IO.Path]::GetFileName($assetPath)
    $fileSizeMB = [Math]::Round(((Get-Item $assetPath).Length / 1MB), 2)

    if ($existingAssets.ContainsKey($fileName)) {
        Write-Host "Suppression de l'ancien asset existant $fileName (ID: $($existingAssets[$fileName]))..." -ForegroundColor Yellow
        try {
            Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases/assets/$($existingAssets[$fileName])" -Method Delete -Headers $headers
        } catch {}
    }

    Write-Host "Upload de $fileName ($fileSizeMB Mo) vers GitHub Release..." -ForegroundColor Cyan
    $uploadUri = "$uploadBase`?name=$fileName"
    
    $uploadHeaders = @{
        "Authorization" = "Bearer $token"
        "User-Agent" = "YouDlp-Dashboard-Releaser"
        "Content-Type" = "application/octet-stream"
    }

    try {
        $uploadResult = Invoke-RestMethod -Uri $uploadUri -Method Post -Headers $uploadHeaders -InFile $assetPath -TimeoutSec 900
        Write-Host "  -> Upload réussi : $($uploadResult.browser_download_url)" -ForegroundColor Green
    } catch {
        Write-Error "Échec de l'upload pour $fileName : $($_.Exception.Message)"
    }
}

Write-Host "`n=======================================================" -ForegroundColor Green
Write-Host " Release publiée avec succès !" -ForegroundColor Green
Write-Host " URL : $($release.html_url)" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
