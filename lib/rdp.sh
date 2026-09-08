#!/usr/bin/env bash
# FreeRDP 3 launcher and argument builder

rdp_build_args() {
  local profile_json="$1"
  local password="${2:-}"

  local host port username domain
  host="$(echo "$profile_json" | jq -r '.host')"
  port="$(echo "$profile_json" | jq -r '.port // 3389')"
  username="$(echo "$profile_json" | jq -r '.username')"
  domain="$(echo "$profile_json" | jq -r '.domain // ""')"

  local -a args=(
    "/v:$host:$port"
    "/u:$username"
    "/dynamic-resolution"
    "/cert:ignore"
  )

  if [[ -n "$domain" && "$domain" != "null" ]]; then
    args+=("/d:$domain")
  fi

  if [[ -n "$password" ]]; then
    args+=("/p:$password")
  fi

  printf '%s\n' "${args[@]}"
}

rdp_connect() {
  local profile_json="$1"
  local password="${2:-}"

  local -a args=()
  while IFS= read -r arg; do
    [[ -n "$arg" ]] && args+=("$arg")
  done < <(rdp_build_args "$profile_json" "$password")

  exec xfreerdp3 "${args[@]}"
}
