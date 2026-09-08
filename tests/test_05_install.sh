#!/usr/bin/env bash
# Integration test for Ticket 05: Installation & system integration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

echo "Running Ticket 05 integration tests..."
setup_test_env
trap cleanup_test_env EXIT

# Create fake HOME for installation test
FAKE_HOME="$TEST_DIR/user_home"
mkdir -p "$FAKE_HOME/.config/hypr"
touch "$FAKE_HOME/.config/hypr/hyprland.lua"

HOME="$FAKE_HOME" "$SCRIPT_DIR/../install.sh" > "$TEST_DIR/install.log"

# 1. Verify binary is installed in ~/.local/bin
assert_eq "true" "$([[ -x "$FAKE_HOME/.local/bin/omarchy-rdp" ]] && echo true || echo false)" "Binary installed and executable"

# 2. Verify desktop file is installed in ~/.local/share/applications
desktop_file="$FAKE_HOME/.local/share/applications/omarchy-rdp.desktop"
assert_eq "true" "$([[ -f "$desktop_file" ]] && echo true || echo false)" "Desktop file installed"
assert_contains "$(cat "$desktop_file")" "foot --app-id=omarchy-rdp -e omarchy-rdp" "Desktop entry executes inside foot"

# 3. Verify Hyprland rule is added
hypr_content="$(cat "$FAKE_HOME/.config/hypr/hyprland.lua")"
assert_contains "$hypr_content" 'o.window("^(omarchy-rdp)$"' "Hyprland window rule added to hyprland.lua"

# 4. Verify binary executed from outside repo via symlink works
installed_ver="$("$FAKE_HOME/.local/bin/omarchy-rdp" --version)"
assert_contains "$installed_ver" "omarchy-rdp 1." "Installed symlink runs and outputs version"

# 5. Create a fake profile to verify safe retention vs purge
mkdir -p "$FAKE_HOME/.config/omarchy-rdp"
echo '{"profiles":[{"name":"TestRetain"}]}' > "$FAKE_HOME/.config/omarchy-rdp/profiles.json"
# Add extra config in hyprland.lua to verify we only delete the omarchy-rdp rule
echo 'o.window("^(other-app)$", { float = true })' >> "$FAKE_HOME/.config/hypr/hyprland.lua"

# 6. Run standard uninstallation
HOME="$FAKE_HOME" "$SCRIPT_DIR/../uninstall.sh" > "$TEST_DIR/uninstall.log"

assert_eq "false" "$([[ -e "$FAKE_HOME/.local/bin/omarchy-rdp" ]] && echo true || echo false)" "Binary symlink removed by uninstall"
assert_eq "false" "$([[ -e "$desktop_file" ]] && echo true || echo false)" "Desktop file removed by uninstall"

hypr_uninstalled="$(cat "$FAKE_HOME/.config/hypr/hyprland.lua")"
assert_eq "false" "$(grep -q 'omarchy-rdp' "$FAKE_HOME/.config/hypr/hyprland.lua" && echo true || echo false)" "Hyprland rule removed from hyprland.lua"
assert_contains "$hypr_uninstalled" "other-app" "Other Hyprland rules preserved"
assert_eq "true" "$([[ -f "$FAKE_HOME/.config/omarchy-rdp/profiles.json" ]] && echo true || echo false)" "User profiles preserved during standard uninstall"

# 7. Run purge uninstallation
HOME="$FAKE_HOME" "$SCRIPT_DIR/../uninstall.sh" --purge > "$TEST_DIR/uninstall-purge.log"
assert_eq "false" "$([[ -e "$FAKE_HOME/.config/omarchy-rdp" ]] && echo true || echo false)" "User configuration directory removed by --purge"

report_results

