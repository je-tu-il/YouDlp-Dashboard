# Script d'enrichissement automatique des chaînes YouTube dans history.txt
# Ce script lit db/history.txt et interroge l'API oEmbed de YouTube pour récupérer le nom exact de la chaîne (auteur).

$histPath = "$PSScriptRoot\..\db\history.txt"
if (-not (Test-Path $histPath)) {
    Write-Warning "Fichier db/history.txt introuvable."
    exit
}

$lines = Get-Content $histPath -Encoding UTF8
$total = $lines.Count
Write-Host "Analyse de $total éléments dans l'historique..." -ForegroundColor Cyan

$updatedLines = @()
$modifiedCount = 0

for ($i = 0; $i -lt $total; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split("|||")
    
    # Structure : Titre ||| Chemin ||| ID ||| Format ||| Duree [||| Chaine]
    if ($parts.Count -ge 4) {
        $title = $parts[0]
        $path = $parts[1]
        $id = $parts[2]
        $fmt = $parts[3]
        $dur = if ($parts.Count -ge 5) { $parts[4] } else { "0" }
        $channel = if ($parts.Count -ge 6) { $parts[5] } else { "" }

        if ([string]::IsNullOrWhiteSpace($channel) -and -not [string]::IsNullOrWhiteSpace($id) -and $id.Length -ge 6) {
            try {
                $oembedUrl = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$id&format=json"
                $res = Invoke-RestMethod -Uri $oembedUrl -TimeoutSec 2 -ErrorAction Stop
                if ($res.author_name) {
                    $channel = $res.author_name.Trim()
                    $modifiedCount++
                    Write-Host "[$($i+1)/$total] ($id) Chaîne trouvée : $channel" -ForegroundColor Green
                }
            } catch {
                # Erreur réseau ou vidéo privée/supprimée, on conserve sans bloquer
            }
        }

        $newLine = "$title|||$path|||$id|||$fmt|||$dur|||$channel"
        $updatedLines += $newLine
    } else {
        $updatedLines += $line
    }
}

Set-Content -Path $histPath -Value $updatedLines -Encoding UTF8
Write-Host "`nTerminé ! $modifiedCount vidéos enrichies avec leur nom de chaîne exact." -ForegroundColor Cyan
