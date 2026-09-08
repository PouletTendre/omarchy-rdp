# RDP Connection Manager

A terminal-based connection manager on Omarchy Linux to configure, store, and launch remote desktop sessions to Windows machines.

## Language

**Profile**:
A named configuration representing a target Windows machine and its connection parameters (host, port, username, domain, display options, audio, and shares).
_Avoid_: Host, server, session config, bookmark

**Credential**:
An authentication secret (password) stored in the Linux keyring mapped to a specific profile or username.
_Avoid_: Password, secret, token

**Session**:
An active, running remote desktop connection instance spawned from a profile.
_Avoid_: Connection, link

**TUI**:
The interactive terminal user interface used to browse, edit, create profiles, and initiate sessions.
_Avoid_: GUI, console, CLI

**Launcher**:
The transient floating window hosting the TUI, invoked from the application menu to launch a session.
_Avoid_: Terminal, console window

**Dynamic Resolution**:
Automatic synchronization of the remote Windows desktop resolution with the local Hyprland window dimensions.
_Avoid_: Fixed resolution, fullscreen-only

**Share**:
A local Linux directory mounted into the remote Windows session as a drive via RDP.
_Avoid_: Mount, shared folder, local disk

**Display Scale**:
The scaling factor derived from the focused Hyprland monitor and passed to FreeRDP to ensure crisp rendering on HiDPI displays.
_Avoid_: Zoom, DPI

**Package**:
The installable Arch Linux distribution unit built from a PKGBUILD for installation via pacman or yay.
_Avoid_: Installer, zip, binary
