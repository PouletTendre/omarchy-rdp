# Architecture: Launcher Lifecycle and AUR Packaging

The launcher TUI window terminates immediately upon initiating a remote desktop Session, eliminating residual floating terminal windows under Hyprland. If the session terminates with an error or lasts less than 3 seconds, a desktop notification is dispatched and the launcher reopens automatically. For public distribution, the application is packaged via an Arch User Repository (AUR) PKGBUILD and a standalone curl installer pointing to GitHub.
