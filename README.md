# 🎬 YouDlp-Dashboard - Serveur & UI Local

Un gestionnaire de téléchargement YouTube léger et robuste, piloté par `yt-dlp` et disposant d'une interface web ultra-rapide. Conçu pour s'intégrer facilement dans des environnements Windows (et combinable avec d'autres scripts AutoHotkey), il fonctionne en arrière-plan de manière asynchrone sans bloquer vos autres tâches.

---

## ✨ Fonctionnement et Architecture

Le projet est divisé en deux parties complémentaires :
1. **Un démon backend (AutoHotkey v1)** : 
   - Surveille le presse-papiers pour détecter des liens YouTube.
   - Gère une file d'attente (queue) asynchrone.
   - Lance les processus `yt-dlp` en arrière-plan.
   - Embarque son propre mini-serveur HTTP sur le port `9000`.
2. **Une interface frontend (HTML/JS)** : 
   - Un véritable dashboard moderne et sombre interrogeant le serveur AHK via une API REST JSON (`/api/data`, `/api/action`).

### ⚙️ Le Processus
1. **Détection** : Dès que vous copiez un lien (ou un texte contenant un lien), le script détecte l'URL et affiche instantanément un élégant pop-up au centre supérieur de votre écran (sans interférer avec votre souris).
2. **Choix du format** : Via la flèche Gauche (Vidéo MP4) ou Droite (Audio MP3), le lien est poussé dans la file d'attente (`db/queue.txt`).
3. **Téléchargement** : Le "Worker" AutoHotkey lit la queue toutes les 5 secondes et exécute `yt-dlp`. Le téléchargement s'effectue dans vos dossiers cibles sans aucune fenêtre visible.
4. **Suivi** : Pendant et après le téléchargement, les données remontent sur l'interface web (`http://localhost:9000`), où vous pouvez gérer vos favoris, trier, rechercher et consulter les erreurs si une vidéo a échoué.

---

## 🚀 Fonctionnalités Clés

- **Système de tri et recherche** : Filtrage en temps réel ultra-rapide par nom, favoris ou date.
- **Sauvegarde Robuste** : Gestion des doublons automatique et système de favoris reposant sur un fichier `favorites.ini` très réactif.
- **Gestion des erreurs** : Si `yt-dlp` échoue (vidéo privée, hors ligne), l'erreur remonte automatiquement dans l'onglet "Erreurs" de l'interface avec le log détaillé de `yt-dlp`.
- **Zéro latence UI** : Actualisations asynchrones et mise en cache stricte des actions de l'utilisateur pour une impression de fluidité parfaite.

---

## 🛠️ Dépendances Nécessaires

Pour que ce script fonctionne parfaitement, vous devez avoir sur votre machine :

1. **AutoHotkey v1.1+** : Le langage qui fait tourner le serveur `main.ahk` (ATTENTION: le script utilise la syntaxe AHK v1 et non v2).
2. **yt-dlp** : Le moteur de téléchargement incontournable. **Il doit être accessible dans votre variable d'environnement système `PATH`** (vous devez pouvoir taper `yt-dlp` dans un terminal).
3. **FFmpeg** : Requis par `yt-dlp` pour fusionner l'audio et la vidéo lors des téléchargements MP4, et pour la conversion MP3. **Il doit également être accessible dans votre `PATH`**.

---

## 📖 Installation & Lancement

1. Clonez ou téléchargez ce dossier (`Downloader`).
2. Modifiez le chemin des dossiers de téléchargements cibles dans le code de `main.ahk` (actuellement réglés sur `E:\Reste\Upload` et `E:\Reste\Podcast` par défaut).
3. Lancez **`main.ahk`**. (Il s'exécutera discrètement dans votre barre des tâches Windows).
4. Copiez un lien YouTube avec `Ctrl+C`.
5. Ouvrez le tableau de bord : **`Ctrl + Alt + H`** ou naviguez vers [http://localhost:9000](http://localhost:9000).

*(En cas de problème technique, consultez le fichier `db/debug.log` généré automatiquement par le serveur).*
