#NoEnv
#SingleInstance Force
#Persistent
SetWorkingDir %A_ScriptDir%
FileEncoding, UTF-8
#Include %A_ScriptDir%\lib\Socket.ahk

; ---------------------------------------------------------
; VARIABLES GLOBALES
; ---------------------------------------------------------
global ClipboardURL := ""
global CurrentDownloadURL := ""
global CurrentDownloadType := ""

IfNotExist, %A_ScriptDir%\db
    FileCreateDir, %A_ScriptDir%\db

; Encapsulation du HTML pour la compilation
FileInstall, www\history.html, %A_Temp%\youdlp_history.html, 1

global Server := new HttpServer()
Server.Bind(["0.0.0.0", 9000])
Server.Listen()

; Démarrer le worker de téléchargement en arrière-plan
SetTimer, ProcessQueue, 5000

; ---------------------------------------------------------
; SURVEILLANCE PRESSE-PAPIER
; ---------------------------------------------------------
OnClipboardChange("ClipChanged")
global ClipboardURL := ""

ClipChanged(Type) {
    if (Type = 1) {
        clip := Clipboard
        if (InStr(clip, "youtube.com/watch") || InStr(clip, "youtu.be/") || InStr(clip, "youtube.com/shorts/")) {
            ClipboardURL := clip
            ShowGUI()
        }
    }
}

ShowGUI() {
    global hGui, ClipboardURL
    
    vidTitle := ClipboardURL
    try {
        req := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(2000, 2000, 2000, 2000)
        req.Open("GET", "https://www.youtube.com/oembed?url=" . ClipboardURL . "&format=json", false)
        req.Send()
        if (RegExMatch(req.ResponseText, """title"":\s*""(.*?)""", match)) {
            vidTitle := match1
            vidTitle := StrReplace(vidTitle, "\""", """")
        }
    } catch {
        ; Ignore network errors
    }
    
    videoTitle := vidTitle
    if (StrLen(videoTitle) > 60)
        videoTitle := SubStr(videoTitle, 1, 57) . "..."
        
    Gui, Main:Destroy
    Gui, Main:New, +AlwaysOnTop -Caption +ToolWindow +Border +HWNDhGui
    Gui, Main:Color, 202225
    Gui, Main:Margin, 20, 20
    
    Gui, Main:Font, s16 c00A8E8 bold, Segoe UI
    Gui, Main:Add, Text, w500 Center, 🎬 YouTube Downloader
    
    Gui, Main:Font, s12 cFFFFFF norm, Segoe UI
    Gui, Main:Add, Text, w500 Center, %videoTitle%
    
    Gui, Main:Add, Text, w500 h2 0x10 ; Horizontal line separator
    
    Gui, Main:Font, s14 c43B581 bold, Segoe UI
    Gui, Main:Add, Text, w240 x20 y+15 Center, 🡄 MP4 (Vidéo)
    
    Gui, Main:Font, s14 cF04747 bold, Segoe UI
    Gui, Main:Add, Text, w240 x260 yp Center, MP3 (Audio) 🡆
    
    Gui, Main:Font, s10 c72767D norm, Segoe UI
    Gui, Main:Add, Text, w500 x20 y+20 Center, (Appuyez sur Echap pour ignorer)
    
    Gui, Main:Show, NoActivate xCenter y40, YT Downloader Popup
    
    Hotkey, IfWinExist, ahk_id %hGui%
    Hotkey, Left, AddMP4, On
    Hotkey, Right, AddMP3, On
    Hotkey, Escape, CloseGUI, On
    Hotkey, If
}

AddMP4:
    FileAppend, %ClipboardURL%|mp4`n, %A_ScriptDir%\db\queue.txt
    GoSub, CloseGUI
return

AddMP3:
    FileAppend, %ClipboardURL%|mp3`n, %A_ScriptDir%\db\queue.txt
    GoSub, CloseGUI
return

CloseGUI:
    Gui, Main:Destroy
    Hotkey, IfWinExist, ahk_id %hGui%
    Hotkey, Left, Off, UseErrorLevel
    Hotkey, Right, Off, UseErrorLevel
    Hotkey, Escape, Off, UseErrorLevel
    Hotkey, If
return

; ---------------------------------------------------------
; WORKER DE TELECHARGEMENT
; ---------------------------------------------------------
ProcessQueue:
    SetTimer, ProcessQueue, Off
    
    global currentDownloadPID
    if (currentDownloadPID != 0 && currentDownloadPID != "") {
        Process, Exist, %currentDownloadPID%
        if (!ErrorLevel) {
            ; Process is done
            
            errLog := A_ScriptDir "\db\last_error.txt"
            if FileExist(errLog) {
                FileRead, errOutput, %errLog%
                if (InStr(errOutput, "ERROR:")) {
                    cleanOutput := StrReplace(errOutput, "`r`n", " ")
                    cleanOutput := StrReplace(cleanOutput, "`n", " ")
                    ; Extract video ID from URL if possible for thumbnail
                    RegExMatch(CurrentDownloadURL, "v=([^&]+)", vMatch)
                    vid := vMatch1 ? vMatch1 : CurrentDownloadURL
                    FileAppend, %vid%|||%CurrentDownloadType%|||%cleanOutput%`n, %A_ScriptDir%\db\errors.txt
                }
            }
            
            currentDownloadPID := 0
            CurrentDownloadURL := ""
            CurrentDownloadType := ""
        } else {
            SetTimer, ProcessQueue, 5000
            return
        }
    }
    
    if !FileExist(A_ScriptDir "\db\queue.txt") {
        SetTimer, ProcessQueue, 5000
        return
    }
    
    FileAppend, [Debug] Queue trouvee`n, %A_ScriptDir%\db\debug.log
    
    firstLine := ""
    remaining := ""
    
    Loop, Read, %A_ScriptDir%\db\queue.txt
    {
        if (A_Index = 1)
            firstLine := A_LoopReadLine
        else if (A_LoopReadLine != "")
            remaining .= A_LoopReadLine "`n"
    }
    
    FileAppend, [Debug] firstLine: %firstLine%`n, %A_ScriptDir%\db\debug.log
    
    if (firstLine = "") {
        FileDelete, %A_ScriptDir%\db\queue.txt
        SetTimer, ProcessQueue, 5000
        return
    }
    
    FileDelete, %A_ScriptDir%\db\queue.txt
    if (remaining != "")
        FileAppend, %remaining%, %A_ScriptDir%\db\queue.txt
        
    parts := StrSplit(firstLine, "|")
    url := parts[1]
    type := parts[2]
    
    FileAppend, [Debug] URL a traiter: %url% Type: %type%`n, %A_ScriptDir%\db\debug.log
    
    if (url != "") {
        CurrentDownloadURL := url
        CurrentDownloadType := type
            
        histFile := A_ScriptDir "\db\history.txt"
        
        errLog := A_ScriptDir "\db\last_error.txt"
        FileDelete, %errLog%
        
        if (type = "mp3") {
            cmd := "yt-dlp -f ""bestaudio[language=fr]/bestaudio/best"" -x --audio-format mp3 --audio-quality 128k -P ""home:E:\Reste\Podcast"" -o ""%(title)s.%(ext)s"" --retries infinite --fragment-retries infinite --sponsorblock-remove sponsor --no-warnings --extractor-args ""youtube:player_client=android,web"" --postprocessor-args ""ffmpeg:-avoid_negative_ts make_zero"" --print-to-file ""after_move:%(title)s|||%(filepath)s|||%(id)s|||mp3"" """ histFile """ """ url """ 2> """ errLog """"
        } else {
            cmd := "yt-dlp -f ""bestvideo[height<=720][ext=mp4]+bestaudio[language^=fr][ext=m4a]/bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]/best[height<=720][ext=mp4]/best"" --merge-output-format mp4 -P ""home:E:\Reste\Upload"" -o ""%(title)s.%(ext)s"" --retries infinite --fragment-retries infinite --sponsorblock-remove sponsor --no-warnings --extractor-args ""youtube:player_client=android,web"" --print-to-file ""after_move:%(title)s|||%(filepath)s|||%(id)s|||mp4"" """ histFile """ """ url """ 2> """ errLog """"
        }
        
        FileAppend, [Debug] Execution cmd: %cmd%`n, %A_ScriptDir%\db\debug.log
        Run, %ComSpec% /c "%cmd%", %A_ScriptDir%, Hide UseErrorLevel, currentDownloadPID
        
    }
    
    SetTimer, ProcessQueue, 5000
return

; ---------------------------------------------------------
; INTERFACE D'HISTORIQUE (WEB)
; ---------------------------------------------------------
ShowHistory() {
    Run, http://localhost:9000/history
}

PlayHistory:
    RowNumber := LV_GetNext(0)
    if (RowNumber) {
        LV_GetText(path, RowNumber, 3)
        Run, "%path%"
    }
return

FolderHistory:
    RowNumber := LV_GetNext(0)
    if (RowNumber) {
        LV_GetText(path, RowNumber, 3)
        Run, % "explorer.exe /select,""" path """"
    }
return

class HttpServer extends SocketTCP {
    OnAccept() {
        client := this.Accept()
        client.base := this.base
        client.EventProcRegister(this.FD_READ | this.FD_CLOSE)
    }
    OnRecv() {
        try {
            request := this.RecvText()
            
            ; Wait for full body if it's a POST request
            if (RegExMatch(request, "i)Content-Length:\s*(\d+)", lenMatch)) {
                contentLen := lenMatch1
                RegExMatch(request, "s)\r\n\r\n(.*)$", bodyMatch)
                bodyLen := StrLen(bodyMatch1)
                
                startWait := A_TickCount
                while (bodyLen < contentLen && (A_TickCount - startWait) < 2000) {
                    Sleep, 10
                    extra := this.RecvText()
                    if (extra != "") {
                        request .= extra
                        bodyLen += StrLen(extra)
                    }
                }
            }
            
            FileAppend, [Debug] Requete recue: %request%`n, %A_ScriptDir%\db\debug.log
            if (RegExMatch(request, "s)^GET ([^\s]+)", match)) {
                path := match1
                queryPos := InStr(path, "?")
                if (queryPos > 0)
                    path := SubStr(path, 1, queryPos - 1)
                FileAppend, [Debug] Path detecte: %path%`n, %A_ScriptDir%\db\debug.log
                if (path = "/history" || path = "/") {
                    htmlPath := A_IsCompiled ? A_Temp "\youdlp_history.html" : A_ScriptDir "\www\history.html"
                    FileRead, html, %htmlPath%
                    len := StrPut(html, "UTF-8") - 1
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nCache-Control: no-store, no-cache, must-revalidate, max-age=0`r`nContent-Type: text/html; charset=UTF-8`r`nContent-Length: " len "`r`n`r`n" html)
                } else if (path = "/api/data") {
                    json := "["
                    global CurrentDownloadURL, CurrentDownloadType
                    
                    favIds := {}
                    If FileExist(A_ScriptDir "\db\favorites.ini") {
                        IniRead, favKeys, %A_ScriptDir%\db\favorites.ini, Favorites
                        Loop, Parse, favKeys, `n, `r
                        {
                            parts := StrSplit(A_LoopField, "=")
                            if (parts[1] != "")
                                favIds[parts[1]] := true
                        }
                    }
                    
                    if (CurrentDownloadURL != "") {
                        json .= "{""statut"":""En cours"",""url"":""" CurrentDownloadURL """,""format"":""" CurrentDownloadType """,""title"":""" CurrentDownloadURL """},"
                    }
                    If FileExist(A_ScriptDir "\db\queue.txt") {
                        Loop, Read, %A_ScriptDir%\db\queue.txt
                        {
                            if (A_LoopReadLine = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|")
                            if (parts.MaxIndex() >= 2) {
                                cleanUrl := StrReplace(parts[1], "\", "\\")
                                json .= "{""statut"":""En attente"",""url"":""" cleanUrl """,""format"":""" parts[2] """,""title"":""" cleanUrl """},"
                            }
                        }
                    }
                    If FileExist(A_ScriptDir "\db\history.txt") {
                        lastOccurrences := {}
                        lineNum := 0
                        Loop, Read, %A_ScriptDir%\db\history.txt
                        {
                            lineNum++
                            if (A_LoopReadLine = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|||")
                            if (parts.MaxIndex() >= 4) {
                                key := parts[3] . "_" . parts[4]
                                lastOccurrences[key] := lineNum
                            }
                        }
                        
                        lineNum := 0
                        Loop, Read, %A_ScriptDir%\db\history.txt
                        {
                            lineNum++
                            if (A_LoopReadLine = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|||")
                            if (parts.MaxIndex() >= 4) {
                                key := parts[3] . "_" . parts[4]
                                if (lastOccurrences[key] != lineNum)
                                    continue
                                    
                                title := StrReplace(parts[1], "\", "\\")
                                title := StrReplace(title, """", "\""")
                                pathFile := StrReplace(parts[2], "\", "\\")
                                pathFile := StrReplace(pathFile, """", "\""")
                                id := StrReplace(parts[3], """", "\""")
                                format := StrReplace(parts[4], """", "\""")
                                isFav := favIds[id] ? "true" : "false"
                                json .= "{""statut"":""Termine"",""title"":""" title """,""path"":""" pathFile """,""id"":""" id """,""format"":""" format """,""fav"":" isFav "},"
                            }
                        }
                    }
                    If FileExist(A_ScriptDir "\db\errors.txt") {
                        Loop, Read, %A_ScriptDir%\db\errors.txt
                        {
                            if (A_LoopReadLine = "")
                                continue
                            parts := StrSplit(A_LoopReadLine, "|||")
                            if (parts.MaxIndex() >= 3) {
                                id := StrReplace(parts[1], """", "\""")
                                format := StrReplace(parts[2], """", "\""")
                                errTxt := StrReplace(parts[3], "\", "\\")
                                errTxt := StrReplace(errTxt, """", "\""")
                                json .= "{""statut"":""Erreur"",""id"":""" id """,""format"":""" format """,""title"":""Erreur lors du téléchargement"",""error"":""" errTxt """},"
                            }
                        }
                    }
                    if (SubStr(json, 0) = ",")
                        json := SubStr(json, 1, StrLen(json) - 1)
                    json .= "]"
                    len := StrPut(json, "UTF-8") - 1
                    this.SendText("HTTP/1.1 200 OK`r`nConnection: close`r`nCache-Control: no-store, no-cache, must-revalidate, max-age=0`r`nContent-Type: application/json; charset=UTF-8`r`nContent-Length: " len "`r`n`r`n" json)
                } else {
                    this.SendText("HTTP/1.1 404 Not Found`r`nConnection: close`r`nContent-Length: 0`r`n`r`n")
                }
            } else if (RegExMatch(request, "s)^POST ([^\s]+).*?\r\n\r\n(.*)", match)) {
                path := match1
                body := match2
                if (path = "/api/action") {
                    RegExMatch(body, """action""\s*:\s*""([^""]+)""", actionMatch)
                    RegExMatch(body, """target""\s*:\s*""([^""]*)""", targetMatch)
                    action := actionMatch1
                    target := targetMatch1
                    
                    if (action = "stop") {
                        Process, Close, yt-dlp.exe
                    } else if (action = "clear_history") {
                        FileDelete, %A_ScriptDir%\db\history.txt
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
                            if (A_LoopReadLine = "")
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
                            if (A_LoopReadLine = "")
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
                        FileAppend, %newQueue%, %A_ScriptDir%\db\queue.txt
                    }
                    this.SendText("HTTP/1.1 200 OK`r`nContent-Length: 2`r`n`r`nOK")
                } else if (path = "/") {
                    RegExMatch(body, """action""\s*:\s*""([^""]+)""", actionMatch)
                    RegExMatch(body, """url""\s*:\s*""([^""]+)""", urlMatch)
                    RegExMatch(body, """type""\s*:\s*""([^""]+)""", typeMatch)
                    action := actionMatch1
                    url := urlMatch1
                    type := typeMatch1
                    
                    if (action = "add" && url != "") {
                        FileAppend, %url%|%type%`n, %A_ScriptDir%\db\queue.txt
                        TrayTip, YouTube Downloader, %url% ajoute (%type%), 2, 1
                    } 
                    this.SendText("HTTP/1.1 200 OK`r`nAccess-Control-Allow-Origin: *`r`nContent-Length: 2`r`n`r`nOK")
                }
            }
            this.Disconnect()
        } catch e {
            FileAppend, % "[Error] Line: " e.Line " | Message: " e.Message " | What: " e.What " | Extra: " e.Extra "`n", %A_ScriptDir%\db\debug.log
            this.Disconnect()
        }
    }
}


; Raccourci Historique (Ctrl + Alt + H)
^!h::ShowHistory()

