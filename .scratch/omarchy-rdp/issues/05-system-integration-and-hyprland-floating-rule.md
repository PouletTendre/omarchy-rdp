# 05: System Integration and Hyprland Floating Rule

**What to build:** An installation script that deploys `omarchy-rdp` to `~/.local/bin/`, installs a desktop entry file for Omarchy's app launcher (`Super + Space`) using `foot --app-id=omarchy-rdp`, configures a floating and centered Hyprland window rule, and provides comprehensive documentation.

**Blocked by:** 04: Interactive Quick-Connect TUI

**Status:** ready-for-agent

- [ ] An `install.sh` script installs or symlinks `bin/omarchy-rdp` into `~/.local/bin/omarchy-rdp` and ensures executable permissions.
- [ ] A desktop entry `omarchy-rdp.desktop` is installed to `~/.local/share/applications/` launching `foot --app-id=omarchy-rdp -e omarchy-rdp`.
- [ ] A Hyprland window rule is documented or configured (`windowrulev2 = float, class:(omarchy-rdp), size 800 600, center`) so that launching via application launcher floats the window nicely.
- [ ] Project `README.md` documents dependencies, installation steps, usage workflows, and troubleshooting tips.
- [ ] End-to-end smoke verification confirms the application can be launched from the launcher and terminal.
