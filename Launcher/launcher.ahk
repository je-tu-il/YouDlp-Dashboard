#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%

; --- Configuration ---
PythonScript := "downloader.py"
Port := 65432
Host := "127.0.0.1"

; --- Raccourcis ---

; AltGr + 8 : Podcast (MP3)
<^>!8::
    SendToPython("PODCAST", Clipboard)
return

; AltGr + 9 : Video (MP4)
<^>!9::
    SendToPython("VIDEO", Clipboard)
return

; AltGr + 0 : Custom (Menu)
<^>!0::
    SendToPython("CUSTOM", Clipboard)
return

; AltGr + = : Afficher l'interface
<^>!=::
    SendToPython("SHOW", "")
return

; --- Fonction de Communication ---
SendToPython(Command, Url) {
    global PythonScript, Port, Host
    
    ; 1. Essayer de se connecter
    socket := ConnectToSocket(Host, Port)
    
    ; 2. Si échec (Python fermé), on lance le script
    if (socket = -1) {
        ; Lance pythonw (sans console)
        Run, pythonw.exe "%PythonScript%", %A_ScriptDir%, Hide
        
        ; On attend un peu que l'interface démarre
        Sleep, 1500
        
        ; On réessaie
        socket := ConnectToSocket(Host, Port)
        if (socket = -1) {
            MsgBox, 16, Erreur, Impossible de lancer ou connecter le script Python.
            return
        }
    }
    
    ; 3. Envoyer la donnée (Format: COMMAND|URL)
    StringToSend := Command . "|" . Url
    SendData(socket, StringToSend)
    
    ; 4. Fermer connexion
    DllCall("Ws2_32\closesocket", "UInt", socket)
    DllCall("Ws2_32\WSACleanup")
}

; --- Helpers Winsock pour AHK v1.1 ---
ConnectToSocket(IP, Port) {
    ; Initialisation Winsock
    VarSetCapacity(wsaData, 400)
    Result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", &wsaData)
    if (Result)
        return -1
    
    ; Création Socket
    socket := DllCall("Ws2_32\socket", "Int", 2, "Int", 1, "Int", 6) ; AF_INET, SOCK_STREAM, TCP
    if (socket = -1)
        return -1
    
    ; Structure SockAddr
    VarSetCapacity(SockAddr, 16)
    NumPut(2, SockAddr, 0, "Short") ; AF_INET
    NumPut(DllCall("Ws2_32\htons", "UShort", Port), SockAddr, 2, "UShort") ; Port
    NumPut(DllCall("Ws2_32\inet_addr", "AStr", IP), SockAddr, 4, "UInt") ; IP
    
    ; Connexion
    if (DllCall("Ws2_32\connect", "UInt", socket, "Ptr", &SockAddr, "Int", 16)) {
        DllCall("Ws2_32\closesocket", "UInt", socket)
        return -1
    }
    return socket
}

SendData(socket, string) {
    VarSetCapacity(buffer, StrLen(string), 0)
    StrPut(string, &buffer, "UTF-8")
    DllCall("Ws2_32\send", "UInt", socket, "Ptr", &buffer, "Int", StrLen(string), "Int", 0)
}