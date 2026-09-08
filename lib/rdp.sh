#!/usr/bin/env bash
# FreeRDP 3 launcher and argument builder

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-rdp"

rdp_detect_display_scale() {
  if ! command -v hyprctl >/dev/null 2>&1; then
    return 0
  fi
  local hypr_scale
  hypr_scale="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .scale' 2>/dev/null || true)"
  if [[ -n "$hypr_scale" && "$hypr_scale" != "null" ]]; then
    local scale_pct
    scale_pct="$(echo "$hypr_scale" | awk '{print int($1 * 100)}')"
    if (( scale_pct >= 170 )); then
      echo "/scale:180"
    elif (( scale_pct >= 130 )); then
      echo "/scale:140"
    fi
  fi
}

rdp_setup_krb5() {
  local krb5_dir="$CONFIG_DIR/krb5"
  local krb5_conf="$krb5_dir/krb5.conf"
  mkdir -p "$krb5_dir"
  if [[ ! -f "$krb5_conf" ]]; then
    printf '[libdefaults]\n  dns_lookup_kdc = false\n  dns_lookup_realm = false\n' > "$krb5_conf"
  fi
  export KRB5_CONFIG="$krb5_conf"
}

rdp_build_args() {
  local profile_json="$1"
  local password="${2:-}"

  local host port username domain sound microphone clipboard share_path ignore_cert
  host="$(echo "$profile_json" | jq -r '.host')"
  port="$(echo "$profile_json" | jq -r '.port // 3389')"
  username="$(echo "$profile_json" | jq -r '.username')"
  domain="$(echo "$profile_json" | jq -r '.domain // ""')"
  sound="$(echo "$profile_json" | jq -r '.sound // false')"
  microphone="$(echo "$profile_json" | jq -r '.microphone // false')"
  clipboard="$(echo "$profile_json" | jq -r 'if has("clipboard") then .clipboard else true end')"
  share_path="$(echo "$profile_json" | jq -r '.share_path // ""')"
  ignore_cert="$(echo "$profile_json" | jq -r 'if has("ignore_cert") then .ignore_cert else true end')"

  local -a args=(
    "/v:$host:$port"
    "/u:$username"
    "/dynamic-resolution"
  )

  if [[ "$ignore_cert" == "true" ]]; then
    args+=("/cert:ignore")
  fi

  if [[ "$clipboard" == "true" ]]; then
    args+=("/clipboard")
  fi

  if [[ "$sound" == "true" ]]; then
    args+=("/sound")
  fi

  if [[ "$microphone" == "true" ]]; then
    args+=("/microphone")
  fi

  if [[ -n "$share_path" && "$share_path" != "null" && -d "$share_path" ]]; then
    args+=("/drive:shared,$share_path")
  fi

  local scale_flag
  scale_flag="$(rdp_detect_display_scale)"
  if [[ -n "$scale_flag" ]]; then
    args+=("$scale_flag")
  fi

  if [[ -n "$domain" && "$domain" != "null" ]]; then
    args+=("/d:$domain")
  fi

  if [[ -n "$password" ]]; then
    args+=("/p:$password")
  fi

  local name
  name="$(echo "$profile_json" | jq -r '.name // "Windows"')"
  args+=("/title:$name - omarchy-rdp")

  printf '%s\n' "${args[@]}"
}

rdp_connect() {
  local profile_json="$1"
  local password="${2:-}"

  rdp_setup_krb5

  local -a args=()
  while IFS= read -r arg; do
    [[ -n "$arg" ]] && args+=("$arg")
  done < <(rdp_build_args "$profile_json" "$password")

  exec xfreerdp3 "${args[@]}"
}
