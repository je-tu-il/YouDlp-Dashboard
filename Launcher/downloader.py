import customtkinter as ctk
import socket
import threading
import subprocess
import os
import sys
import json
import time
import re
from datetime import datetime

# --- CONFIGURATION ---
HOST = '127.0.0.1'
PORT = 65432
HISTORY_FILE = "historique.txt"
SETTINGS_FILE = "settings.json"

# Chemins
PATH_PODCAST = r"D:\Reste\Podcast"
PATH_VIDEO = r"D:\Reste\Upload"

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("dark-blue")

class DownloadManagerApp(ctk.CTk):
    def __init__(self):
        super().__init__()

        # Configuration Fenêtre
        self.title("DL-Manager")
        self.geometry("600x400")
        self.resizable(False, False)
        
        # Positionnement en bas à droite
        self.screen_w = self.winfo_screenwidth()
        self.screen_h = self.winfo_screenheight()
        self.normal_geometry = f"600x400+{self.screen_w-620}+{self.screen_h-450}"
        self.mini_geometry = f"300x60+{self.screen_w-320}+{self.screen_h-100}"
        self.geometry(self.normal_geometry)

        # Variables d'état
        self.queue = [] # Liste des tâches
        self.is_mini = False
        self.last_interaction = time.time()
        self.custom_settings = self.load_settings()

        # UI Layout
        self.grid_columnconfigure(0, weight=1)
        self.grid_rowconfigure(1, weight=1)

        # 1. Header (Titres + Boutons)
        self.header_frame = ctk.CTkFrame(self, height=40, corner_radius=0)
        self.header_frame.grid(row=0, column=0, sticky="ew")
        
        self.lbl_title = ctk.CTkLabel(self.header_frame, text="DL Manager - Active Queue", font=("Roboto", 16, "bold"))
        self.lbl_title.pack(side="left", padx=10, pady=5)

        self.btn_history = ctk.CTkButton(self.header_frame, text="Historique", width=80, height=24, command=self.show_history)
        self.btn_history.pack(side="right", padx=10)

        # 2. Zone de Liste (Scrollable)
        self.scroll_frame = ctk.CTkScrollableFrame(self, label_text="Téléchargements en cours")
        self.scroll_frame.grid(row=1, column=0, sticky="nsew", padx=10, pady=5)

        # 3. Zone Custom (Cachée par défaut, visible en mode Custom)
        self.custom_frame = ctk.CTkFrame(self)
        self.custom_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=5)
        self.custom_frame.grid_remove() # Masquer au départ

        self.entry_custom_args = ctk.CTkEntry(self.custom_frame, placeholder_text="Arguments yt-dlp (ex: -f best...)")
        self.entry_custom_args.pack(fill="x", padx=5, pady=2)
        if "last_args" in self.custom_settings:
            self.entry_custom_args.insert(0, self.custom_settings["last_args"])

        self.entry_custom_path = ctk.CTkEntry(self.custom_frame, placeholder_text="Chemin de sortie")
        self.entry_custom_path.pack(fill="x", padx=5, pady=2)
        if "last_path" in self.custom_settings:
            self.entry_custom_path.insert(0, self.custom_settings["last_path"])

        self.btn_launch_custom = ctk.CTkButton(self.custom_frame, text="Lancer Custom", command=self.launch_custom_manual)
        self.btn_launch_custom.pack(pady=5)
        self.current_custom_url = ""

        # 4. Mode Mini (Overlay caché au départ)
        self.mini_frame = ctk.CTkFrame(self, fg_color="#1a1a1a")
        self.lbl_mini_status = ctk.CTkLabel(self.mini_frame, text="Inactif", text_color="gray")
        self.lbl_mini_status.pack(pady=(5,0))
        self.prog_mini = ctk.CTkProgressBar(self.mini_frame, width=250)
        self.prog_mini.pack(pady=5)
        self.prog_mini.set(0)
        
        # Event bindings
        self.bind("<Motion>", self.reset_timer)
        self.bind("<Button-1>", self.on_click_main)
        self.mini_frame.bind("<Button-1>", self.restore_ui)
        self.prog_mini.bind("<Button-1>", self.restore_ui)
        self.lbl_mini_status.bind("<Button-1>", self.restore_ui)

        # Démarrage Serveur & Timer
        self.start_socket_server()
        self.check_inactivity()
        self.protocol("WM_DELETE_WINDOW", self.minimize_to_tray) # Eviter fermeture accidentelle

    def minimize_to_tray(self):
        self.withdraw() # Cache simplement la fenêtre

    def restore_ui(self, event=None):
        self.deiconify()
        self.geometry(self.normal_geometry)
        self.mini_frame.grid_forget()
        self.header_frame.grid(row=0, column=0, sticky="ew")
        self.scroll_frame.grid(row=1, column=0, sticky="nsew")
        if self.custom_frame.winfo_viewable(): 
             self.custom_frame.grid(row=2, column=0, sticky="ew")
        self.is_mini = False
        self.reset_timer()

    def reset_timer(self, event=None):
        self.last_interaction = time.time()

    def check_inactivity(self):
        # Vérifie si inactif depuis 5s
        if not self.is_mini and (time.time() - self.last_interaction > 5):
            if len(self.queue) > 0: # Ne réduit que s'il y a de l'activité ou si on veut cacher
                self.go_mini_mode()
        
        self.after(1000, self.check_inactivity)

    def go_mini_mode(self):
        self.is_mini = True
        self.header_frame.grid_forget()
        self.scroll_frame.grid_forget()
        self.custom_frame.grid_remove()
        
        self.geometry(self.mini_geometry)
        self.mini_frame.grid(row=0, column=0, rowspan=3, sticky="nsew")
        self.update_mini_bar()

    def update_mini_bar(self):
        if not self.queue:
            self.lbl_mini_status.configure(text="En attente...")
            self.prog_mini.set(0)
            return
        
        # Calcul moyenne progression
        total = 0
        count = 0
        active = 0
        for task in self.queue:
            if task['status'] == 'downloading':
                total += task['progress']
                count += 1
                active += 1
        
        if count > 0:
            avg = total / count
            self.prog_mini.set(avg)
            self.lbl_mini_status.configure(text=f"Téléchargement ({active} en cours)")
        else:
            self.prog_mini.set(1) # Fini
            self.lbl_mini_status.configure(text="Terminé")

    def on_click_main(self, event):
        self.reset_timer()

    # --- LOGIQUE SOCKET ---
    def start_socket_server(self):
        thread = threading.Thread(target=self.socket_thread, daemon=True)
        thread.start()

    def socket_thread(self):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind((HOST, PORT))
                s.listen()
                while True:
                    conn, addr = s.accept()
                    with conn:
                        data = conn.recv(1024)
                        if data:
                            msg = data.decode('utf-8')
                            self.after(0, lambda m=msg: self.handle_command(m))
            except OSError:
                print("Socket déjà utilisé.")

    def handle_command(self, msg):
        parts = msg.split("|", 1)
        cmd = parts[0]
        url = parts[1] if len(parts) > 1 else ""

        self.restore_ui() # On réveille l'app

        if cmd == "SHOW":
            return
        
        # Vérif Doublons
        for task in self.queue:
            if task['url'] == url and task['status'] in ['pending', 'downloading']:
                print("Doublon ignoré")
                return

        if cmd == "PODCAST":
            self.add_task(url, "PODCAST")
        elif cmd == "VIDEO":
            self.add_task(url, "VIDEO")
        elif cmd == "CUSTOM":
            self.prepare_custom(url)

    # --- LOGIQUE TÉLÉCHARGEMENT ---
    def prepare_custom(self, url):
        self.custom_frame.grid(row=2, column=0, sticky="ew", padx=10, pady=5)
        self.current_custom_url = url
        # Focus pour inviter l'user à modifier
        self.entry_custom_args.focus_set()

    def launch_custom_manual(self):
        args = self.entry_custom_args.get()
        path = self.entry_custom_path.get()
        
        # Sauvegarde settings
        self.custom_settings["last_args"] = args
        self.custom_settings["last_path"] = path
        self.save_settings()
        
        self.custom_frame.grid_remove()
        self.add_task(self.current_custom_url, "CUSTOM", custom_args=args, custom_path=path)

    def add_task(self, url, mode, custom_args=None, custom_path=None):
        task_id = len(self.queue)
        
        # UI pour la tâche
        frame = ctk.CTkFrame(self.scroll_frame)
        frame.pack(fill="x", pady=2)
        
        lbl = ctk.CTkLabel(frame, text=f"[{mode}] {url[:40]}...", anchor="w")
        lbl.pack(side="top", fill="x", padx=5)
        
        prog = ctk.CTkProgressBar(frame, height=10)
        prog.pack(side="left", fill="x", expand=True, padx=5, pady=5)
        prog.set(0)
        
        status_lbl = ctk.CTkLabel(frame, text="Attente", width=60)
        status_lbl.pack(side="right", padx=5)

        task = {
            "id": task_id,
            "url": url,
            "mode": mode,
            "status": "pending",
            "progress": 0.0,
            "ui_prog": prog,
            "ui_lbl": status_lbl,
            "custom_args": custom_args,
            "custom_path": custom_path
        }
        self.queue.append(task)
        
        # Lancer le download dans un thread
        threading.Thread(target=self.run_ytdlp, args=(task,), daemon=True).start()

    def run_ytdlp(self, task):
        task['status'] = 'downloading'
        task['ui_lbl'].configure(text="0%", text_color="orange")
        self.update_mini_bar()

        # Construction de la commande
        cmd_base = ["yt-dlp", "--newline", "--no-colors"] # Essential for parsing
        
        output_template = ""
        args = []

        if task['mode'] == "PODCAST":
            path = os.path.join(PATH_PODCAST, "%(playlist)s", "%(title)s.%(ext)s")
            args = ["-x", "--audio-format", "mp3", "--audio-quality", "128k", 
                    "--extractor-args", "youtube:player-client=default,-tv_simply"]
            output_template = path

        elif task['mode'] == "VIDEO":
            path = os.path.join(PATH_VIDEO, "%(playlist)s", "%(title)s.%(ext)s")
            args = ["-f", "bestvideo[height<=720]+bestaudio[abr<=128]/best[height<=720]", 
                    "--merge-output-format", "mp4",
                    "--extractor-args", "youtube:player-client=default,-tv_simply"]
            output_template = path

        elif task['mode'] == "CUSTOM":
            path = os.path.join(task['custom_path'], "%(title)s.%(ext)s")
            # Split des arguments raw proprement
            import shlex
            raw_args = shlex.split(task['custom_args'])
            args = raw_args
            output_template = path

        final_cmd = cmd_base + args + ["-o", output_template, task['url']]
        
        # Exécution sans fenêtre console (CREATE_NO_WINDOW = 0x08000000)
        creation_flags = 0x08000000 if sys.platform == "win32" else 0
        
        process = subprocess.Popen(
            final_cmd, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.STDOUT, 
            universal_newlines=True,
            creationflags=creation_flags
        )

        for line in process.stdout:
            # Parsing de la progression
            match = re.search(r"(\d+\.\d+)%", line)
            if match:
                percent = float(match.group(1))
                val = percent / 100
                task['progress'] = val
                # Mise à jour UI thread-safe via after (ou direct CTk supporte bien)
                task['ui_prog'].set(val)
                task['ui_lbl'].configure(text=f"{int(percent)}%")
                self.after(0, self.update_mini_bar)

        process.wait()

        if process.returncode == 0:
            task['status'] = 'done'
            task['ui_lbl'].configure(text="OK", text_color="green")
            task['ui_prog'].set(1)
            self.log_history(task)
        else:
            task['status'] = 'error'
            task['ui_lbl'].configure(text="Erreur", text_color="red")
        
        self.after(0, self.update_mini_bar)

    # --- HISTOIRE & SETTINGS ---
    def log_history(self, task):
        date_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        try:
            with open(HISTORY_FILE, "a", encoding="utf-8") as f:
                f.write(f"{date_str} | {task['mode']} | {task['url']}\n")
        except:
            pass

    def show_history(self):
        if os.path.exists(HISTORY_FILE):
            os.startfile(HISTORY_FILE)
        else:
            print("Pas d'historique")

    def load_settings(self):
        if os.path.exists(SETTINGS_FILE):
            try:
                with open(SETTINGS_FILE, "r") as f:
                    return json.load(f)
            except:
                return {}
        return {}

    def save_settings(self):
        with open(SETTINGS_FILE, "w") as f:
            json.dump(self.custom_settings, f)

if __name__ == "__main__":
    app = DownloadManagerApp()
    app.mainloop()