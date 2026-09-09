#!/usr/bin/env bash
# Integration test for Launcher Watchdog & Failure Recovery

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

APP="$SCRIPT_DIR/../bin/omarchy-rdp"

echo "Running Watchdog lifecycle integration tests..."
setup_test_env
trap cleanup_test_env EXIT

# Mock notify-send and omarchy-notification-send
cat << 'MOCK_NOTIFY_EOF' > "$MOCK_BIN_DIR/notify-send"
#!/usr/bin/env bash
echo "notify: $@" >> "$XDG_CONFIG_HOME/mock_notify.log"
exit 0
MOCK_NOTIFY_EOF
chmod +x "$MOCK_BIN_DIR/notify-send"

cat << 'MOCK_OM_NOTIFY_EOF' > "$MOCK_BIN_DIR/omarchy-notification-send"
#!/usr/bin/env bash
echo "notify: $@" >> "$XDG_CONFIG_HOME/mock_notify.log"
exit 0
MOCK_OM_NOTIFY_EOF
chmod +x "$MOCK_BIN_DIR/omarchy-notification-send"

# Mock foot
cat << 'MOCK_FOOT_EOF' > "$MOCK_BIN_DIR/foot"
#!/usr/bin/env bash
echo "foot reopened with: $@" >> "$XDG_CONFIG_HOME/mock_foot.log"
exit 0
MOCK_FOOT_EOF
chmod +x "$MOCK_BIN_DIR/foot"

# Add test profile
"$APP" --add '{"name":"TargetPC","host":"10.0.0.99","username":"testuser"}'

# Case 1: Session fails immediately (exit 1)
cat << 'FAIL_RDP_EOF' > "$MOCK_BIN_DIR/xfreerdp3"
#!/usr/bin/env bash
exit 1
FAIL_RDP_EOF
chmod +x "$MOCK_BIN_DIR/xfreerdp3"

"$APP" --watchdog "TargetPC"
sleep 0.2
notify_log="$(cat "$XDG_CONFIG_HOME/mock_notify.log" 2>/dev/null || true)"
foot_log="$(cat "$XDG_CONFIG_HOME/mock_foot.log" 2>/dev/null || true)"

assert_contains "$notify_log" "TargetPC" "Notification emitted when session fails immediately"
assert_contains "$foot_log" "foot reopened" "Launcher foot window reopened on failure"

# Case 2: Session succeeds and lasts >= 3 seconds
rm -f "$XDG_CONFIG_HOME/mock_notify.log" "$XDG_CONFIG_HOME/mock_foot.log"

cat << 'OK_RDP_EOF' > "$MOCK_BIN_DIR/xfreerdp3"
#!/usr/bin/env bash
sleep 3
exit 0
OK_RDP_EOF
chmod +x "$MOCK_BIN_DIR/xfreerdp3"

"$APP" --watchdog "TargetPC"
assert_eq "" "$(cat "$XDG_CONFIG_HOME/mock_notify.log" 2>/dev/null || true)" "Silent exit when session succeeds normally"
assert_eq "" "$(cat "$XDG_CONFIG_HOME/mock_foot.log" 2>/dev/null || true)" "No reopening when session succeeds normally"

report_results
