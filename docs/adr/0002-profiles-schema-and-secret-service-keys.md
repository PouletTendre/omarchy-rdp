# Architecture: Profile Schema and Secret Service Keys

Profiles are stored in `~/.config/omarchy-rdp/profiles.json` containing connection metadata (name, host, port, username, domain, sound, microphone, clipboard, dynamic resolution, and local share). Passwords are never written to disk; they are stored in the Secret Service keyring with attributes `service=omarchy-rdp` and `profile=<name>`.
