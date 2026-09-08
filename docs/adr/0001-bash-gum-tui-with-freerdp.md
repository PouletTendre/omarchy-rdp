# Architecture: Bash/Gum TUI wrapping FreeRDP 3 and Linux Keyring

We chose a modular Bash script using Gum and FZF for the TUI, FreeRDP 3 (`xfreerdp3`) for the RDP engine, and Secret Service (`secret-tool`) for credential storage. This provides seamless, zero-dependency integration with Omarchy's Wayland/Hyprland environment while matching existing system utilities.
