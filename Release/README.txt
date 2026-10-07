========================================================================
             🎬 YouDlp Dashboard - Editions de Release
========================================================================

Ce dossier contient les 2 éditions de YouDlp Dashboard :

1. YouDlp-Dashboard-Standalone.exe (~110 Mo) [RECOMMANDÉ]
------------------------------------------------------------------------
- Totalement autonome : embarque yt-dlp, FFmpeg et l'interface Web.
- ZÉRO installation requise : placez simplement le fichier où vous voulez
  et lancez-le.
- Tout s'initialise automatiquement (dossier db, téléchargements, etc.).
- Mise à jour autonome :
  * Un check hebdomadaire (tous les 7 jours) interroge l'API GitHub de yt-dlp.
  * Si une nouvelle version existe, une boîte de dialogue vous propose la mise à jour (Oui / Non).
  * En validant (ou via le bouton du dashboard), `bin\yt-dlp.exe` est mis à jour
    directement sur votre disque.
  * L'exécutable fonctionne IMMÉDIATEMENT avec la nouvelle version, sans nécessiter
    de compilateur ni aucun outil externe !
  * Si le compilateur AHK est présent sur la machine, les .exe sont également
    ré-empaquetés pour de futures distributions.

2. YouDlp-Dashboard-Lite.exe (~1.4 Mo)
------------------------------------------------------------------------
- Version ultra-légère pour les utilisateurs ayant déjà yt-dlp et FFmpeg
  installés sur leur machine (dans le PATH Windows ou le dossier bin).
- Embarque l'interface Web complète.
- Idéal si vous gérez vous-même les binaires yt-dlp et FFmpeg.

------------------------------------------------------------------------
Options & Notifications :
- Notifications système (TrayTip Windows) : activables / désactivables
  à tout moment depuis l'interface Web (icône Paramètres ⚙) ou via le menu
  de la barre des tâches (clic droit sur l'icône Tray -> 🔔 Notifications système).

Raccourcis & Utilisation :
- Lancement : Double-cliquez sur le .exe (démarre discrètement en barre des tâches).
- Ouvrir le Dashboard Web : Ctrl + Alt + H (ou re-cliquez sur le .exe).
- Téléchargement instantané : Copiez un lien YouTube (Ctrl+C), le popup apparaît.
  * Flèche Gauche [ ← ] : Télécharger en MP4 (Vidéo)
  * Flèche Droite [ → ] : Télécharger en MP3 (Audio)
  * Échap : Fermer le popup
========================================================================
