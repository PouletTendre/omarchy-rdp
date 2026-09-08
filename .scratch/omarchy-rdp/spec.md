Status: ready-for-agent

# Spec: Omarchy RDP Connection Manager (`omarchy-rdp`)

## Problem Statement

Users running Omarchy Linux (an Arch Linux distribution tailored with the Hyprland Wayland compositor) frequently need to access Windows virtual machines or remote Windows hosts for corporate, developmental, or administrative tasks. Currently, connecting via RDP requires manually typing complex, repetitive `xfreerdp` command-line arguments (including display scaling flags, dynamic resolution parameters, audio flags, and host IP addresses) or resorting to heavy desktop clients that do not integrate with Wayland, Hyprland tiling, or Linux keyring credential managers. Storing passwords in plain text or in shell history presents significant security hazards, and lack of automatic display scaling leads to tiny, unreadable remote interfaces on modern HiDPI screens.

## Solution

`omarchy-rdp` is a fast, keyboard-driven Terminal User Interface (TUI) connection manager built natively for Omarchy and Hyprland. It allows users to create, manage, and launch RDP Profiles to Windows machines in seconds.
The application seamlessly delegates connection execution to FreeRDP 3 with optimized Wayland parameters (Dynamic Resolution, automatic focused monitor Display Scale detection, clipboard synchronization, and audio redirection). Credentials are never saved in plain text, but are encrypted and stored safely via the Linux Secret Service (Keyring). Users can launch the application directly from the terminal or through the Omarchy application launcher (`Super + Space`) in a floating terminal window.

## User Stories

1. As a developer on Omarchy, I want to launch `omarchy-rdp` from my terminal or app launcher, so that I can immediately view my list of saved Profiles without remembering host addresses.
2. As a user, I want to see a Quick-Connect list of all configured Profiles on startup, so that I can select a machine and press Enter to initiate a Session with zero friction.
3. As a user, I want to filter and search my Profiles quickly, so that I can immediately locate a specific machine among many saved entries.
4. As a user, I want to create a new Profile by filling in connection details (name, host, port, username, domain, audio preferences), so that I can save my frequent remote targets.
5. As a user, I want to store my Windows Credential in the Linux Keyring securely, so that my passwords are never stored in plain text on my disk.
6. As a user, I want `omarchy-rdp` to prompt me for my password on the first connection if it is not yet saved in the Keyring, so that I don't have to manually pre-configure the Keyring.
7. As a user, I want the option to save or not save the Credential in the Keyring during the connection prompt, so that I can keep sensitive passwords ephemeral when needed.
8. As a user, I want to update or delete a stored Credential in the Keyring from the Profile management menu, so that I can rotate expired passwords easily.
9. As a user, I want my RDP Session to adapt its resolution dynamically when I resize or tile its window in Hyprland, so that I don't have fixed black bars or distorted aspect ratios.
10. As a user on a HiDPI screen, I want `omarchy-rdp` to detect my focused Hyprland monitor's Display Scale and pass the appropriate scaling factor to the RDP engine, so that the remote Windows interface is sharp and properly proportioned.
11. As a user, I want clipboard sharing enabled between Omarchy and the Windows Session, so that I can copy and paste text and files smoothly.
12. As a user, I want audio redirection enabled by default, so that audio playback from the remote Windows machine plays through my local Linux speakers.
13. As a user, I want microphone redirection to be optionally configurable per Profile, so that I can join meetings on the remote machine when necessary.
14. As a user, I want to optionally configure a local Share directory to be mounted into the remote Windows Session, so that I can transfer files between Omarchy and Windows effortlessly.
15. As a user, I want the connection engine to bypass the 23-second Kerberos NLA DNS timeout bug, so that my Sessions connect instantly via NTLM without hanging.
16. As a user, I want `/cert:ignore` applied by default, so that self-signed certificates on local VMs and dev boxes do not abort the connection.
17. As a user, I want to edit an existing Profile's host, port, username, or preferences, so that I can adjust parameters when a machine's setup changes.
18. As a user, I want to delete an obsolete Profile, so that my connection list remains clean and uncluttered.
19. As a user, I want deleting a Profile to automatically clean up its associated Credential from the Linux Keyring, so that orphaned secrets do not linger.
20. As a user, I want to receive a system notification if a Session terminates unexpectedly with an error, so that I immediately understand why the connection dropped.
21. As a user, I want a `.desktop` launcher entry for `omarchy-rdp`, so that I can open the manager using Omarchy's standard `Super + Space` shortcut.
22. As a user, I want the application window launched from the desktop entry to open in a floating, centered terminal window, so that it behaves like a lightweight utility dialog rather than a tiled work pane.
23. As a developer, I want to invoke `omarchy-rdp` non-interactively via CLI flags (e.g. to connect directly to a profile by name), so that I can script or bind specific machines to custom shortcuts.

## Implementation Decisions

- **Architecture & Ecosystem Alignment**: The application is designed as a modular Bash program leveraging `gum` and `fzf` for TUI interactions, matching Omarchy's native system utilities. It compiles no external binaries and relies exclusively on tools pre-installed on the host.
- **RDP Engine**: Delegated to FreeRDP 3 (`xfreerdp3`). The manager assembles the command-line arguments according to the Profile settings, detects Hyprland display scaling via monitor queries, sets the Kerberos realm fallback configuration, and spawns the FreeRDP process.
- **Profile Storage Format**: Profiles are persisted in a centralized JSON document located in the user's XDG config directory (`omarchy-rdp/profiles.json`). Operations on the JSON structure use `jq` for deterministic queries and atomic file writes.
- **Credential Storage**: Passwords are never serialized into `profiles.json`. They are managed via Secret Service using `secret-tool` with attributes `service=omarchy-rdp` and `profile=<name>`.
- **System Integration**: A desktop entry file is provided to launch the manager inside `foot` with a custom app-id, accompanied by a Hyprland window rule to float and center the window upon invocation.
- **CLI Seam Interface**: In addition to interactive TUI mode, the core script exposes headless subcommands (`--list`, `--connect <name>`, `--add <json>`, `--delete <name>`, `--get-args <name>`) allowing scriptable automation and black-box testing.

## Testing Decisions

- **High-level Testing Seam**: A good test exercises external behavior and outputs through the public CLI seam rather than testing internal helper functions or mock-heavy unit logic.
- **Test Strategy**: Integration test suite executing the `omarchy-rdp` CLI interface with isolated test environments:
  - `XDG_CONFIG_HOME` redirected to a temporary scratch directory.
  - A mock `secret-tool` intercepting and recording store/lookup/clear invocations.
  - A mock `xfreerdp3` intercepting and verifying the generated command-line arguments without opening real network sockets.
- **Verification Matrix**:
  - Verification of Profile CRUD operations and JSON persistence integrity.
  - Verification that password lookups query the exact service and profile attributes.
  - Verification of FreeRDP 3 argument generation (Dynamic Resolution, monitor scaling calculations, audio/mic flags, local Share flags, and Kerberos environment setup).
  - Verification of exit code handling and error reporting.

## Out of Scope

- Developing a custom RDP protocol parser or implementing custom GUI rendering widgets.
- Supporting legacy RDP protocols or non-FreeRDP client engines (such as Remmina or rdesktop).
- Automatic discovery of Windows hosts on the local network (mDNS/Active Directory queries).
- Managing multi-hop SSH tunnels or complex VPN lifecycle orchestration within the app.
- Synchronizing Profiles across multiple machines via cloud storage.

## Further Notes

- FreeRDP 3's MIT Kerberos lookup issue is circumvented by generating a minimal `krb5.conf` with `dns_lookup_kdc = false` and passing it via `KRB5_CONFIG`.
- FreeRDP 3 automatically handles Wayland HiDPI scaling, but explicitly setting `/scale:140` or `/scale:180` based on Hyprland's active monitor scaling provides crisp font rendering for remote Windows sessions.
