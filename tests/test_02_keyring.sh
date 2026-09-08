#!/usr/bin/env bash
# Integration test for Ticket 02: Keyring Credential Management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

APP="$SCRIPT_DIR/../bin/omarchy-rdp"

echo "Running Ticket 02 integration tests..."
setup_test_env
trap cleanup_test_env EXIT

TAB=$'\t'

# Create mock secret-tool
cat << 'MOCK_SECRET_EOF' > "$MOCK_BIN_DIR/secret-tool"
#!/usr/bin/env bash
KEYRING_FILE="$XDG_CONFIG_HOME/mock_keyring.tsv"
touch "$KEYRING_FILE"

action="$1"
shift

TAB=$'\t'

case "$action" in
  lookup)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 == s && $2 == p { print $3 }' "$KEYRING_FILE"
    ;;
  store)
    label=""
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --label=*) label="${1#*=}"; shift ;;
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    secret="$(cat)"
    # Remove existing entry if present
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 != s || $2 != p' "$KEYRING_FILE" > "$KEYRING_FILE.tmp" || true
    mv "$KEYRING_FILE.tmp" "$KEYRING_FILE"
    printf '%s\t%s\t%s\n' "$service" "$profile" "$secret" >> "$KEYRING_FILE"
    ;;
  clear)
    service=""
    profile=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        service) service="$2"; shift 2 ;;
        profile) profile="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    awk -F"$TAB" -v s="$service" -v p="$profile" '$1 != s || $2 != p' "$KEYRING_FILE" > "$KEYRING_FILE.tmp" || true
    mv "$KEYRING_FILE.tmp" "$KEYRING_FILE"
    ;;
esac
exit 0
MOCK_SECRET_EOF
chmod +x "$MOCK_BIN_DIR/secret-tool"

# 1. Add a profile
"$APP" --add '{"name":"WinDev","host":"192.168.1.50","port":3389,"username":"admin"}'

# 2. Store password in keyring via CLI
"$APP" --set-password "WinDev" "SuperSecret123"

# 3. Verify password is stored in mock keyring under service=omarchy-rdp profile=WinDev
stored_pass="$(awk -F"$TAB" '$1 == "omarchy-rdp" && $2 == "WinDev" { print $3 }' "$XDG_CONFIG_HOME/mock_keyring.tsv")"
assert_eq "SuperSecret123" "$stored_pass" "Password correctly stored in Secret Service"

# 4. Verify password is NOT in profiles.json
profile_json="$("$APP" --get "WinDev")"
assert_eq "null" "$(echo "$profile_json" | jq -r '.password // "null"')" "profiles.json contains no password"

# 5. FreeRDP arguments mask password by default on CLI and reveal only with --show-secrets
masked_args="$("$APP" --get-args "WinDev")"
assert_contains "$masked_args" "/p:********" "Args mask password by default on CLI"

raw_args="$("$APP" --get-args "WinDev" --show-secrets)"
assert_contains "$raw_args" "/p:SuperSecret123" "Args retrieve password from keyring with --show-secrets"

# 6. Connecting invokes FreeRDP with the password securely via file descriptor (not in process argv)
"$APP" --connect "WinDev"
log="$(cat "$XDG_CONFIG_HOME/mock_xfreerdp3.log")"
cli_call="$(grep "^xfreerdp3 cli:" "$XDG_CONFIG_HOME/mock_xfreerdp3.log" | head -n 1)"
assert_contains "$cli_call" "/args-from:fd:3" "FreeRDP CLI only uses descriptor pipe"
if [[ "$cli_call" == *"/p:"* ]]; then
  assert_eq "no /p: in cli" "found /p: in cli" "Password must not leak into process CLI arguments"
else
  assert_eq "clean" "clean" "Password not exposed in FreeRDP command line"
fi
assert_contains "$log" "/p:SuperSecret123" "FreeRDP receives stored password via fd:3"

# 7. Deleting profile clears the password from keyring
"$APP" --delete "WinDev"
cleared_pass="$(awk -F"$TAB" '$1 == "omarchy-rdp" && $2 == "WinDev" { print $3 }' "$XDG_CONFIG_HOME/mock_keyring.tsv")"
assert_eq "" "$cleared_pass" "Secret cleared from Keyring upon profile deletion"

report_results
