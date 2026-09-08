#!/usr/bin/env bash
# Integration test for Ticket 04: Interactive Quick-Connect TUI & Notifications

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

APP="$SCRIPT_DIR/../bin/omarchy-rdp"

echo "Running Ticket 04 integration tests..."
setup_test_env
trap cleanup_test_env EXIT

# Create mock notify-send
cat << 'MOCK_NOTIFY_EOF' > "$MOCK_BIN_DIR/notify-send"
#!/usr/bin/env bash
echo "notify-send: $@" >> "$XDG_CONFIG_HOME/mock_notify.log"
exit 0
MOCK_NOTIFY_EOF
chmod +x "$MOCK_BIN_DIR/notify-send"

# Also mock omarchy-notification-send
cat << 'MOCK_OM_NOTIFY_EOF' > "$MOCK_BIN_DIR/omarchy-notification-send"
#!/usr/bin/env bash
echo "omarchy-notify: $@" >> "$XDG_CONFIG_HOME/mock_notify.log"
exit 0
MOCK_OM_NOTIFY_EOF
chmod +x "$MOCK_BIN_DIR/omarchy-notification-send"

# Source UI module directly to test UI helper functions
source "$SCRIPT_DIR/../lib/config.sh"
source "$SCRIPT_DIR/../lib/keyring.sh"
source "$SCRIPT_DIR/../lib/rdp.sh"
source "$SCRIPT_DIR/../lib/ui.sh"

# 1. Test error notification
ui_notify_error "Connection dropped"
notify_log="$(cat "$XDG_CONFIG_HOME/mock_notify.log")"
assert_contains "$notify_log" "Connection dropped" "Notification sent on error"

# 2. Add profile and verify ui_build_menu_options contains it
"$APP" --add '{"name":"DesktopWork","host":"10.0.0.5","username":"user1"}'
menu_items="$(ui_build_menu_options)"
assert_contains "$menu_items" "DesktopWork" "Profile listed in menu options"
assert_contains "$menu_items" "Nouveau profil" "Add action in menu options"
assert_contains "$menu_items" "Supprimer un profil" "Delete action in menu options"
assert_contains "$menu_items" "Gérer le credential" "Password action in menu options"

# 3. Test failure in rdp execution triggers notification
cat << 'FAIL_RDP_EOF' > "$MOCK_BIN_DIR/xfreerdp3"
#!/usr/bin/env bash
exit 12
FAIL_RDP_EOF
chmod +x "$MOCK_BIN_DIR/xfreerdp3"

# Connect to DesktopWork with error handling
ui_connect "DesktopWork" "dummyPass" || true
notify_log="$(cat "$XDG_CONFIG_HOME/mock_notify.log")"
assert_contains "$notify_log" "DesktopWork" "Notification mentions profile name on exit failure"

report_results
