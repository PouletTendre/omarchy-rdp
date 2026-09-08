#!/usr/bin/env bash
# Keyring helper using Linux Secret Service (secret-tool)

KEYRING_SERVICE="omarchy-rdp"

keyring_get_password() {
  local profile_name="$1"
  if ! command -v secret-tool >/dev/null 2>&1; then
    return 1
  fi
  secret-tool lookup service "$KEYRING_SERVICE" profile "$profile_name" 2>/dev/null
}

keyring_set_password() {
  local profile_name="$1"
  local password="$2"
  if ! command -v secret-tool >/dev/null 2>&1; then
    echo "Error: secret-tool is not installed" >&2
    return 1
  fi
  printf '%s' "$password" | secret-tool store \
    --label="omarchy-rdp: $profile_name" \
    service "$KEYRING_SERVICE" \
    profile "$profile_name" 2>/dev/null
}

keyring_delete_password() {
  local profile_name="$1"
  if ! command -v secret-tool >/dev/null 2>&1; then
    return 0
  fi
  secret-tool clear service "$KEYRING_SERVICE" profile "$profile_name" 2>/dev/null || true
}

keyring_has_password() {
  local profile_name="$1"
  local pass
  pass="$(keyring_get_password "$profile_name" || true)"
  [[ -n "$pass" ]]
}
