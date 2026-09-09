#!/usr/bin/env python3
"""omarchy-rdp GTK 4 / Libadwaita Graphical User Interface.

Provides a modern Wayland desktop frontend for managing RDP profiles,
launching FreeRDP sessions, and storing credentials in Secret Service.
"""

import json
import os
import shutil
import subprocess
import sys
import threading
import time
from typing import Any, Callable, Dict, List, Optional

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")
from gi.repository import Adw, Gdk, Gio, GLib, Gtk


DEFAULT_CONFIG_DIR = os.path.expanduser(
    os.environ.get("XDG_CONFIG_HOME", "~/.config") + "/omarchy-rdp"
)


class KeyringManager:
    """Interacts with the Linux Secret Service Keyring using secret-tool."""

    SERVICE = "omarchy-rdp"

    @classmethod
    def get_password(cls, profile_name: str) -> Optional[str]:
        if not profile_name:
            return None
        try:
            res = subprocess.run(
                ["secret-tool", "lookup", "service", cls.SERVICE, "profile", profile_name],
                capture_output=True,
                text=True,
                check=False,
            )
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.rstrip("\r\n")
            return None
        except OSError:
            return None

    @classmethod
    def set_password(cls, profile_name: str, password: str) -> bool:
        if not profile_name:
            return False
        try:
            res = subprocess.run(
                [
                    "secret-tool",
                    "store",
                    f"--label=omarchy-rdp: {profile_name}",
                    "service",
                    cls.SERVICE,
                    "profile",
                    profile_name,
                ],
                input=password,
                text=True,
                capture_output=True,
                check=False,
            )
            return res.returncode == 0
        except OSError:
            return False

    @classmethod
    def delete_password(cls, profile_name: str) -> bool:
        if not profile_name:
            return False
        try:
            res = subprocess.run(
                ["secret-tool", "clear", "service", cls.SERVICE, "profile", profile_name],
                capture_output=True,
                text=True,
                check=False,
            )
            return res.returncode == 0
        except OSError:
            return False

    @classmethod
    def has_password(cls, profile_name: str) -> bool:
        pwd = cls.get_password(profile_name)
        return bool(pwd)

    # Domain vocabulary aliases
    get_credential = get_password
    set_credential = set_password
    delete_credential = delete_password
    has_credential = has_password


class ProfileManager:
    """Handles loading, querying, and updating RDP profiles from profiles.json."""

    def __init__(self, config_dir: Optional[str] = None):
        self.config_dir = os.path.abspath(config_dir or DEFAULT_CONFIG_DIR)
        self.profiles_file = os.path.join(self.config_dir, "profiles.json")

    def list_profiles(self) -> List[Dict[str, Any]]:
        if not os.path.exists(self.profiles_file):
            return []
        try:
            with open(self.profiles_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    return data
                return []
        except (json.JSONDecodeError, OSError):
            return []

    def get_profile(self, name: str) -> Optional[Dict[str, Any]]:
        for p in self.list_profiles():
            if p.get("name") == name:
                return p
        return None

    def filter_profiles(self, query: str) -> List[Dict[str, Any]]:
        query_norm = (query or "").strip().lower()
        if not query_norm:
            return self.list_profiles()

        matched = []
        for p in self.list_profiles():
            name = (p.get("name") or "").lower()
            host = (p.get("host") or "").lower()
            user = (p.get("username") or "").lower()
            domain = (p.get("domain") or "").lower()
            if (
                query_norm in name
                or query_norm in host
                or query_norm in user
                or query_norm in domain
            ):
                matched.append(p)
        return matched

    def save_profile(self, profile: Dict[str, Any]) -> None:
        os.makedirs(self.config_dir, exist_ok=True)
        # Deep copy & sanitize: never store password in profiles.json
        clean_profile = dict(profile)
        clean_profile.pop("password", None)
        if not clean_profile.get("port"):
            clean_profile["port"] = 3389
        else:
            try:
                clean_profile["port"] = int(clean_profile["port"])
            except (ValueError, TypeError):
                clean_profile["port"] = 3389

        # Ensure boolean defaults
        for key in ("sound", "clipboard", "dynamic_resolution", "ignore_cert"):
            if key not in clean_profile:
                clean_profile[key] = True
        if "microphone" not in clean_profile:
            clean_profile["microphone"] = False

        profiles = self.list_profiles()
        name = clean_profile.get("name")
        updated = False
        for i, existing in enumerate(profiles):
            if existing.get("name") == name:
                profiles[i] = clean_profile
                updated = True
                break
        if not updated:
            profiles.append(clean_profile)

        tmp_file = self.profiles_file + ".tmp"
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(profiles, f, indent=2)
            f.write("\n")
        os.replace(tmp_file, self.profiles_file)

    def delete_profile(self, name: str) -> bool:
        profiles = self.list_profiles()
        filtered = [p for p in profiles if p.get("name") != name]
        if len(filtered) == len(profiles):
            return False

        os.makedirs(self.config_dir, exist_ok=True)
        tmp_file = self.profiles_file + ".tmp"
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(filtered, f, indent=2)
            f.write("\n")
        os.replace(tmp_file, self.profiles_file)
        return True


class RunningSession:
    """Represents an active FreeRDP 3 process."""

    def __init__(self, profile_name: str, proc: subprocess.Popen, start_time: float):
        self.profile_name = profile_name
        self.proc = proc
        self.start_time = start_time
        self.user_stopped = False


class SessionManager:
    """Manages active FreeRDP sessions, arguments building, and lifecycle."""

    def __init__(self, config_dir: Optional[str] = None):
        self.config_dir = os.path.abspath(config_dir or DEFAULT_CONFIG_DIR)
        self.active_sessions: Dict[str, RunningSession] = {}

    def is_active(self, profile_name: str) -> bool:
        session = self.active_sessions.get(profile_name)
        if not session:
            return False
        if session.proc.poll() is not None:
            return False
        return True

    def detect_display_scale(self) -> Optional[str]:
        if not shutil.which("hyprctl"):
            return None
        try:
            res = subprocess.run(
                ["hyprctl", "monitors", "-j"],
                capture_output=True,
                text=True,
                check=False,
            )
            if res.returncode == 0 and res.stdout:
                monitors = json.loads(res.stdout)
                for mon in monitors:
                    if mon.get("focused"):
                        scale = float(mon.get("scale", 1.0))
                        scale_pct = int(scale * 100)
                        if scale_pct >= 170:
                            return "/scale:180"
                        elif scale_pct >= 130:
                            return "/scale:140"
        except (OSError, ValueError, json.JSONDecodeError):
            pass
        return None

    def setup_krb5(self) -> str:
        krb5_dir = os.path.join(self.config_dir, "krb5")
        krb5_conf = os.path.join(krb5_dir, "krb5.conf")
        os.makedirs(krb5_dir, exist_ok=True)
        if not os.path.exists(krb5_conf):
            with open(krb5_conf, "w", encoding="utf-8") as f:
                f.write("[libdefaults]\n  dns_lookup_kdc = false\n  dns_lookup_realm = false\n")
        return krb5_conf

    def build_rdp_args(
        self,
        profile: Dict[str, Any],
        credential: Optional[str] = None,
        mask_secrets: bool = False,
    ) -> List[str]:
        host = profile.get("host") or ""
        port = profile.get("port") or 3389
        user = profile.get("username") or ""
        domain = profile.get("domain") or ""
        sound = profile.get("sound", True)
        microphone = profile.get("microphone", False)
        clipboard = profile.get("clipboard", True)
        dynamic_res = profile.get("dynamic_resolution", True)
        ignore_cert = profile.get("ignore_cert", True)
        share_path = profile.get("share_path") or ""

        args = [f"/v:{host}:{port}", f"/u:{user}"]

        if dynamic_res:
            args.append("/dynamic-resolution")
        if ignore_cert:
            args.append("/cert:ignore")
        if clipboard:
            args.append("/clipboard")
        if sound:
            args.append("/sound")
        if microphone:
            args.append("/microphone")
        if share_path and os.path.isdir(share_path):
            args.append(f"/drive:shared,{share_path}")

        scale_flag = self.detect_display_scale()
        if scale_flag:
            args.append(scale_flag)

        if domain:
            args.append(f"/d:{domain}")

        if credential:
            if mask_secrets:
                args.append("/p:********")
            else:
                args.append(f"/p:{credential}")

        return args

    def notify_error(self, message: str) -> None:
        try:
            if shutil.which("omarchy-notification-send"):
                subprocess.run(
                    ["omarchy-notification-send", "-u", "critical", "omarchy-rdp", message],
                    check=False,
                )
            elif shutil.which("notify-send"):
                subprocess.run(
                    ["notify-send", "-u", "critical", "omarchy-rdp", message],
                    check=False,
                )
        except OSError:
            pass

    def start_session(
        self,
        profile: Dict[str, Any],
        credential: Optional[str] = None,
        on_exit: Optional[Callable[[str, int, float], None]] = None,
    ) -> bool:
        name = profile.get("name")
        if not name or self.is_active(name):
            return False

        krb5_conf = self.setup_krb5()
        env = os.environ.copy()
        env["KRB5_CONFIG"] = krb5_conf

        args = self.build_rdp_args(profile, credential=credential, mask_secrets=False)
        payload = ("\n".join(args) + "\n").encode("utf-8")

        r_fd, w_fd = os.pipe()
        try:
            with open(w_fd, "wb") as f:
                f.write(payload)
        except OSError:
            os.close(r_fd)
            return False

        def preexec():
            if r_fd != 3:
                os.dup2(r_fd, 3)

        try:
            proc = subprocess.Popen(
                ["xfreerdp3", "/args-from:fd:3"],
                pass_fds=(r_fd,),
                preexec_fn=preexec,
                env=env,
            )
        except OSError as e:
            os.close(r_fd)
            self.notify_error(f"Impossible de lancer FreeRDP 3 pour '{name}': {e}")
            return False
        finally:
            try:
                os.close(r_fd)
            except OSError:
                pass

        session = RunningSession(name, proc, time.time())
        self.active_sessions[name] = session

        def monitor():
            proc.wait()
            end_time = time.time()
            duration = end_time - session.start_time
            returncode = proc.returncode

            if not session.user_stopped and (returncode != 0 or duration < 3):
                msg = f"La session '{name}' s'est fermée anormalement (durée: {int(duration)}s, code: {returncode})."
                self.notify_error(msg)

            if name in self.active_sessions and self.active_sessions[name] is session:
                del self.active_sessions[name]

            if on_exit:
                GLib.idle_add(on_exit, name, returncode, duration)

        t = threading.Thread(target=monitor, daemon=True)
        t.start()
        return True

    def stop_session(self, profile_name: str) -> bool:
        session = self.active_sessions.get(profile_name)
        if not session:
            return False
        session.user_stopped = True
        try:
            session.proc.terminate()
            return True
        except OSError:
            return False


class PasswordDialog(Adw.MessageDialog):
    """Modal dialog prompting for missing RDP credentials."""

    def __init__(
        self,
        parent: Gtk.Window,
        profile_name: str,
        username: str,
        on_connect: Callable[[str, bool], None],
    ):
        super().__init__(
            transient_for=parent,
            heading="Authentification RDP",
            body=f"Veuillez saisir le mot de passe Windows pour « {username or profile_name} ».",
        )
        self.on_connect = on_connect
        self.profile_name = profile_name

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(12)
        box.set_margin_bottom(12)

        self.password_entry = Gtk.PasswordEntry()
        self.password_entry.set_placeholder_text("Mot de passe")
        self.password_entry.set_show_peek_icon(True)
        self.password_entry.connect("activate", self._on_submit)
        box.append(self.password_entry)

        self.remember_switch = Gtk.CheckButton(
            label="Mémoriser ce mot de passe dans le trousseau de clés"
        )
        self.remember_switch.set_active(True)
        box.append(self.remember_switch)

        self.set_extra_child(box)

        self.add_response("cancel", "Annuler")
        self.add_response("connect", "Se connecter")
        self.set_response_appearance("connect", Adw.ResponseAppearance.SUGGESTED)
        self.set_default_response("connect")
        self.set_close_response("cancel")

        self.connect("response", self._on_response)

    def _on_submit(self, _entry: Any) -> None:
        self.response("connect")

    def _on_response(self, _dialog: Any, response: str) -> None:
        if response == "connect":
            pwd = self.password_entry.get_text()
            remember = self.remember_switch.get_active()
            self.on_connect(pwd, remember)


class CredentialDialog(Adw.MessageDialog):
    """Modal dialog for managing a profile's stored credential in Secret Service."""

    def __init__(
        self,
        parent: Gtk.Window,
        profile_name: str,
        on_updated: Optional[Callable[[], None]] = None,
    ):
        has_stored = KeyringManager.has_credential(profile_name)
        status_text = (
            "Un credential est actuellement enregistré pour ce profil dans Secret Service."
            if has_stored
            else "Aucun credential n'est enregistré pour ce profil."
        )
        super().__init__(
            transient_for=parent,
            heading="Gérer le credential",
            body=f"Profil : {profile_name}\n{status_text}",
        )
        self.profile_name = profile_name
        self.on_updated = on_updated

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(12)
        box.set_margin_bottom(12)

        self.password_entry = Gtk.PasswordEntry()
        self.password_entry.set_placeholder_text("Nouveau mot de passe / credential")
        self.password_entry.set_show_peek_icon(True)
        box.append(self.password_entry)

        self.set_extra_child(box)

        self.add_response("cancel", "Fermer")
        if has_stored:
            self.add_response("clear", "Supprimer du trousseau")
            self.set_response_appearance("clear", Adw.ResponseAppearance.DESTRUCTIVE)
        self.add_response("save", "Enregistrer")
        self.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED)
        self.set_default_response("save")
        self.set_close_response("cancel")

        self.connect("response", self._on_response)

    def _on_response(self, _dialog: Any, response: str) -> None:
        if response == "save":
            pwd = self.password_entry.get_text()
            if pwd:
                KeyringManager.set_credential(self.profile_name, pwd)
                if self.on_updated:
                    self.on_updated()
        elif response == "clear":
            KeyringManager.delete_credential(self.profile_name)
            if self.on_updated:
                self.on_updated()


class DeleteConfirmDialog(Adw.MessageDialog):
    """Confirmation modal for profile deletion."""

    def __init__(
        self,
        parent: Gtk.Window,
        profile_name: str,
        on_confirm: Callable[[str], None],
    ):
        super().__init__(
            transient_for=parent,
            heading="Supprimer le profil ?",
            body=f"Voulez-vous vraiment supprimer le profil « {profile_name} » ?\nCette action supprimera également le secret associé du trousseau.",
        )
        self.profile_name = profile_name
        self.on_confirm = on_confirm

        self.add_response("cancel", "Annuler")
        self.add_response("delete", "Supprimer")
        self.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE)
        self.set_default_response("cancel")
        self.set_close_response("cancel")

        self.connect("response", self._on_response)

    def _on_response(self, _dialog: Any, response: str) -> None:
        if response == "delete":
            self.on_confirm(self.profile_name)


class ProfileFormDialog(Adw.PreferencesWindow):
    """Modal preferences dialog for creating or editing an RDP profile."""

    def __init__(
        self,
        parent: Gtk.Window,
        profile_manager: ProfileManager,
        profile: Optional[Dict[str, Any]] = None,
        on_saved: Optional[Callable[[Dict[str, Any]], None]] = None,
    ):
        super().__init__(transient_for=parent, modal=True)
        self.profile_manager = profile_manager
        self.profile = profile
        self.is_edit = profile is not None
        self.on_saved = on_saved

        title = "Modifier le profil" if self.is_edit else "Nouveau profil RDP"
        self.set_title(title)
        self.set_default_size(580, 620)

        self._build_form()

        # Keyboard controller for Escape dismissal
        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self._on_key_pressed)
        self.add_controller(key_controller)

    def _on_key_pressed(
        self,
        _controller: Gtk.EventControllerKey,
        keyval: int,
        _keycode: int,
        _state: Gdk.ModifierType,
    ) -> bool:
        if keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False

    def _build_form(self) -> None:
        page = Adw.PreferencesPage()
        self.add(page)

        # 1. General Connection Group
        conn_group = Adw.PreferencesGroup(title="Connexion", description="Paramètres d'accès réseau")
        page.add(conn_group)

        # Name row
        self.name_row = Adw.EntryRow(title="Nom du profil *")
        if self.profile:
            self.name_row.set_text(self.profile.get("name", ""))
            self.name_row.set_sensitive(False)
        conn_group.add(self.name_row)

        # Host row
        self.host_row = Adw.EntryRow(title="Hôte / Adresse IP *")
        if self.profile:
            self.host_row.set_text(self.profile.get("host", ""))
        conn_group.add(self.host_row)

        # Port row
        self.port_row = Adw.SpinRow.new_with_range(1, 65535, 1)
        self.port_row.set_title("Port RDP")
        self.port_row.set_value(float(self.profile.get("port", 3389) if self.profile else 3389))
        conn_group.add(self.port_row)

        # User row
        self.user_row = Adw.EntryRow(title="Nom d'utilisateur")
        if self.profile:
            self.user_row.set_text(self.profile.get("username", ""))
        conn_group.add(self.user_row)

        # Domain row
        self.domain_row = Adw.EntryRow(title="Domaine (optionnel)")
        if self.profile:
            self.domain_row.set_text(self.profile.get("domain", ""))
        conn_group.add(self.domain_row)

        # 2. Options Group
        opts_group = Adw.PreferencesGroup(title="Options de session", description="Périphériques et affichage")
        page.add(opts_group)

        # Sound switch
        self.sound_switch = Adw.SwitchRow(title="Redirection audio")
        self.sound_switch.set_active(self.profile.get("sound", True) if self.profile else True)
        opts_group.add(self.sound_switch)

        # Mic switch
        self.mic_switch = Adw.SwitchRow(title="Microphone")
        self.mic_switch.set_active(self.profile.get("microphone", False) if self.profile else False)
        opts_group.add(self.mic_switch)

        # Clipboard switch
        self.clip_switch = Adw.SwitchRow(title="Presse-papier partagé")
        self.clip_switch.set_active(self.profile.get("clipboard", True) if self.profile else True)
        opts_group.add(self.clip_switch)

        # Dynamic Resolution switch
        self.dyn_switch = Adw.SwitchRow(title="Résolution dynamique")
        self.dyn_switch.set_active(self.profile.get("dynamic_resolution", True) if self.profile else True)
        opts_group.add(self.dyn_switch)

        # 3. Share Group
        share_group = Adw.PreferencesGroup(title="Partage de fichiers", description="Monter un dossier Linux dans Windows")
        page.add(share_group)

        self.share_row = Adw.EntryRow(title="Chemin du Share local")
        if self.profile:
            self.share_row.set_text(self.profile.get("share_path", ""))

        browse_btn = Gtk.Button.new_from_icon_name("folder-open-symbolic")
        browse_btn.set_tooltip_text("Sélectionner un dossier")
        browse_btn.add_css_class("flat")
        browse_btn.connect("clicked", self._on_browse_share)
        self.share_row.add_suffix(browse_btn)
        share_group.add(self.share_row)

        # 4. Keyring / Credential Group
        cred_group = Adw.PreferencesGroup(
            title="Trousseau de clés",
            description="Stockage sécurisé dans Secret Service",
        )
        page.add(cred_group)

        self.pwd_row = Adw.PasswordEntryRow(title="Mot de passe")
        cred_group.add(self.pwd_row)

        if not self.is_edit:
            self.save_pwd_switch = Adw.SwitchRow(title="Enregistrer dans le trousseau")
            self.save_pwd_switch.set_active(True)
            cred_group.add(self.save_pwd_switch)
        else:
            prof_name = self.profile.get("name", "") if self.profile else ""
            has_stored = KeyringManager.has_password(prof_name)

            self.keyring_status_row = Adw.ActionRow(
                title="Mot de passe enregistré",
                subtitle="Présent dans le trousseau" if has_stored else "Aucun mot de passe mémorisé",
            )
            if has_stored:
                clear_btn = Gtk.Button(label="Supprimer du trousseau")
                clear_btn.add_css_class("flat")
                clear_btn.add_css_class("destructive-action")
                clear_btn.connect("clicked", self._on_clear_keyring_clicked)
                self.keyring_status_row.add_suffix(clear_btn)
            cred_group.add(self.keyring_status_row)

        # Action Buttons row
        action_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        action_box.set_margin_top(16)
        action_box.set_margin_bottom(16)
        action_box.set_halign(Gtk.Align.END)

        cancel_btn = Gtk.Button(label="Annuler")
        cancel_btn.connect("clicked", lambda *_: self.close())
        action_box.append(cancel_btn)

        save_btn = Gtk.Button(label="Enregistrer")
        save_btn.add_css_class("suggested-action")
        save_btn.connect("clicked", self._on_save_clicked)
        action_box.append(save_btn)

        btn_group = Adw.PreferencesGroup()
        btn_group.add(action_box)
        page.add(btn_group)

    def _on_browse_share(self, _btn: Any) -> None:
        def on_folder_picked(dialog: Gtk.FileDialog, result: Gio.AsyncResult) -> None:
            try:
                folder = dialog.select_folder_finish(result)
                if folder:
                    self.share_row.set_text(folder.get_path() or "")
            except GLib.Error:
                pass

        file_dialog = Gtk.FileDialog()
        file_dialog.set_title("Sélectionner un dossier pour le Share")
        file_dialog.select_folder(self, None, on_folder_picked)

    def _on_clear_keyring_clicked(self, btn: Gtk.Button) -> None:
        if self.profile:
            name = self.profile.get("name", "")
            KeyringManager.delete_password(name)
            self.keyring_status_row.set_subtitle("Aucun mot de passe mémorisé")
            btn.set_visible(False)

    def _on_save_clicked(self, _btn: Any) -> None:
        name = self.name_row.get_text().strip()
        host = self.host_row.get_text().strip()
        port = int(self.port_row.get_value())
        username = self.user_row.get_text().strip()
        domain = self.domain_row.get_text().strip()
        sound = self.sound_switch.get_active()
        microphone = self.mic_switch.get_active()
        clipboard = self.clip_switch.get_active()
        dynamic_res = self.dyn_switch.get_active()
        share_path = self.share_row.get_text().strip()
        pwd = self.pwd_row.get_text()

        if not name:
            self._show_error("Le nom du profil est obligatoire.")
            return

        if not self.is_edit and self.profile_manager.get_profile(name):
            self._show_error(f"Un profil nommé « {name} » existe déjà.")
            return

        if not host:
            self._show_error("L'adresse de l'hôte est obligatoire.")
            return

        updated_profile = {
            "name": name,
            "host": host,
            "port": port,
            "username": username,
            "domain": domain,
            "sound": sound,
            "microphone": microphone,
            "clipboard": clipboard,
            "dynamic_resolution": dynamic_res,
            "ignore_cert": True,
            "share_path": share_path,
        }

        self.profile_manager.save_profile(updated_profile)

        save_cred = self.save_pwd_switch.get_active() if hasattr(self, "save_pwd_switch") else True
        if pwd and save_cred:
            KeyringManager.set_credential(name, pwd)

        if self.on_saved:
            self.on_saved(updated_profile)

        self.close()

    def _show_error(self, message: str) -> None:
        dlg = Adw.MessageDialog(
            transient_for=self,
            heading="Erreur de validation",
            body=message,
        )
        dlg.add_response("ok", "OK")
        dlg.present()


class ProfileRow(Adw.ActionRow):
    """An action row representing an RDP profile with status badge and actions."""

    def __init__(self, profile: Dict[str, Any], window: "MainWindow"):
        super().__init__()
        self.profile = profile
        self.window = window
        self.profile_name = profile.get("name", "")

        self.set_title(self.profile_name)
        user = profile.get("username") or ""
        host = profile.get("host") or ""
        port = profile.get("port") or 3389
        subtitle = f"{user}@{host}:{port}" if user else f"{host}:{port}"
        self.set_subtitle(subtitle)

        # Leading machine icon
        icon = Gtk.Image.new_from_icon_name("network-workgroup-symbolic")
        self.add_prefix(icon)

        # Status badge (hidden by default)
        self.status_badge = Gtk.Label(label="En cours")
        self.status_badge.add_css_class("badge")
        self.status_badge.add_css_class("accent")
        self.status_badge.set_visible(False)
        self.add_suffix(self.status_badge)

        # Connect button
        self.connect_btn = Gtk.Button.new_from_icon_name("media-playback-start-symbolic")
        self.connect_btn.set_tooltip_text("Se connecter")
        self.connect_btn.add_css_class("flat")
        self.connect_btn.add_css_class("suggested-action")
        self.connect_btn.connect("clicked", self._on_connect_clicked)
        self.add_suffix(self.connect_btn)

        # Edit button
        self.edit_btn = Gtk.Button.new_from_icon_name("document-edit-symbolic")
        self.edit_btn.set_tooltip_text("Modifier le profil")
        self.edit_btn.add_css_class("flat")
        self.edit_btn.connect("clicked", self._on_edit_clicked)
        self.add_suffix(self.edit_btn)

        # Action group for secondary menu
        action_group = Gio.SimpleActionGroup()

        act_cred = Gio.SimpleAction.new("manage_cred", None)
        act_cred.connect("activate", lambda *_: self.window.manage_credential(self.profile_name))
        action_group.add_action(act_cred)

        act_del = Gio.SimpleAction.new("delete_profile", None)
        act_del.connect("activate", lambda *_: self.window.confirm_delete_profile(self.profile_name))
        action_group.add_action(act_del)

        self.insert_action_group("row", action_group)

        # Secondary MenuButton
        menu = Gio.Menu()
        menu.append("Gérer le credential", "row.manage_cred")
        menu.append("Supprimer le profil", "row.delete_profile")

        self.menu_btn = Gtk.MenuButton()
        self.menu_btn.set_icon_name("view-more-symbolic")
        self.menu_btn.set_tooltip_text("Options supplémentaires")
        self.menu_btn.add_css_class("flat")
        self.menu_btn.set_menu_model(menu)
        self.add_suffix(self.menu_btn)

        self.set_activatable(True)
        self.connect("activated", self._on_activated)

    def _on_activated(self, _row: Any) -> None:
        self.window.connect_profile(self.profile_name)

    def _on_connect_clicked(self, _btn: Any) -> None:
        self.window.connect_profile(self.profile_name)

    def _on_edit_clicked(self, _btn: Any) -> None:
        self.window.edit_profile(self.profile_name)

    def set_session_active(self, active: bool) -> None:
        self.status_badge.set_visible(active)
        if active:
            self.connect_btn.set_icon_name("media-playback-stop-symbolic")
            self.connect_btn.set_tooltip_text("Déconnecter la session")
            self.connect_btn.remove_css_class("suggested-action")
            self.connect_btn.add_css_class("destructive-action")
        else:
            self.connect_btn.set_icon_name("media-playback-start-symbolic")
            self.connect_btn.set_tooltip_text("Se connecter")
            self.connect_btn.remove_css_class("destructive-action")
            self.connect_btn.add_css_class("suggested-action")


class MainWindow(Adw.ApplicationWindow):
    """The main application window hosting the profile list, search bar, and actions."""

    def __init__(
        self,
        application: Adw.Application,
        profile_manager: Optional[ProfileManager] = None,
        session_manager: Optional[SessionManager] = None,
    ):
        super().__init__(application=application)
        self.profile_manager = profile_manager or ProfileManager()
        self.session_manager = session_manager or SessionManager(
            config_dir=self.profile_manager.config_dir
        )
        self.profile_rows: Dict[str, ProfileRow] = {}

        self.set_title("Omarchy RDP")
        self.set_default_size(680, 560)

        self._build_ui()
        self.refresh_profiles()

    def _build_ui(self) -> None:
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(main_box)

        # Header bar
        header = Adw.HeaderBar()
        main_box.append(header)

        # Header Title
        header_title = Adw.WindowTitle(title="Omarchy RDP", subtitle="Gestionnaire de Connexions")
        header.set_title_widget(header_title)

        # Add Profile Button (+)
        self.add_btn = Gtk.Button.new_from_icon_name("list-add-symbolic")
        self.add_btn.set_tooltip_text("Nouveau profil (Ctrl+N)")
        self.add_btn.connect("clicked", self._on_add_clicked)
        header.pack_start(self.add_btn)

        # Search Bar / Entry
        search_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        search_box.set_margin_top(8)
        search_box.set_margin_bottom(8)
        search_box.set_margin_start(16)
        search_box.set_margin_end(16)

        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_hexpand(True)
        self.search_entry.set_placeholder_text("Rechercher un profil (Ctrl+F ou /)...")
        self.search_entry.connect("search-changed", self._on_search_changed)
        self.search_entry.connect("notify::text", lambda *_: self._filter_rows(self.search_entry.get_text()))
        search_box.append(self.search_entry)
        main_box.append(search_box)

        # Scrolled content container
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        main_box.append(scrolled)

        # Preferences page & group for profile cards
        self.pref_page = Adw.PreferencesPage()
        scrolled.set_child(self.pref_page)

        self.pref_group = Adw.PreferencesGroup(title="Profils enregistrés")
        self.pref_page.add(self.pref_group)

        # Status page for empty state
        self.status_page = Adw.StatusPage()
        self.status_page.set_icon_name("network-workgroup-symbolic")
        self.status_page.set_title("Aucun profil RDP")
        self.status_page.set_description("Ajoutez un profil avec le bouton + ci-dessus.")
        self.status_page.set_vexpand(True)
        self.status_page.set_visible(False)
        main_box.append(self.status_page)

        # Keyboard shortcuts controller
        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self._on_key_pressed)
        self.add_controller(key_controller)

    def _on_key_pressed(
        self,
        _controller: Gtk.EventControllerKey,
        keyval: int,
        _keycode: int,
        state: Gdk.ModifierType,
    ) -> bool:
        # Ctrl+F: Focus search
        if (state & Gdk.ModifierType.CONTROL_MASK) and (
            keyval in (Gdk.KEY_f, Gdk.KEY_F)
        ):
            self.search_entry.grab_focus()
            return True

        # / when not already typing in an entry: Focus search
        if keyval == Gdk.KEY_slash:
            focus = self.get_focus()
            if not isinstance(focus, (Gtk.Editable, Gtk.Entry, Gtk.SearchEntry)):
                self.search_entry.grab_focus()
                return True

        # Ctrl+N: New profile
        if (state & Gdk.ModifierType.CONTROL_MASK) and (
            keyval in (Gdk.KEY_n, Gdk.KEY_N)
        ):
            self._on_add_clicked(None)
            return True

        # Escape: Clear search if non-empty
        if keyval == Gdk.KEY_Escape:
            if self.search_entry.get_text():
                self.search_entry.set_text("")
                return True

        return False

    def refresh_profiles(self) -> None:
        for row in list(self.profile_rows.values()):
            self.pref_group.remove(row)
        self.profile_rows.clear()

        profiles = self.profile_manager.list_profiles()
        if not profiles:
            self.pref_page.set_visible(False)
            self.status_page.set_title("Aucun profil RDP")
            self.status_page.set_description("Ajoutez un profil avec le bouton + ci-dessus.")
            self.status_page.set_visible(True)
            return

        self.pref_page.set_visible(True)
        self.status_page.set_visible(False)

        for profile in profiles:
            p_name = profile.get("name", "")
            row = ProfileRow(profile, self)
            if self.session_manager.is_active(p_name):
                row.set_session_active(True)
            self.profile_rows[p_name] = row
            self.pref_group.add(row)

        self._filter_rows(self.search_entry.get_text())

    def _on_search_changed(self, entry: Gtk.SearchEntry) -> None:
        self._filter_rows(entry.get_text())

    def _filter_rows(self, query: str) -> None:
        query_norm = (query or "").strip().lower()
        matched_count = 0

        for name, row in self.profile_rows.items():
            p = row.profile
            p_name = (p.get("name") or "").lower()
            p_host = (p.get("host") or "").lower()
            p_user = (p.get("username") or "").lower()
            p_dom = (p.get("domain") or "").lower()

            matches = (
                not query_norm
                or query_norm in p_name
                or query_norm in p_host
                or query_norm in p_user
                or query_norm in p_dom
            )
            row.set_visible(matches)
            if matches:
                matched_count += 1

        if len(self.profile_rows) > 0 and matched_count == 0:
            self.pref_page.set_visible(False)
            self.status_page.set_title("Aucun résultat")
            self.status_page.set_description(f"Aucun profil ne correspond à « {query} ».")
            self.status_page.set_visible(True)
        elif len(self.profile_rows) > 0:
            self.pref_page.set_visible(True)
            self.status_page.set_visible(False)

    def _on_add_clicked(self, _btn: Any) -> None:
        dialog = ProfileFormDialog(
            parent=self,
            profile_manager=self.profile_manager,
            profile=None,
            on_saved=lambda _: self.refresh_profiles(),
        )
        dialog.present()

    def edit_profile(self, name: str) -> None:
        profile = self.profile_manager.get_profile(name)
        if not profile:
            return
        dialog = ProfileFormDialog(
            parent=self,
            profile_manager=self.profile_manager,
            profile=profile,
            on_saved=lambda _: self.refresh_profiles(),
        )
        dialog.present()

    def manage_credential(self, name: str) -> None:
        dialog = CredentialDialog(
            parent=self,
            profile_name=name,
            on_updated=lambda: self.refresh_profiles(),
        )
        dialog.present()

    def confirm_delete_profile(self, name: str) -> None:
        dialog = DeleteConfirmDialog(
            parent=self,
            profile_name=name,
            on_confirm=self._do_delete_profile,
        )
        dialog.present()

    def _do_delete_profile(self, name: str) -> None:
        if self.session_manager.is_active(name):
            self.session_manager.stop_session(name)

        self.profile_manager.delete_profile(name)
        KeyringManager.delete_password(name)
        self.refresh_profiles()

    def connect_profile(self, name: str) -> None:
        if self.session_manager.is_active(name):
            self.session_manager.stop_session(name)
            return

        profile = self.profile_manager.get_profile(name)
        if not profile:
            return

        cred = KeyringManager.get_password(name)
        if cred:
            self._do_start_session(profile, cred)
        else:
            def on_dialog_confirm(pwd: str, remember: bool) -> None:
                if remember and pwd:
                    KeyringManager.set_password(name, pwd)
                self._do_start_session(profile, pwd)

            dialog = PasswordDialog(
                parent=self,
                profile_name=name,
                username=profile.get("username", ""),
                on_connect=on_dialog_confirm,
            )
            dialog.present()

    def _do_start_session(self, profile: Dict[str, Any], cred: Optional[str]) -> None:
        name = profile.get("name", "")
        success = self.session_manager.start_session(
            profile,
            credential=cred,
            on_exit=self._on_session_exit,
        )
        if success:
            if name in self.profile_rows:
                self.profile_rows[name].set_session_active(True)

    def _on_session_exit(self, name: str, returncode: int, duration: float) -> None:
        if name in self.profile_rows:
            self.profile_rows[name].set_session_active(False)


class RdpGuiApp(Adw.Application):
    """GTK4 Application for omarchy-rdp."""

    def __init__(
        self,
        profile_manager: Optional[ProfileManager] = None,
        session_manager: Optional[SessionManager] = None,
    ):
        super().__init__(
            application_id="org.omarchy.Rdp",
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self.profile_manager = profile_manager
        self.session_manager = session_manager
        self.window: Optional[MainWindow] = None

    def do_activate(self) -> None:
        if not self.window:
            self.window = MainWindow(
                application=self,
                profile_manager=self.profile_manager,
                session_manager=self.session_manager,
            )
        self.window.present()


def main() -> int:
    app = RdpGuiApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
