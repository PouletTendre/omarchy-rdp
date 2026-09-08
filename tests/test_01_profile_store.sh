#!/usr/bin/env bash
# Integration test for Ticket 01: Profile store & headless session execution

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

APP="$SCRIPT_DIR/../bin/omarchy-rdp"

echo "Running Ticket 01 integration tests..."
setup_test_env
trap cleanup_test_env EXIT

# 1. Initial state: listing profiles returns nothing
out="$("$APP" --list)"
assert_eq "" "$out" "Listing profiles on clean config is empty"

# 2. Add profile
"$APP" --add '{"name":"WinDev","host":"192.168.1.50","port":3389,"username":"admin"}'
out="$("$APP" --list)"
assert_eq "WinDev" "$out" "Profile WinDev is listed"

# 3. Get profile details
out="$("$APP" --get "WinDev" | jq -r '.host')"
assert_eq "192.168.1.50" "$out" "Host is retrieved correctly"

out="$("$APP" --get "WinDev" | jq -r '.username')"
assert_eq "admin" "$out" "Username is retrieved correctly"

# 4. Get FreeRDP arguments
args="$("$APP" --get-args "WinDev")"
assert_contains "$args" "/v:192.168.1.50:3389" "Args contain target host and port"
assert_contains "$args" "/u:admin" "Args contain username"
assert_contains "$args" "/dynamic-resolution" "Args contain dynamic resolution"
assert_contains "$args" "/cert:ignore" "Args contain cert ignore"

# 5. Connect headless
"$APP" --connect "WinDev"
log="$(cat "$XDG_CONFIG_HOME/mock_xfreerdp3.log")"
assert_contains "$log" "/v:192.168.1.50:3389" "FreeRDP 3 mock was invoked with host/port"

# 6. Delete profile
"$APP" --delete "WinDev"
out="$("$APP" --list)"
assert_eq "" "$out" "Profile WinDev is removed after delete"

report_results
