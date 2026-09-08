# 04: Interactive Quick-Connect TUI

**What to build:** An interactive terminal user interface (TUI) powered by Gum and FZF that displays saved Profiles upon invocation, launches a chosen Session on Enter, provides interactive forms to add/edit/delete Profiles and manage passwords, and notifies the desktop if a Session exits abnormally.

**Blocked by:** 02: Keyring Credential Management, 03: Hyprland Display Scale and Advanced RDP Options

**Status:** resolved

- [x] When invoked without arguments, launch an interactive TUI displaying styled application banner and a list of configured Profiles.
- [x] Selecting a Profile and pressing Enter starts the Session immediately.
- [x] Main screen provides navigation entries for `[➕ Nouveau profil]`, `[✏️ Modifier un profil]`, `[🔑 Gérer mot de passe]`, `[🗑️ Supprimer un profil]`, and `[🚪 Quitter]`.
- [x] Interactive form captures all Profile fields (name, host, port, username, domain, audio, mic, clipboard, local share) and prompts to save initial Credential to the Keyring.
- [x] Editing an existing Profile pre-fills current values and persists updates cleanly.
- [x] Desktop notifications (`notify-send` / `omarchy-notification-send`) alert the user if FreeRDP 3 exits with an error status.
