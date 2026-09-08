#!/usr/bin/env bash
# Profile store configuration manager

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-rdp"
PROFILES_FILE="$CONFIG_DIR/profiles.json"

config_init() {
  mkdir -p "$CONFIG_DIR"
  if [[ ! -f "$PROFILES_FILE" ]]; then
    printf '[]\n' > "$PROFILES_FILE"
  fi
}

config_list_profiles() {
  config_init
  jq -r '.[] | .name' "$PROFILES_FILE" 2>/dev/null || true
}

config_get_profile() {
  local name="$1"
  config_init
  jq -r --arg name "$name" '.[] | select(.name == $name)' "$PROFILES_FILE"
}

config_profile_exists() {
  local name="$1"
  local match
  match="$(config_get_profile "$name")"
  [[ -n "$match" && "$match" != "null" ]]
}

config_save_profile() {
  local profile_json="$1"
  config_init
  local name
  name="$(echo "$profile_json" | jq -r '.name')"
  if [[ -z "$name" || "$name" == "null" ]]; then
    echo "Error: Profile must have a valid 'name' field" >&2
    return 1
  fi

  # Ensure default port 3389 if not provided
  profile_json="$(echo "$profile_json" | jq '.port = (.port // 3389)')"

  local tmp_file
  tmp_file="$(mktemp "$CONFIG_DIR/profiles.tmp.XXXXXX")"
  
  if config_profile_exists "$name"; then
    # Update existing
    jq --arg name "$name" --argjson new_prof "$profile_json" \
      'map(if .name == $name then $new_prof else . end)' \
      "$PROFILES_FILE" > "$tmp_file"
  else
    # Append new
    jq --argjson new_prof "$profile_json" \
      '. + [$new_prof]' \
      "$PROFILES_FILE" > "$tmp_file"
  fi

  mv "$tmp_file" "$PROFILES_FILE"
}

config_delete_profile() {
  local name="$1"
  config_init
  local tmp_file
  tmp_file="$(mktemp "$CONFIG_DIR/profiles.tmp.XXXXXX")"
  jq --arg name "$name" 'map(select(.name != $name))' "$PROFILES_FILE" > "$tmp_file"
  mv "$tmp_file" "$PROFILES_FILE"
}
