#NoEnv
#SingleInstance Off
#Persistent
SetWorkingDir %A_ScriptDir%
FileEncoding, UTF-8
#Include %A_ScriptDir%\lib\Socket.ahk

; ==============================================================================
; 🎬 YouDlp-Dashboard - Serveur Backend & Démon AHK
; ==============================================================================

; --- Icône & Menu Tray ---
IfExist, %A_ScriptDir%\a.ico
    Menu, Tray, Icon, %A_ScriptDir%\a.ico

Menu, Tray, NoStandard
Menu, Tray, Add, 🎬 Ouvrir le Dashboard`tCtrl+Alt+H, MenuOpenDashboard
Menu, Tray, Default, 🎬 Ouvrir le Dashboard`tCtrl+Alt+H
Menu, Tray, Add
Menu, Tray, Add, 📁 Dossier Vidéos (MP4), MenuOpenMP4
Menu, Tray, Add, 🎵 Dossier Musiques (MP3), MenuOpenMP3
Menu, Tray, Add
Menu, Tray, Add, 📋 Surveillance Presse-papiers, MenuToggleClipboard
Menu, Tray, Check, 📋 Surveillance Presse-papiers
Menu, Tray, Add, 🔔 Notifications système, MenuToggleNotifications
Menu, Tray, Check, 🔔 Notifications système
Menu, Tray, Add, 🚀 Lancer au démarrage de Windows, MenuToggleStartup
IfExist, %A_Startup%\YouDlp-Dashboard.lnk
    Menu, Tray, Check, 🚀 Lancer au démarrage de Windows
Menu, Tray, Add, 🔄 Mettre à jour et ré-empaqueter yt-dlp, MenuUpdateYtDlp
Menu, Tray, Add
Menu, Tray, Add, ♻ Redémarrer, MenuReload
Menu, Tray, Add, ❌ Quitter, MenuExit
Menu, Tray, Tip, YouDlp Dashboard Lite (Actif sur :9000)

; ------------------------------------------------------------------------------
; VARIABLES GLOBALES
; ------------------------------------------------------------------------------
global ClipboardURL := ""
global CurrentDownloadURL := ""
global CurrentDownloadType := ""
global CurrentDownloadTitle := ""
global CurrentDownloadQuality := ""
global CurrentDownloadVidID := ""
global currentDownloadPID := 0
global StateHash := ""
global hGui := 0
global LastClipboardURL := ""
global LastClipboardTime := 0

IfNotExist, %A_ScriptDir%\db
    FileCreateDir, %A_ScriptDir%\db

; ------------------------------------------------------------------------------
; CHARGEMENT DES PARAMETRES
; ------------------------------------------------------------------------------
global SettingSyncFile := "E:\Reste\Docs\Notes\DOWNLOAD.txt"
global SettingTheme := "dark"
global SettingAutoRetry := 0
global SettingPathMP4 := "E:\Reste\Upload"
global SettingPathMP3 := "E:\Reste\Podcast"
global SettingLabelMP4 := "MP4 (Vidéo)"
global SettingLabelMP3 := "MP3 (Audio)"
global SettingQuality := "720"
global SettingAudioQuality := "128k"
global SettingSponsorBlock := 1
global SettingAutoClosePopup := 12
global SettingClipboardMonitor := 1
global SettingNotifications := 1
global SettingLastUpdateCheck := ""

LoadSettings() {
    IniRead, SettingSyncFile, %A_ScriptDir%\db\settings.ini, General, SyncthingFile, E:\Reste\Docs\Notes\DOWNLOAD.txt
    IniRead, SettingTheme, %A_ScriptDir%\db\settings.ini, General, Theme, dark
    IniRead, SettingAutoRetry, %A_ScriptDir%\db\settings.ini, General, AutoRetry, 0
    IniRead, SettingPathMP4, %A_ScriptDir%\db\settings.ini, Paths, MP4, E:\Reste\Upload
    IniRead, SettingPathMP3, %A_ScriptDir%\db\settings.ini, Paths, MP3, E:\Reste\Podcast
    IniRead, SettingLabelMP4, %A_ScriptDir%\db\settings.ini, UI, LabelMP4, MP4 (Vidéo)
    IniRead, SettingLabelMP3, %A_ScriptDir%\db\settings.ini, UI, LabelMP3, MP3 (Audio)
    IniRead, SettingQuality, %A_ScriptDir%\db\settings.ini, Quality, VideoQuality, 720
    IniRead, SettingAudioQuality, %A_ScriptDir%\db\settings.ini, Quality, AudioQuality, 128k
    IniRead, SettingSponsorBlock, %A_ScriptDir%\db\settings.ini, General, SponsorBlock, 1
    IniRead, SettingAutoClosePopup, %A_ScriptDir%\db\settings.ini, UI, AutoClosePopup, 12
    IniRead, SettingClipboardMonitor, %A_ScriptDir%\db\settings.ini, General, ClipboardMonitor, 1
    IniRead, SettingNotifications, %A_ScriptDir%\db\settings.ini, General, Notifications, 1
    IniRead, SettingLastUpdateCheck, %A_ScriptDir%\db\settings.ini, General, LastUpdateCheck, %A_Space%

    if (SettingClipboardMonitor = 1)
        Menu, Tray, Check, 📋 Surveillance Presse-papiers
    else
        Menu, Tray, Uncheck, 📋 Surveillance Presse-papiers

    if (SettingNotifications = 1)
        Menu, Tray, Check, 🔔 Notifications système
    else
        Menu, Tray, Uncheck, 🔔 Notifications système
}
LoadSettings()

UpdateStateHash() {
    global StateHash
    StateHash := A_Now . A_MSec
}
UpdateStateHash()

; --- Extraction des ressources embarquées (si compilé) ---
FileInstall, www\history.html, %A_Temp%\youdlp_history.html, 1

global BinDir := A_ScriptDir "\bin"
IfNotExist, %BinDir%
    FileCreateDir, %BinDir%

; [Version Lite : utilise yt-dlp et ffmpeg du systeme / PATH]
global YtDlpExe := FileExist(BinDir "\yt-dlp.exe") ? (BinDir "\yt-dlp.exe") : (FileExist("E:\App\Pc\Installer\Cmd\Path\yt-dlp.exe") ? "E:\App\Pc\Installer\Cmd\Path\yt-dlp.exe" : "yt-dlp.exe")
global FfmpegExe := FileExist(BinDir "\ffmpeg.exe") ? (BinDir "\ffmpeg.exe") : (FileExist("E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin\ffmpeg.exe") ? "E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin\ffmpeg.exe" : "ffmpeg.exe")

; Ajout dynamique du dossier bin et FFmpeg au PATH pour yt-dlp
EnvGet, curPath, PATH
if (FileExist(BinDir) && !InStr(curPath, BinDir))
    EnvSet, PATH, BinDir . ";" . curPath
ffmpegSysDir := "E:\App\Pc\Installer\Cmd\Path\ffmpeg\bin"
if (FileExist(ffmpegSysDir) && !InStr(curPath, ffmpegSysDir))
    EnvSet, PATH, ffmpegSysDir . ";" . curPath

; ------------------------------------------------------------------------------
; GESTION INSTANCE UNIQUE VIA MUTEX
; ------------------------------------------------------------------------------
global hMutex := DllCall("CreateMutex", "Ptr", 0, "Int", 1, "Str", "YouDlpDashboardMutexInstance")
if (DllCall("GetLastError") = 183) { ; ERROR_ALREADY_EXISTS
    ; Une instance de YouDlp tourne déjà en tâche de fond !
    ; Re-cliquer sur le raccourci ouvre l'interface dans le navigateur !
    Run, http://localhost:9000/
    ExitApp
}

; ------------------------------------------------------------------------------
; DEMARRAGE DU SERVEUR HTTP
; ------------------------------------------------------------------------------
bound := false
Loop, 30 {
    try {
        global Server := new HttpServer()
        Server.Bind(["0.0.0.0", 9000])
        Server.Listen()
        bound := true
        break
    } catch e {
        Sleep, 500
    }
}
if (!bound) {
    MsgBox, 16, Erreur YouDlp Dashboard, Impossible de démarrer le serveur local sur le port 9000. Veuillez vérifier qu'aucune autre application n'utilise ce port.
    ExitApp
}

; Démarrer le worker de file d'attente
SetTimer, ProcessQueue, 3000

; Vérification hebdomadaire des mises à jour de yt-dlp
SetTimer, TimerWeeklyCheck, -6000
SetTimer, TimerWeeklyCheck, 86400000

; ------------------------------------------------------------------------------
; SURVEILLANCE DU PRESSE-PAPIERS
; ------------------------------------------------------------------------------
try {
    OnClipboardChange("ClipChanged")
}

; Démarrage silencieux en tâche de fond (ne pas ouvrir le navigateur sauf si --open)
shouldOpen := false
Loop, %0%
{
    param := %A_Index%
    if (param = "--open" || param = "/open" || param = "-o")
        shouldOpen := true
}
if (shouldOpen) {
    Run, http://localhost:9000/
} else {
    SafeTrayTip("YouDlp Dashboard", "Prêt en arrière-plan (Ctrl+Alt+H pour ouvrir le Dashboard)", 2, 1)
}
return ; Fin de la section auto-execute

ClipChanged(Type) {
    global SettingClipboardMonitor, ClipboardURL, LastClipboardURL, LastClipboardTime
    if (!SettingClipboardMonitor)
        return

    if (Type = 1) {
        clip := Trim(Clipboard)
        ; Détection des URLs YouTube (vidéos standard, shorts, live, playlists, youtu.be)
        if (RegExMatch(clip, "i)(https?://(?:www\.|m\.)?(?:youtube\.com/(?:watch\?v=[^&\s]+|shorts/[^?\s]+|live/[^?\s]+|playlist\?list=[^&\s]+)|youtu\.be/[^?\s]+))", match)) {
            matchedUrl := match1
            now := A_TickCount
            if (matchedUrl = LastClipboardURL && (now - LastClipboardTime) < 3500)
                return
            LastClipboardURL := matchedUrl
            LastClipboardTime := now
            ClipboardURL := matchedUrl
            ShowGUI()
        }
    }
}

; ------------------------------------------------------------------------------
; INTERFACE OVERLAY / POPUP FLOTTANT
; ------------------------------------------------------------------------------
global TempVideoTitle := ""

ShowGUI() {
    global
    TempVideoTitle := ClipboardURL

    Gui, Main:Destroy
    Gui, Main:New, +AlwaysOnTop -Caption +ToolWindow +Border +HWNDhGui
    Gui, Main:Color, 181b20
    Gui, Main:Margin, 16, 14

    ; Titre application
    Gui, Main:Font, s13 c38bdf8 bold, Segoe UI
    Gui, Main:Add, Text, w480 Center, 🎬 YouTube Downloader

    ; Titre de la vidéo (mis à jour asynchronement)
    displayTitle := ClipboardURL
    if (StrLen(displayTitle) > 65)
        displayTitle := SubStr(displayTitle, 1, 62) . "..."

    Gui, Main:Font, s11 cF1F5F9 norm, Segoe UI
    Gui, Main:Add, Text, w480 Center vGuiVideoTitle, %displayTitle%

    ; Ligne de séparation subtile
    Gui, Main:Add, Text, w480 h1 0x10 y+8

    ; Bouton MP4 (Cliquable à la souris et activé par Flèche Gauche)
    Gui, Main:Font, s12 cFFFFFF bold, Segoe UI
    Gui, Main:Add, Progress, x20 y+12 w230 h42 Background1d4ed8 Disabled
    Gui, Main:Add, Text, xp yp w230 h42 cWhite BackgroundTrans Center 0x200 gAddMP4, [ ← ] %SettingLabelMP4%

    ; Bouton MP3 (Cliquable à la souris et activé par Flèche Droite)
    Gui, Main:Add, Progress, x270 yp w230 h42 Background059669 Disabled
    Gui, Main:Add, Text, xp yp w230 h42 cWhite BackgroundTrans Center 0x200 gAddMP3, %SettingLabelMP3% [ → ]

    ; Bouton / Indication Options Web & Echap
    Gui, Main:Font, s9 c94A3B8 norm, Segoe UI
    Gui, Main:Add, Text, w480 x20 y+12 Center gOpenWebCustom, [ ↓ ] Options Web (Format, Qualité)  •  [ Échap ] Ignorer

    Gui, Main:Show, NoActivate xCenter y35, YouDlp Popup

    ; Coins arrondis
    WinGetPos, , , w, h, ahk_id %hGui%
    WinSet, Region, 0-0 w%w% h%h% R16-16, ahk_id %hGui%

    ; Raccourcis clavier quand le popup existe
    Hotkey, IfWinExist, ahk_id %hGui%
    Hotkey, Left, AddMP4, On
    Hotkey, Right, AddMP3, On
    Hotkey, Down, OpenWebCustom, On
    Hotkey, Escape, CloseGUI, On
    Hotkey, If

    ; Auto-fermeture si configurée
    if (SettingAutoClosePopup > 0) {
        timeoutMs := SettingAutoClosePopup * 1000
        SetTimer, AutoClosePopupTimer, -%timeoutMs%
    }

    ; Récupération du titre sans bloquer l'affichage initial
    SetTimer, FetchTitleAsync, -20
}

FetchTitleAsync:
    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(1000, 1000, 1000, 1000)
        req.Open("GET", "https://www.youtube.com/oembed?url=" . ClipboardURL . "&format=json", false)
        req.Send()
        if (RegExMatch(req.ResponseText, """title"":\s*""(.*?)""", mTitle)) {
            t := mTitle1
            t := StrReplace(t, "\""", """")
            t := StrReplace(t, "\\", "\")
            t := StrReplace(t, "\/", "/")
            TempVideoTitle := t
            if (hGui && WinExist("ahk_id " . hGui)) {
                if (StrLen(t) > 65)
                    t := SubStr(t, 1, 62) . "..."
                GuiControl, Main:, GuiVideoTitle, %t%
            }
        }
    } catch {
    }
return

AutoClosePopupTimer:
    GoSub, CloseGUI
return

OpenWebCustom:
    Run, http://localhost:9000/?custom_url=%ClipboardURL%
    GoSub, CloseGUI
return

AddMP4:
    safeTitle := StrReplace(TempVideoTitle, "|", "-")
    safeTitle := StrReplace(safeTitle, "`n", " ")
    safeTitle := StrReplace(safeTitle, "`r", "")
    FileAppend, %ClipboardURL%|mp4|%safeTitle%`n, %A_ScriptDir%\db\queue.txt
    UpdateStateHash()
    GoSub, CloseGUI
return

AddMP3:
    safeTitle := StrReplace(TempVideoTitle, "|", "-")
    safeTitle := StrReplace(safeTitle, "`n", " ")
    safeTitle := StrReplace(safeTitle, "`r", "")
    FileAppend, %ClipboardURL%|mp3|%safeTitle%`n, %A_ScriptDir%\db\queue.txt
    UpdateStateHash()
    GoSub, CloseGUI
return

CloseGUI:
    SetTimer, AutoClosePopupTimer, Off
    Gui, Main:Destroy
    if (hGui) {
        Hotkey, IfWinExist, ahk_id %hGui%
        Hotkey, Left, Off, UseErrorLevel
        Hotkey, Right, Off, UseErrorLevel
        Hotkey, Down, Off, UseErrorLevel
        Hotkey, Escape, Off, UseErrorLevel
        Hotkey, If
        hGui := 0
    }
return

; ------------------------------------------------------------------------------
; WORKER DE TELECHARGEMENT EN ARRIERE-PLAN
; ------------------------------------------------------------------------------
ProcessQueue:
    SetTimer, ProcessQueue, Off

    ; 1. Si un téléchargement est en cours, vérifier s'il est terminé
    if (currentDownloadPID != 0 && currentDownloadPID != "") {
        Process, Exist, %currentDownloadPID%
        if (!ErrorLevel) {
            ; Le processus est terminé
            statusFile := A_ScriptDir "\db\last_dl.txt"
            hasSucceeded := false
            if (FileExist(statusFile)) {
                hasSucceeded := true
                FileDelete, %statusFile%
            }

            histFile := A_ScriptDir "\db\history.txt"
            inHist := false
            if (FileExist(histFile) && CurrentDownloadVidID != "") {
                Loop, Read, %histFile%
                {
                    parts := StrSplit(A_LoopReadLine, "|||")
                    if (parts.MaxIndex() >= 4 && parts[3] = CurrentDownloadVidID && parts[4] = CurrentDownloadType) {
                        inHist := true
                        break
                    }
                }
            }

            if (hasSucceeded) {
                ; Si la vidéo était déjà téléchargée ou si after_move n'a pas réécrit dans history.txt
                if (!inHist) {
                    targetFolder := (CurrentDownloadType = "mp3") ? SettingPathMP3 : SettingPathMP4
                    targetExt := (CurrentDownloadType = "mp3") ? "*.mp3" : "*.*"
                    matchedFile := ""
                    if (FileExist(targetFolder)) {
                        Loop, Files, %targetFolder%\%targetExt%
                        {
                            if (CurrentDownloadVidID != "" && InStr(A_LoopFileName, CurrentDownloadVidID)) {
                                matchedFile := A_LoopFileFullPath
                                break
                            }
                            if (CurrentDownloadTitle != "" && StrLen(CurrentDownloadTitle) > 5 && InStr(A_LoopFileName, SubStr(CurrentDownloadTitle, 1, 20))) {
                                matchedFile := A_LoopFileFullPath
                                break
                            }
                        }
                        if (matchedFile = "") {
                            newestTime := 0
                            Loop, Files, %targetFolder%\%targetExt%
                            {
                                if (A_LoopFileTimeModified > newestTime) {
                                    newestTime := A_LoopFileTimeModified
                                    matchedFile := A_LoopFileFullPath
                                }
                            }
                        }
                    }
                    safeT := CurrentDownloadTitle ? CurrentDownloadTitle : "Vidéo"
                    safeT := StrReplace(safeT, "|", "-")
                    safeT := StrReplace(safeT, "`n", " ")
                    safeT := StrReplace(safeT, "`r", "")
                    FileAppend, %safeT%|||%matchedFile%|||%CurrentDownloadVidID%|||%CurrentDownloadType%|||0`n, %histFile%
                }
                SafeTrayTip("YouDlp Dashboard", "Téléchargement terminé avec succès !", 3, 1)
            } else {
                cleanVid := CurrentDownloadVidID ? CurrentDownloadVidID : "inconnu"
                cleanT := CurrentDownloadTitle ? CurrentDownloadTitle : "Échec"
                FileAppend, %cleanVid%|||%CurrentDownloadType%|||Échec du téléchargement|||%cleanT%`n, %A_ScriptDir%\db\errors.txt
                ; Si un téléchargement échoue (ex: changement YouTube), vérifier si yt-dlp a une mise à jour disponible
                SetTimer, AutoCheckYtDlpStartup, -100
            }

            UpdateStateHash()
            currentDownloadPID := 0
            CurrentDownloadURL := ""
            CurrentDownloadType := ""
            CurrentDownloadTitle := ""
            CurrentDownloadQuality := ""
            CurrentDownloadVidID := ""
        } else {
            ; En cours : on reprend la vérification dans 1.5s
            SetTimer, ProcessQueue, 1500
            return
        }
    }

    ; 2. Synchronisation de fichiers distants (ex: Syncthing, iPhone / Android)
    if (SettingSyncFile != "" && FileExist(SettingSyncFile)) {
        tempSync := A_ScriptDir "\db\sync_temp.txt"
        FileMove, %SettingSyncFile%, %tempSync%, 1
        if (!ErrorLevel && FileExist(tempSync)) {
            FileRead, syncContent, %tempSync%
            FileDelete, %tempSync%
            hasNew := false
            Loop, Parse, syncContent, `n, `r
            {
                line := Trim(A_LoopField)
                if (line = "")
                    continue

                if (RegExMatch(line, "^(mp3|mp4)=(.*)$", sMatch)) {
                    sFormat := sMatch1
                    sUrl := Trim(sMatch2)
                    FileAppend, %sUrl%|%sFormat%|URL Distante`n, %A_ScriptDir%\db\queue.txt
                    hasNew := true
                } else if (InStr(line, "http")) {
                    FileAppend, %line%|mp4|URL Distante`n, %A_ScriptDir%\db\queue.txt
                    hasNew := true
                }
            }
            if (hasNew)
                UpdateStateHash()
        }
    }

    ; 3. Vérifier s'il y a un élément dans la file d'attente
    if !FileExist(A_ScriptDir "\db\queue.txt") {
        SetTimer, ProcessQueue, 3000
        return
    }

    firstLine := ""
    remaining := ""
    Loop, Read, %A_ScriptDir%\db\queue.txt
    {
        if (A_Index = 1)
            firstLine := Trim(A_LoopReadLine)
        else if (Trim(A_LoopReadLine) != "")
            remaining .= A_LoopReadLine "`n"
    }

    if (firstLine = "") {
        FileDelete, %A_ScriptDir%\db\queue.txt
        SetTimer, ProcessQueue, 3000
        return
    }

    FileDelete, %A_ScriptDir%\db\queue.txt
    if (remaining != "")
        FileAppend, %remaining%, %A_ScriptDir%\db\queue.txt

    parts := StrSplit(firstLine, "|")
    url := parts[1]
    type := parts[2]
    title := parts.MaxIndex() >= 3 ? parts[3] : url
    quality := parts.MaxIndex() >= 4 ? parts[4] : SettingQuality

    if (url != "") {
        ; Récupération du titre réel si générique ou absent
        if (title = "URL Distante" || title = "" || title = url) {
            try {
                req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
                req.SetTimeouts(800, 800, 800, 800)
                req.Open("GET", "https://www.youtube.com/oembed?url=" . url . "&format=json", false)
                req.Send()
                if (RegExMatch(req.ResponseText, """title"":\s*""(.*?)""", mTitle)) {
                    t := mTitle1
                    t := StrReplace(t, "\""", """")
                    t := StrReplace(t, "\\", "\")
                    while RegExMatch(t, "\\u([0-9a-fA-F]{4})", uMatch) {
                        charCode := "0x" . uMatch1
                        char := Chr(charCode)
                        t := StrReplace(t, uMatch, char)
                    }
                    title := t
                }
            } catch {}
        }

        CurrentDownloadURL := url
        CurrentDownloadType := type
        CurrentDownloadTitle := title
        CurrentDownloadQuality := quality
        CurrentDownloadVidID := ExtractVideoID(url)

        histFile := A_ScriptDir "\db\history.txt"
        UpdateStateHash()

        ; SponsorBlock flag
        sbFlag := (SettingSponsorBlock = 1) ? "--sponsorblock-remove sponsor" : ""

        ; FFmpeg location flag
        ffmpegFolder := ""
        if (FileExist(FfmpegExe)) {
            SplitPath, FfmpegExe, , ffmpegFolder
            if (ffmpegFolder = "")
                ffmpegFolder := FfmpegExe
        } else if (FileExist(BinDir "\ffmpeg.exe")) {
            ffmpegFolder := BinDir
        }
        ffmpegFlag := (ffmpegFolder != "") ? ("--ffmpeg-location """ . ffmpegFolder . """") : ""

        statusFile := A_ScriptDir "\db\last_dl.txt"
        FileDelete, %statusFile%

        if (type = "mp3") {
            audioQual := (quality != "" && InStr(quality, "k")) ? quality : SettingAudioQuality
            cmdArgs := "-f ""bestaudio[language=fr]/bestaudio/best"" -x --audio-format mp3 --audio-quality " audioQual " " ffmpegFlag " -P ""home:" SettingPathMP3 """ -o ""%(title)s.%(ext)s"" --retries infinite --fragment-retries infinite " sbFlag " --no-warnings --extractor-args ""youtube:player_client=android,web"" --postprocessor-args ""ffmpeg:-avoid_negative_ts make_zero"" --print-to-file ""after_move:%(title)s|||%(filepath)s|||%(id)s|||mp3|||%(duration)s"" """ histFile """ --print-to-file ""after_video:OK:%(id)s"" """ statusFile """ """ url """"
        } else {
            ; Sélection résolution vidéo
            if (quality = "1080") {
                videoFmt := "bestvideo[height<=1080][ext=mp4]+bestaudio[language^=fr][ext=m4a]/bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best"
            } else if (quality = "best") {
                videoFmt := "bestvideo[ext=mp4]+bestaudio[language^=fr][ext=m4a]/bestvideo+bestaudio/best"
            } else if (quality = "480") {
                videoFmt := "bestvideo[height<=480][ext=mp4]+bestaudio[language^=fr][ext=m4a]/bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]/best[height<=480][ext=mp4]/best"
            } else {
                ; 720p par défaut
                videoFmt := "bestvideo[height<=720][ext=mp4]+bestaudio[language^=fr][ext=m4a]/bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best"
            }
            cmdArgs := "-f """ videoFmt """ --merge-output-format mp4 " ffmpegFlag " -P ""home:" SettingPathMP4 """ -o ""%(title)s.%(ext)s"" --retries infinite --fragment-retries infinite " sbFlag " --no-warnings --extractor-args ""youtube:player_client=android,web"" --print-to-file ""after_move:%(title)s|||%(filepath)s|||%(id)s|||mp4|||%(duration)s"" """ histFile """ --print-to-file ""after_video:OK:%(id)s"" """ statusFile """ """ url """"
        }

        DetectHiddenWindows, On
        Run, "%YtDlpExe%" %cmdArgs%, %A_ScriptDir%, Hide UseErrorLevel, currentDownloadPID
    }

    SetTimer, ProcessQueue, 2000
return

; ------------------------------------------------------------------------------
; FONCTIONS UTILITAIRES & JSON ESCAPE
; ------------------------------------------------------------------------------
JsonEscape(str) {
    if (str = "")
        return ""
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, """", "\""")
    str := StrReplace(str, "`r", "")
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`t", "\t")
    str := RegExReplace(str, "[\x00-\x1F]", "")
    return str
}

ExtractVideoID(url) {
    if RegExMatch(url, "i)(?:v=|shorts/|live/|youtu\.be/)([^?&/\s]+)", m)
        return m1
    return ""
}

ShowHistory() {
    Run, http://localhost:9000/
}

SafeTrayTip(title, text, timeout:=2, options:=1) {
    global SettingNotifications
    if (SettingNotifications = 1) {
        TrayTip, %title%, %text%, %timeout%, %options%
    }
}

; ------------------------------------------------------------------------------
; SERVEUR HTTP EMBARQUE
; ------------------------------------------------------------------------------
class HttpServer extends SocketTCP {
    OnAccept() {
        try {
            client := this.Accept()
            client.base := this.base
            client.EventProcRegister(this.FD_READ | this.FD_CLOSE)
        }
    }

    OnRecv() {
        try {
            request := this.RecvText()

            ; Lecture corps de requête POST complet
            if (RegExMatch(request, "i)Content-Length:\s*(\d+)", lenMatch)) {
                contentLen := lenMatch1 + 0
                bodyPos := InStr(request, "`r`n`r`n")
                if (bodyPos > 0)
                    bodyContent := SubStr(request, bodyPos + 4)
                else {
                    bodyPos := InStr(request, "`n`n")
                    bodyContent := (bodyPos > 0) ? SubStr(request, bodyPos + 2) : ""
                }
                bodyLen := StrPut(bodyContent, "UTF-8") - 1

                startWait := A_TickCount
                while (bodyLen < contentLen && (A_TickCount - startWait) < 2000) {
                    if (this.MsgSize() > 0) {
                        extra := this.RecvText()
                        if (extra != "") {
                            request .= extra
                            bodyContent .= extra
                            bodyLen := StrPut(bodyContent, "UTF-8") - 1
                        }
                    } else {
                        Sleep, 15
                    }
                }
            }

            if (RegExMatch(request, "s)^GET ([^\s]+)", match)) {
                path := match1
                queryPos := InStr(path, "?")
                if (queryPos > 0)
                    path := SubStr(path, 1, queryPos - 1)

                if (path = "/" || path = "/history") {
                    htmlPath := FileExist(A_ScriptDir "\www\history.html") ? (A_ScriptDir "\www\history.html") : (A_Temp "\youdlp_history.html")
                    FileRead, html, %htmlPath%
                    len := StrPut(html, "UTF-8") - 1
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`nCache-Control: no-store, no-cache, must-revalidate, max-age=0`r`nContent-Type: text/html; charset=UTF-8`r`nContent-Length: " len "`r`n`r`n" html)
                } else if (path = "/api/status") {
                    json := "{""hash"":""" StateHash """}"
                    len := StrPut(json, "UTF-8") - 1
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`nCache-Control: no-store, no-cache, must-revalidate, max-age=0`r`nContent-Type: application/json; charset=UTF-8`r`nContent-Length: " len "`r`n`r`n" json)
                } else if (path = "/api/data") {
                    json := "["
                    global CurrentDownloadURL, CurrentDownloadType, CurrentDownloadTitle, currentDownloadPID

                    ; 1. Téléchargement en cours + Progression en direct
                    if (CurrentDownloadURL != "") {
                        progPercent := ""
                        progSpeed := ""
                        progETA := ""
                        if (currentDownloadPID != 0 && currentDownloadPID != "") {
                            DetectHiddenWindows, On
                            WinGetTitle, progTitle, ahk_pid %currentDownloadPID%
                            if InStr(progTitle, "PROG:") {
                                progData := SubStr(progTitle, InStr(progTitle, "PROG:") + 5)
                                pParts := StrSplit(progData, "|")
                                if (pParts.MaxIndex() >= 3) {
                                    progPercent := Trim(pParts[1])
                                    progSpeed := Trim(pParts[2])
                                    progETA := Trim(pParts[3])
                                }
                            }
                        }
                        json .= "{""statut"":""En cours"",""url"":""" JsonEscape(CurrentDownloadURL) """,""format"":""" JsonEscape(CurrentDownloadType) """,""title"":""" JsonEscape(CurrentDownloadTitle) """,""percent"":""" JsonEscape(progPercent) """,""speed"":""" JsonEscape(progSpeed) """,""eta"":""" JsonEscape(progETA) """},"
                    }

                    ; 2. File d'attente
                    If FileExist(A_ScriptDir "\db\queue.txt") {
                        FileRead, queueRaw, %A_ScriptDir%\db\queue.txt
                        Loop, Parse, queueRaw, `n, `r
                        {
                            if (Trim(A_LoopField) = "")
                                continue
                            parts := StrSplit(A_LoopField, "|")
                            if (parts.MaxIndex() >= 2) {
                                qUrl := parts[1]
                                qFmt := parts[2]
                                qTitle := parts.MaxIndex() >= 3 ? parts[3] : qUrl
                                json .= "{""statut"":""En attente"",""url"":""" JsonEscape(qUrl) """,""format"":""" JsonEscape(qFmt) """,""title"":""" JsonEscape(qTitle) """},"
                            }
                        }
                    }

                    ; 3. Favoris
                    favIds := {}
                    If FileExist(A_ScriptDir "\db\favorites.ini") {
                        IniRead, favKeys, %A_ScriptDir%\db\favorites.ini, Favorites
                        Loop, Parse, favKeys, `n, `r
                        {
                            fParts := StrSplit(A_LoopField, "=")
                            if (fParts[1] != "")
                                favIds[fParts[1]] := true
                        }
                    }

                    ; 4. Historique (optimisé en 1 seule lecture mémoire et sans FileExist répétitifs)
                    If FileExist(A_ScriptDir "\db\history.txt") {
                        FileRead, histRaw, %A_ScriptDir%\db\history.txt
                        dedupHistory := {}
                        historyOrder := []
                        Loop, Parse, histRaw, `n, `r
                        {
                            if (Trim(A_LoopField) = "")
                                continue
                            parts := StrSplit(A_LoopField, "|||")
                            if (parts.MaxIndex() >= 4) {
                                key := parts[3] . "_" . parts[4]
                                if (!dedupHistory.HasKey(key))
                                    historyOrder.Push(key)
                                dedupHistory[key] := parts
                            }
                        }

                        For _, key in historyOrder {
                            parts := dedupHistory[key]
                            hTitle := parts[1]
                            hPath := parts[2]
                            hId := parts[3]
                            hFormat := parts[4]
                            hDuration := parts.MaxIndex() >= 5 ? parts[5] : "0"
                            isFav := favIds[hId] ? "true" : "false"

                            json .= "{""statut"":""Termine"",""title"":""" JsonEscape(hTitle) """,""path"":""" JsonEscape(hPath) """,""id"":""" JsonEscape(hId) """,""format"":""" JsonEscape(hFormat) """,""duration"":""" JsonEscape(hDuration) """,""fav"":" isFav ",""exists"":true},"
                        }
                    }

                    ; 5. Erreurs
                    If FileExist(A_ScriptDir "\db\errors.txt") {
                        FileRead, errRaw, %A_ScriptDir%\db\errors.txt
                        Loop, Parse, errRaw, `n, `r
                        {
                            if (Trim(A_LoopField) = "")
                                continue
                            parts := StrSplit(A_LoopField, "|||")
                            if (parts.MaxIndex() >= 3) {
                                eId := parts[1]
                                eFmt := parts[2]
                                eErr := parts[3]
                                eTitle := parts.MaxIndex() >= 4 ? parts[4] : "Erreur lors du téléchargement"
                                json .= "{""statut"":""Erreur"",""id"":""" JsonEscape(eId) """,""format"":""" JsonEscape(eFmt) """,""title"":""" JsonEscape(eTitle) """,""error"":""" JsonEscape(eErr) """},"
                            }
                        }
                    }

                    if (SubStr(json, 0) = ",")
                        json := SubStr(json, 1, StrLen(json) - 1)
                    json .= "]"

                    len := StrPut(json, "UTF-8") - 1
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`nCache-Control: no-store, no-cache, must-revalidate, max-age=0`r`nContent-Type: application/json; charset=UTF-8`r`nContent-Length: " len "`r`n`r`n" json)
                } else if (path = "/api/settings") {
                    json := "{"
                    json .= """theme"":""" JsonEscape(SettingTheme) ""","
                    json .= """autoRetry"":" SettingAutoRetry ","
                    json .= """syncFile"":""" JsonEscape(SettingSyncFile) ""","
                    json .= """pathMP4"":""" JsonEscape(SettingPathMP4) ""","
                    json .= """pathMP3"":""" JsonEscape(SettingPathMP3) ""","
                    json .= """labelMP4"":""" JsonEscape(SettingLabelMP4) ""","
                    json .= """labelMP3"":""" JsonEscape(SettingLabelMP3) ""","
                    json .= """quality"":""" JsonEscape(SettingQuality) ""","
                    json .= """audioQuality"":""" JsonEscape(SettingAudioQuality) ""","
                    json .= """sponsorBlock"":" SettingSponsorBlock ","
                    json .= """autoClosePopup"":" SettingAutoClosePopup ","
                    json .= """clipboardMonitor"":" SettingClipboardMonitor ","
                    json .= """notifications"":" SettingNotifications
                    json .= "}"
                    len := StrPut(json, "UTF-8") - 1
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nCache-Control: no-store, no-cache, must-revalidate, max-age=0`r`nContent-Type: application/json; charset=UTF-8`r`nContent-Length: " len "`r`n`r`n" json)
                } else if (path = "/api/sysinfo") {
                    ytdlpStatus := "Disponible"
                    targetYt := YtDlpExe ? YtDlpExe : (A_ScriptDir "\bin\yt-dlp.exe")
                    if FileExist(targetYt) {
                        FileGetVersion, ytVer, %targetYt%
                        if (ytVer != "")
                            ytdlpStatus := ytVer . " (Opérationnel)"
                    }
                    ffmpegStatus := FileExist(FfmpegExe) ? "Disponible" : "Non détecté"
                    lastCheckStr := "Jamais"
                    if (SettingLastUpdateCheck != "") {
                        lastCheckStr := SubStr(SettingLastUpdateCheck, 1, 4) . "-" . SubStr(SettingLastUpdateCheck, 5, 2) . "-" . SubStr(SettingLastUpdateCheck, 7, 2)
                    }
                    json := "{""ytdlp"":""" JsonEscape(ytdlpStatus) """,""ffmpeg"":""" JsonEscape(ffmpegStatus) """,""lastCheck"":""" JsonEscape(lastCheckStr) """}"
                    len := StrPut(json, "UTF-8") - 1
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nCache-Control: no-store, no-cache, must-revalidate, max-age=0`r`nContent-Type: application/json; charset=UTF-8`r`nContent-Length: " len "`r`n`r`n" json)
                } else {
                    this.SendText("HTTP/1.1 404 Not Found`r`nConnection: close`r`nContent-Length: 0`r`n`r`n")
                }
            } else if (RegExMatch(request, "s)^POST ([^\s]+)", postMatch)) {
                path := postMatch1
                queryPos := InStr(path, "?")
                if (queryPos > 0)
                    path := SubStr(path, 1, queryPos - 1)

                bodyPos := InStr(request, "`r`n`r`n")
                if (bodyPos > 0)
                    body := SubStr(request, bodyPos + 4)
                else {
                    bodyPos := InStr(request, "`n`n")
                    body := (bodyPos > 0) ? SubStr(request, bodyPos + 2) : ""
                }

                if (path = "/api/action") {
                    RegExMatch(body, """action""\s*:\s*""([^""]+)""", actionMatch)
                    RegExMatch(body, """target""\s*:\s*""([^""]*)""", targetMatch)
                    action := actionMatch1
                    target := targetMatch1

                    if (action = "stop") {
                        if (currentDownloadPID)
                            Process, Close, %currentDownloadPID%
                        Process, Close, yt-dlp.exe
                        currentDownloadPID := 0
                        CurrentDownloadURL := ""
                        CurrentDownloadType := ""
                        CurrentDownloadTitle := ""
                    } else if (action = "open_file" && target != "") {
                        cleanTarget := StrReplace(target, "\\", "\")
                        if FileExist(cleanTarget) {
                            Run, "%cleanTarget%"
                        } else {
                            SafeTrayTip("YouDlp", "Fichier introuvable : " . cleanTarget, 3, 2)
                        }
                    } else if (action = "open_folder" && target != "") {
                        cleanTarget := StrReplace(target, "\\", "\")
                        if FileExist(cleanTarget) {
                            Run, % "explorer.exe /select,""" cleanTarget """"
                        } else {
                            SplitPath, cleanTarget, , parentDir
                            if InStr(FileExist(parentDir), "D")
                                Run, "%parentDir%"
                        }
                    } else if (action = "delete_file" && target != "") {
                        cleanTarget := StrReplace(target, "\\", "\")
                        if FileExist(cleanTarget)
                            FileDelete, %cleanTarget%

                        ; Retirer également de l'historique
                        newHistory := ""
                        Loop, Read, %A_ScriptDir%\db\history.txt
                        {
                            if (Trim(A_LoopReadLine) = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|||")
                            if (parts.MaxIndex() >= 2 && parts[2] != cleanTarget) {
                                newHistory .= A_LoopReadLine "`n"
                            }
                        }
                        FileDelete, %A_ScriptDir%\db\history.txt
                        if (newHistory != "")
                            FileAppend, %newHistory%, %A_ScriptDir%\db\history.txt
                    } else if (action = "clear_history") {
                        FileDelete, %A_ScriptDir%\db\history.txt
                    } else if (action = "clear_errors") {
                        FileDelete, %A_ScriptDir%\db\errors.txt
                    } else if (action = "toggle_favorite" && target != "") {
                        IniRead, isFav, %A_ScriptDir%\db\favorites.ini, Favorites, %target%, 0
                        if (isFav = "1")
                            IniDelete, %A_ScriptDir%\db\favorites.ini, Favorites, %target%
                        else
                            IniWrite, 1, %A_ScriptDir%\db\favorites.ini, Favorites, %target%
                    } else if (action = "delete" && target != "") {
                        newHistory := ""
                        Loop, Read, %A_ScriptDir%\db\history.txt
                        {
                            if (Trim(A_LoopReadLine) = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|||")
                            if (parts[3] != target) {
                                newHistory .= A_LoopReadLine "`n"
                            }
                        }
                        FileDelete, %A_ScriptDir%\db\history.txt
                        if (newHistory != "")
                            FileAppend, %newHistory%, %A_ScriptDir%\db\history.txt
                    } else if (action = "delete_error" && target != "") {
                        newErrors := ""
                        Loop, Read, %A_ScriptDir%\db\errors.txt
                        {
                            if (Trim(A_LoopReadLine) = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|||")
                            if (parts[1] != target) {
                                newErrors .= A_LoopReadLine "`n"
                            }
                        }
                        FileDelete, %A_ScriptDir%\db\errors.txt
                        if (newErrors != "")
                            FileAppend, %newErrors%, %A_ScriptDir%\db\errors.txt
                    } else if (action = "remove_queue" && target != "") {
                        newQueue := ""
                        Loop, Read, %A_ScriptDir%\db\queue.txt
                        {
                            parts := StrSplit(A_LoopReadLine, "|")
                            if (parts[1] != target)
                                newQueue .= A_LoopReadLine "`n"
                        }
                        FileDelete, %A_ScriptDir%\db\queue.txt
                        if (newQueue != "")
                            FileAppend, %newQueue%, %A_ScriptDir%\db\queue.txt
                    } else if (action = "retry_error" && target != "") {
                        newErrors := ""
                        requeueUrl := ""
                        requeueFormat := ""
                        requeueTitle := ""
                        Loop, Read, %A_ScriptDir%\db\errors.txt
                        {
                            if (Trim(A_LoopReadLine) = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|||")
                            if (parts[1] = target) {
                                requeueUrl := "https://www.youtube.com/watch?v=" . parts[1]
                                requeueFormat := parts[2]
                                requeueTitle := parts.MaxIndex() >= 4 ? parts[4] : "Erreur"
                            } else {
                                newErrors .= A_LoopReadLine "`n"
                            }
                        }
                        FileDelete, %A_ScriptDir%\db\errors.txt
                        if (newErrors != "")
                            FileAppend, %newErrors%, %A_ScriptDir%\db\errors.txt
                        if (requeueUrl != "")
                            FileAppend, %requeueUrl%|%requeueFormat%|%requeueTitle%`n, %A_ScriptDir%\db\queue.txt
                    } else if (action = "update_ytdlp" || action = "check_update") {
                        SetTimer, AsyncManualUpdateYtDlp, -50
                    }

                    UpdateStateHash()
                    this.SendText("HTTP/1.1 200 OK`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`nContent-Length: 2`r`n`r`nOK")
                } else if (path = "/" || path = "/api/add") {
                    RegExMatch(body, """action""\s*:\s*""([^""]+)""", actionMatch)
                    RegExMatch(body, """url""\s*:\s*""([^""]+)""", urlMatch)
                    RegExMatch(body, """type""\s*:\s*""([^""]+)""", typeMatch)
                    RegExMatch(body, """quality""\s*:\s*""([^""]*)""", qualMatch)
                    action := actionMatch1
                    url := urlMatch1
                    type := typeMatch1
                    quality := qualMatch1 ? qualMatch1 : SettingQuality

                    if (action = "add" && url != "") {
                        vidTitle := url
                        try {
                            req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
                            req.SetTimeouts(1000, 1000, 1000, 1000)
                            req.Open("GET", "https://www.youtube.com/oembed?url=" . url . "&format=json", false)
                            req.Send()
                            if (RegExMatch(req.ResponseText, """title"":\s*""(.*?)""", m)) {
                                vidTitle := m1
                                vidTitle := StrReplace(vidTitle, "\""", """")
                                vidTitle := StrReplace(vidTitle, "\\", "\")
                            }
                        } catch {}
                        safeTitle := StrReplace(vidTitle, "|", "-")
                        safeTitle := StrReplace(safeTitle, "`n", " ")
                        safeTitle := StrReplace(safeTitle, "`r", "")
                        FileAppend, %url%|%type%|%safeTitle%|%quality%`n, %A_ScriptDir%\db\queue.txt
                        UpdateStateHash()
                        SafeTrayTip("YouTube Downloader", url . " ajouté (" . type . ")", 2, 1)
                    }
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: 2`r`n`r`nOK")
                } else if (path = "/api/savesettings") {
                    RegExMatch(body, """syncFile""\s*:\s*""([^""]+)""", syncFileMatch)
                    RegExMatch(body, """theme""\s*:\s*""([^""]+)""", themeMatch)
                    RegExMatch(body, """autoRetry""\s*:\s*(\d+)", autoRetryMatch)
                    RegExMatch(body, """pathMP4""\s*:\s*""([^""]+)""", pathMP4Match)
                    RegExMatch(body, """pathMP3""\s*:\s*""([^""]+)""", pathMP3Match)
                    RegExMatch(body, """labelMP4""\s*:\s*""([^""]+)""", labelMP4Match)
                    RegExMatch(body, """labelMP3""\s*:\s*""([^""]+)""", labelMP3Match)
                    RegExMatch(body, """quality""\s*:\s*""([^""]+)""", qualMatch)
                    RegExMatch(body, """audioQuality""\s*:\s*""([^""]+)""", audioQualMatch)
                    RegExMatch(body, """sponsorBlock""\s*:\s*(\d+)", sbMatch)
                    RegExMatch(body, """autoClosePopup""\s*:\s*(\d+)", acpMatch)
                    RegExMatch(body, """clipboardMonitor""\s*:\s*(\d+)", cbmMatch)
                    RegExMatch(body, """notifications""\s*:\s*(\d+)", notifMatch)

                    IniWrite, % StrReplace(syncFileMatch1, "\\", "\"), %A_ScriptDir%\db\settings.ini, General, SyncthingFile
                    IniWrite, % themeMatch1, %A_ScriptDir%\db\settings.ini, General, Theme
                    IniWrite, % autoRetryMatch1, %A_ScriptDir%\db\settings.ini, General, AutoRetry
                    IniWrite, % StrReplace(pathMP4Match1, "\\", "\"), %A_ScriptDir%\db\settings.ini, Paths, MP4
                    IniWrite, % StrReplace(pathMP3Match1, "\\", "\"), %A_ScriptDir%\db\settings.ini, Paths, MP3
                    IniWrite, % labelMP4Match1, %A_ScriptDir%\db\settings.ini, UI, LabelMP4
                    IniWrite, % labelMP3Match1, %A_ScriptDir%\db\settings.ini, UI, LabelMP3
                    IniWrite, % qualMatch1, %A_ScriptDir%\db\settings.ini, Quality, VideoQuality
                    IniWrite, % audioQualMatch1, %A_ScriptDir%\db\settings.ini, Quality, AudioQuality
                    IniWrite, % sbMatch1, %A_ScriptDir%\db\settings.ini, General, SponsorBlock
                    IniWrite, % acpMatch1, %A_ScriptDir%\db\settings.ini, UI, AutoClosePopup
                    IniWrite, % cbmMatch1, %A_ScriptDir%\db\settings.ini, General, ClipboardMonitor
                    if (notifMatch1 != "")
                        IniWrite, % notifMatch1, %A_ScriptDir%\db\settings.ini, General, Notifications

                    LoadSettings()
                    this.SendText("HTTP/1.1 200 OK`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`nContent-Length: 2`r`n`r`nOK")
                }
            }
            this.Disconnect()
        } catch e {
            this.Disconnect()
        }
    }
}

; ------------------------------------------------------------------------------
; TRAY MENU HANDLERS
; ------------------------------------------------------------------------------
MenuOpenDashboard:
    ShowHistory()
return

MenuOpenMP4:
    if InStr(FileExist(SettingPathMP4), "D")
        Run, "%SettingPathMP4%"
    else
        MsgBox, 48, Dossier introuvable, Le dossier MP4 n'existe pas : %SettingPathMP4%
return

MenuOpenMP3:
    if InStr(FileExist(SettingPathMP3), "D")
        Run, "%SettingPathMP3%"
    else
        MsgBox, 48, Dossier introuvable, Le dossier MP3 n'existe pas : %SettingPathMP3%
return

MenuToggleClipboard:
    SettingClipboardMonitor := !SettingClipboardMonitor
    IniWrite, %SettingClipboardMonitor%, %A_ScriptDir%\db\settings.ini, General, ClipboardMonitor
    if (SettingClipboardMonitor) {
        Menu, Tray, Check, 📋 Surveillance Presse-papiers
        SafeTrayTip("YouDlp", "Surveillance du presse-papiers activée", 2, 1)
    } else {
        Menu, Tray, Uncheck, 📋 Surveillance Presse-papiers
        SafeTrayTip("YouDlp", "Surveillance du presse-papiers désactivée", 2, 1)
    }
return

MenuToggleNotifications:
    SettingNotifications := !SettingNotifications
    IniWrite, %SettingNotifications%, %A_ScriptDir%\db\settings.ini, General, Notifications
    if (SettingNotifications) {
        Menu, Tray, Check, 🔔 Notifications système
        SafeTrayTip("YouDlp Dashboard", "Notifications système activées", 2, 1)
    } else {
        Menu, Tray, Uncheck, 🔔 Notifications système
    }
return

MenuToggleStartup:
    startupShortcut := A_Startup . "\YouDlp-Dashboard.lnk"
    if FileExist(startupShortcut) {
        FileDelete, %startupShortcut%
        Menu, Tray, Uncheck, 🚀 Lancer au démarrage de Windows
        SafeTrayTip("YouDlp Dashboard", "Démarrage automatique désactivé", 2, 1)
    } else {
        targetExe := A_ScriptDir "\YouDlp-Dashboard.exe"
        if !FileExist(targetExe)
            targetExe := A_IsCompiled ? A_ScriptFullPath : A_ScriptDir "\YouDlp.exe"
        if !FileExist(targetExe)
            targetExe := A_ScriptFullPath
        FileCreateShortcut, %targetExe%, %startupShortcut%, %A_ScriptDir%, --silent, YouDlp Dashboard, %A_ScriptDir%\a.ico
        Menu, Tray, Check, 🚀 Lancer au démarrage de Windows
        SafeTrayTip("YouDlp Dashboard", "Démarrage automatique avec Windows activé", 2, 1)
    }
return

AutoCheckYtDlpStartup:
TimerWeeklyCheck:
    CheckWeeklyYtDlpUpdate(false)
return

AsyncManualUpdateYtDlp:
AsyncUpdateYtDlp:
MenuUpdateYtDlp:
    CheckWeeklyYtDlpUpdate(true)
return

CheckWeeklyYtDlpUpdate(manual:=false) {
    global SettingLastUpdateCheck, YtDlpExe
    targetExe := YtDlpExe ? YtDlpExe : (A_ScriptDir "\bin\yt-dlp.exe")
    if (!FileExist(targetExe))
        return

    ; Si vérification automatique périodique, vérifier si 7 jours se sont écoulés
    if (!manual && SettingLastUpdateCheck != "") {
        diffDays := A_Now
        EnvSub, diffDays, %SettingLastUpdateCheck%, Days
        if (diffDays < 7)
            return
    }

    ; Enregistrer la date du check
    todayStr := SubStr(A_Now, 1, 8)
    SettingLastUpdateCheck := todayStr
    IniWrite, %todayStr%, %A_ScriptDir%\db\settings.ini, General, LastUpdateCheck

    if (manual)
        SafeTrayTip("YouDlp Dashboard", "Vérification des mises à jour de yt-dlp...", 3, 1)

    ; 1. Obtenir la version locale de yt-dlp
    localVer := ""
    FileGetVersion, localVer, %targetExe%
    localNorm := 0
    if (localVer != "") {
        if (RegExMatch(localVer, "(\d{4})\.(\d{1,2})\.(\d{1,2})", l))
            localNorm := l1 . SubStr("0" . l2, -1) . SubStr("0" . l3, -1)
    }

    ; 2. Interroger l'API GitHub des releases officielles de yt-dlp
    latestTag := ""
    try {
        whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest", true)
        whr.SetRequestHeader("User-Agent", "YouDlp-Dashboard")
        whr.Send()
        whr.WaitForResponse(5)
        if (whr.Status = 200) {
            resp := whr.ResponseText
            if (RegExMatch(resp, "i)""tag_name""\s*:\s*""([^""]+)""", m))
                latestTag := m1
        }
    }

    remoteNorm := 0
    if (latestTag != "") {
        if (RegExMatch(latestTag, "(\d{4})\.(\d{1,2})\.(\d{1,2})", r))
            remoteNorm := r1 . SubStr("0" . r2, -1) . SubStr("0" . r3, -1)
    }

    ; 3. Décision selon la comparaison des versions
    if (remoteNorm > 0 && localNorm > 0) {
        if (remoteNorm > localNorm) {
            ; Une nouvelle version est disponible -> Proposer à l'utilisateur
            MsgBox, 36, YouDlp Dashboard - Mise à jour disponible, Une nouvelle version de yt-dlp est disponible !`n`nVersion actuelle : %localVer%`nNouvelle version : %latestTag%`n`nSouhaitez-vous installer la mise à jour maintenant ?
            IfMsgBox, Yes
            {
                DoUpdateYtDlp(latestTag)
            }
        } else {
            if (manual)
                SafeTrayTip("YouDlp Dashboard", "yt-dlp est déjà à jour (version " . localVer . ").", 3, 1)
        }
    } else {
        ; En cas d'échec requête réseau (hors-ligne ou rate-limit), fallback yt-dlp -U si action manuelle
        if (manual) {
            DoUpdateYtDlp()
        }
    }
    UpdateStateHash()
}

DoUpdateYtDlp(targetVersion:="") {
    global YtDlpExe
    targetExe := YtDlpExe ? YtDlpExe : (A_ScriptDir "\bin\yt-dlp.exe")
    if (!FileExist(targetExe))
        return

    SafeTrayTip("YouDlp Dashboard", "Téléchargement de la mise à jour de yt-dlp...", 3, 1)
    FileGetTime, timeBefore, %targetExe%, M
    RunWait, "%targetExe%" -U, %A_ScriptDir%, Hide UseErrorLevel
    FileGetTime, timeAfter, %targetExe%, M

    if (timeAfter != "" && timeBefore != "" && timeAfter != timeBefore) {
        SafeTrayTip("YouDlp Dashboard", "Nouvelle version de yt-dlp installée avec succès !", 4, 1)
        RebundleAllExes()
    } else if (targetVersion != "") {
        SafeTrayTip("YouDlp Dashboard", "Mise à jour de yt-dlp effectuée.", 3, 1)
        RebundleAllExes()
    } else {
        SafeTrayTip("YouDlp Dashboard", "yt-dlp est déjà à jour.", 3, 1)
    }
    UpdateStateHash()
}

RebundleAllExes() {
    ahkCompiler := "E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Ahk2Exe.exe"
    if (!FileExist(ahkCompiler))
        return

    iconPath := A_ScriptDir "\a.ico"
    iconParam := FileExist(iconPath) ? " /icon """ iconPath """" : ""
    binFile := "E:\App\All\Utilitaire\App\AutoHotkey_1.1.24.02.zip_extrait\Compiler\Unicode 64-bit.bin"
    binParam := FileExist(binFile) ? " /bin """ binFile """" : ""

    ; 1. Recompiler la version Standalone
    mainAhk := A_ScriptDir "\main.ahk"
    if FileExist(mainAhk) {
        outStandalone := A_ScriptDir "\YouDlp-Dashboard-Standalone.exe"
        cmdLine1 := """" ahkCompiler """ /in """ mainAhk """ /out """ outStandalone """" iconParam binParam
        RunWait, %cmdLine1%, %A_ScriptDir%, Hide UseErrorLevel
        FileCopy, %outStandalone%, %A_ScriptDir%\YouDlp-Dashboard.exe, 1
    }

    ; 2. Recompiler la version Lite si main_lite.ahk existe
    mainLiteAhk := A_ScriptDir "\main_lite.ahk"
    if FileExist(mainLiteAhk) {
        outLite := A_ScriptDir "\YouDlp-Dashboard-Lite.exe"
        cmdLine2 := """" ahkCompiler """ /in """ mainLiteAhk """ /out """ outLite """" iconParam binParam
        RunWait, %cmdLine2%, %A_ScriptDir%, Hide UseErrorLevel
    }

    ; 3. Mettre à jour le dossier Release/
    releaseDir := A_ScriptDir "\Release"
    IfExist, %releaseDir%
    {
        FileCopy, %A_ScriptDir%\YouDlp-Dashboard-Standalone.exe, %releaseDir%\YouDlp-Dashboard-Standalone.exe, 1
        FileCopy, %A_ScriptDir%\YouDlp-Dashboard-Lite.exe, %releaseDir%\YouDlp-Dashboard-Lite.exe, 1
        FileCopy, %A_ScriptDir%\YouDlp-Dashboard.exe, %releaseDir%\YouDlp-Dashboard.exe, 1
    }

    SafeTrayTip("YouDlp Dashboard", "Exécutables ré-empaquetés avec succès avec la nouvelle version !", 4, 1)
}

MenuReload:
    Reload
return

MenuExit:
    ExitApp
return

; Raccourci Historique (Ctrl + Alt + H)
^!h::ShowHistory()
