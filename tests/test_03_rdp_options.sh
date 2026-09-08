#!/usr/bin/env bash
# Integration test for Ticket 03: Hyprland Display Scale and Advanced RDP Options

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

APP="$SCRIPT_DIR/../bin/omarchy-rdp"

echo "Running Ticket 03 integration tests..."
setup_test_env
trap cleanup_test_env EXIT

# Create mock hyprctl
cat << 'MOCK_HYPR_EOF' > "$MOCK_BIN_DIR/hyprctl"
#!/usr/bin/env bash
SCALE="${MOCK_HYPR_SCALE:-1.0}"
cat << JSON_EOF
[
  {
    "id": 0,
    "name": "DP-1",
    "focused": true,
    "scale": $SCALE
  }
]
JSON_EOF
MOCK_HYPR_EOF
chmod +x "$MOCK_BIN_DIR/hyprctl"

# 1. HiDPI scaling >= 170% -> /scale:180
"$APP" --add '{"name":"HiDPI","host":"10.0.0.1","username":"noah"}'
export MOCK_HYPR_SCALE=1.75
args="$("$APP" --get-args "HiDPI")"
assert_contains "$args" "/scale:180" "Scale 1.75 produces /scale:180"

# 2. HiDPI scaling >= 130% -> /scale:140
export MOCK_HYPR_SCALE=1.4
args="$("$APP" --get-args "HiDPI")"
assert_contains "$args" "/scale:140" "Scale 1.4 produces /scale:140"

# 3. Standard scaling 1.0 -> no /scale flag
export MOCK_HYPR_SCALE=1.0
args="$("$APP" --get-args "HiDPI")"
if [[ "$args" == *"/scale:"* ]]; then
  assert_eq "no /scale flag" "has /scale flag" "Scale 1.0 has no /scale flag"
else
  assert_eq "no /scale flag" "no /scale flag" "Scale 1.0 has no /scale flag"
fi

# 4. Sound, microphone, clipboard flags
"$APP" --add '{"name":"Media","host":"10.0.0.2","username":"noah","sound":true,"microphone":true,"clipboard":true}'
args="$("$APP" --get-args "Media")"
assert_contains "$args" "/sound" "Sound flag included"
assert_contains "$args" "/microphone" "Microphone flag included"
assert_contains "$args" "/clipboard" "Clipboard flag included"

# 5. Local directory share
SHARE_DIR="$TEST_DIR/shared_folder"
mkdir -p "$SHARE_DIR"
"$APP" --add "{\"name\":\"ShareProf\",\"host\":\"10.0.0.3\",\"username\":\"noah\",\"share_path\":\"$SHARE_DIR\"}"
args="$("$APP" --get-args "ShareProf")"
assert_contains "$args" "/drive:shared,$SHARE_DIR" "Drive share flag included"

# 6. Connecting verifies krb5.conf was created and passed
"$APP" --set-password "HiDPI" "testpass" < /dev/null || true
"$APP" --connect "HiDPI" < /dev/null
krb5_file="$XDG_CONFIG_HOME/omarchy-rdp/krb5/krb5.conf"
assert_eq "true" "$([[ -f "$krb5_file" ]] && echo true || echo false)" "krb5.conf created"
assert_contains "$(cat "$krb5_file" 2>/dev/null || true)" "dns_lookup_kdc = false" "krb5.conf disables KDC DNS lookup"

report_results
