#!/usr/bin/env bash
# Terminal User Interface for omarchy-rdp using Gum and FZF

DELIM=" :: "

ui_notify_error() {
  local msg="$1"
  if command -v omarchy-notification-send >/dev/null 2>&1; then
    omarchy-notification-send -u critical "omarchy-rdp" "$msg" 2>/dev/null || true
  elif command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "omarchy-rdp" "$msg" 2>/dev/null || true
  fi
  echo "⚠️  $msg" >&2
}

ui_build_menu_options() {
  local names
  names="$(config_list_profiles)"
  if [[ -n "$names" ]]; then
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      local prof user host port
      prof="$(config_get_profile "$name")"
      user="$(echo "$prof" | jq -r '.username // ""')"
      host="$(echo "$prof" | jq -r '.host // ""')"
      port="$(echo "$prof" | jq -r '.port // 3389')"
      echo "🖥️   ${name}${DELIM}(${user}@${host}:${port})"
    done <<< "$names"
  fi

  echo "➕  Nouveau profil"
  if [[ -n "$names" ]]; then
    echo "✏️   Modifier un profil"
    echo "🔑  Gérer le credential"
    echo "🗑️   Supprimer un profil"
  fi
  echo "🚪  Quitter"
}

ui_launch_session() {
  local name="$1"
  local cred="${2:-}"

  local prof
  prof="$(config_get_profile "$name")"
  if [[ -z "$prof" || "$prof" == "null" ]]; then
    ui_notify_error "Profil '$name' introuvable."
    return 1
  fi

  if [[ -z "$cred" ]]; then
    cred="$(keyring_get_password "$name" || true)"
  fi

  if [[ -z "$cred" ]]; then
    if command -v gum >/dev/null 2>&1 && [[ -t 0 ]]; then
      local user
      user="$(echo "$prof" | jq -r '.username')"
      cred="$(gum input --password --placeholder "Mot de passe Windows pour $user")"
      if [[ -n "$cred" ]] && gum confirm --default=true "Mémoriser ce credential dans le trousseau sécurisé ?"; then
        keyring_set_password "$name" "$cred"
      fi
    fi
  fi

  clear || true
  echo "Lancement de la Session pour $name..."
  rdp_execute_session "$prof" "$cred"
  local exit_code=$?

  if (( exit_code != 0 )); then
    ui_notify_error "La session '$name' a échoué (code de sortie: $exit_code)."
    return $exit_code
  fi
  return 0
}

ui_connect() {
  ui_launch_session "$@"
}

ui_launch_detached() {
  local name="$1"
  local cred="${2:-}"

  local prof
  prof="$(config_get_profile "$name")"
  if [[ -z "$prof" || "$prof" == "null" ]]; then
    ui_notify_error "Profil '$name' introuvable."
    return 1
  fi

  if [[ -z "$cred" ]]; then
    cred="$(keyring_get_password "$name" || true)"
  fi

  local tmp_cred_file=""
  # Ask for credentials inside this window if missing before closing
  if [[ -z "$cred" && -t 0 ]]; then
    if command -v gum >/dev/null 2>&1; then
      local user
      user="$(echo "$prof" | jq -r '.username')"
      cred="$(gum input --password --placeholder "Mot de passe Windows pour $user")"
      if [[ -n "$cred" ]]; then
        if gum confirm --default=true "Mémoriser ce credential dans le trousseau sécurisé ?"; then
          keyring_set_password "$name" "$cred"
        else
          local runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/omarchy-rdp"
          mkdir -p -m 700 "$runtime_dir"
          tmp_cred_file="$(mktemp "$runtime_dir/cred_XXXXXX")"
          chmod 600 "$tmp_cred_file"
          printf '%s' "$cred" > "$tmp_cred_file"
        fi
      fi
    fi
  fi

  local -a watchdog_cmd=("omarchy-rdp" "--watchdog" "$name")
  if [[ -n "$tmp_cred_file" ]]; then
    watchdog_cmd+=("--credential-file" "$tmp_cred_file")
  fi

  # Dispatch via systemd-run so the process escapes the terminal's cgroup
  if command -v systemd-run >/dev/null 2>&1; then
    systemd-run --user \
      --setenv=WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
      --setenv=DISPLAY="${DISPLAY:-}" \
      --setenv=XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
      --setenv=XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" \
      --setenv=PATH="$PATH" \
      "${watchdog_cmd[@]}" >/dev/null 2>&1
  else
    nohup "${watchdog_cmd[@]}" >/dev/null 2>&1 &
  fi

  exit 0
}

ui_new_profile() {
  echo ""
  gum style --foreground 212 --bold "➕ Création d'un nouveau profil RDP"

  local name host port username domain sound microphone clipboard share_path cred
  name="$(gum input --placeholder "Nom du profil (ex: Bureau, WinDev)" --prompt "Nom : ")"
  if [[ -z "$name" ]]; then
    echo "Création annulée."
    return 0
  fi

  if config_profile_exists "$name"; then
    gum style --foreground 196 "Un profil avec ce nom existe déjà."
    return 1
  fi

  host="$(gum input --placeholder "Adresse IP ou nom d'hôte (ex: 192.168.1.50)" --prompt "Hôte : ")"
  if [[ -z "$host" ]]; then
    echo "Hôte requis. Annulé."
    return 1
  fi

  port="$(gum input --value "3389" --placeholder "Port (défaut: 3389)" --prompt "Port : ")"
  username="$(gum input --placeholder "Nom d'utilisateur Windows" --prompt "Utilisateur : ")"
  domain="$(gum input --placeholder "Domaine (optionnel)" --prompt "Domaine : ")"
  
  sound="true"
  if ! gum confirm --default=true "Activer la redirection audio ?"; then
    sound="false"
  fi

  microphone="false"
  if gum confirm --default=false "Activer le microphone ?"; then
    microphone="true"
  fi

  clipboard="true"
  if ! gum confirm --default=true "Activer le presse-papier partagé ?"; then
    clipboard="false"
  fi

  share_path="$(gum input --placeholder "Chemin du Share local (optionnel)" --prompt "Share local : ")"
  cred="$(gum input --password --placeholder "Credential (laisser vide pour demander à la connexion)" --prompt "Mot de passe : ")"

  local prof_json
  prof_json="$(jq -n \
    --arg name "$name" \
    --arg host "$host" \
    --argjson port "${port:-3389}" \
    --arg username "$username" \
    --arg domain "$domain" \
    --argjson sound "$sound" \
    --argjson microphone "$microphone" \
    --argjson clipboard "$clipboard" \
    --arg share_path "$share_path" \
    --argjson ignore_cert "true" \
    --argjson dynamic_resolution "true" \
    '{name: $name, host: $host, port: $port, username: $username, domain: $domain, sound: $sound, microphone: $microphone, clipboard: $clipboard, share_path: $share_path, ignore_cert: $ignore_cert, dynamic_resolution: $dynamic_resolution}')"

  config_save_profile "$prof_json"

  if [[ -n "$cred" ]]; then
    keyring_set_password "$name" "$cred"
  fi

  gum style --foreground 82 "✓ Profil '$name' enregistré avec succès !"
  sleep 1
}

ui_edit_profile() {
  local names
  names="$(config_list_profiles)"
  if [[ -z "$names" ]]; then
    echo "Aucun profil à modifier."
    return 0
  fi

  local target
  target="$(echo "$names" | fzf --height 40% --reverse --prompt="Modifier quel profil ? > ")"
  if [[ -z "$target" ]]; then
    return 0
  fi

  local prof
  prof="$(config_get_profile "$target")"

  local host port username domain sound microphone clipboard share_path
  host="$(echo "$prof" | jq -r '.host // ""')"
  port="$(echo "$prof" | jq -r '.port // 3389')"
  username="$(echo "$prof" | jq -r '.username // ""')"
  domain="$(echo "$prof" | jq -r '.domain // ""')"
  share_path="$(echo "$prof" | jq -r '.share_path // ""')"
  sound="$(echo "$prof" | jq -r 'if has("sound") then .sound else true end')"
  microphone="$(echo "$prof" | jq -r '.microphone // false')"
  clipboard="$(echo "$prof" | jq -r 'if has("clipboard") then .clipboard else true end')"

  host="$(gum input --value "$host" --prompt "Hôte : ")"
  port="$(gum input --value "$port" --prompt "Port : ")"
  username="$(gum input --value "$username" --prompt "Utilisateur : ")"
  domain="$(gum input --value "$domain" --prompt "Domaine : ")"
  share_path="$(gum input --value "$share_path" --prompt "Share local : ")"

  if [[ "$sound" == "true" ]]; then
    gum confirm --default=true "Garder la redirection audio activée ?" || sound="false"
  else
    gum confirm --default=false "Activer la redirection audio ?" && sound="true"
  fi

  if [[ "$microphone" == "true" ]]; then
    gum confirm --default=true "Garder le microphone activé ?" || microphone="false"
  else
    gum confirm --default=false "Activer le microphone ?" && microphone="true"
  fi

  if [[ "$clipboard" == "true" ]]; then
    gum confirm --default=true "Garder le presse-papier partagé ?" || clipboard="false"
  else
    gum confirm --default=false "Activer le presse-papier partagé ?" && clipboard="true"
  fi

  local updated_json
  updated_json="$(echo "$prof" | jq \
    --arg host "$host" \
    --argjson port "${port:-3389}" \
    --arg username "$username" \
    --arg domain "$domain" \
    --arg share_path "$share_path" \
    --argjson sound "$sound" \
    --argjson microphone "$microphone" \
    --argjson clipboard "$clipboard" \
    '.host = $host | .port = $port | .username = $username | .domain = $domain | .share_path = $share_path | .sound = $sound | .microphone = $microphone | .clipboard = $clipboard')"

  config_save_profile "$updated_json"
  gum style --foreground 82 "✓ Profil '$target' mis à jour."
  sleep 1
}

ui_manage_password() {
  local names
  names="$(config_list_profiles)"
  if [[ -z "$names" ]]; then
    echo "Aucun profil disponible."
    return 0
  fi

  local target
  target="$(echo "$names" | fzf --height 40% --reverse --prompt="Gérer le credential pour quel profil ? > ")"
  if [[ -z "$target" ]]; then
    return 0
  fi

  local cred
  cred="$(gum input --password --placeholder "Nouveau mot de passe" --prompt "Credential : ")"
  if [[ -n "$cred" ]]; then
    keyring_set_password "$target" "$cred"
    gum style --foreground 82 "✓ Credential mis à jour dans le trousseau."
  else
    if gum confirm "Supprimer le credential enregistré du trousseau ?"; then
      keyring_delete_password "$target"
      gum style --foreground 214 "✓ Credential supprimé du trousseau."
    fi
  fi
  sleep 1
}

ui_delete_profile() {
  local names
  names="$(config_list_profiles)"
  if [[ -z "$names" ]]; then
    echo "Aucun profil à supprimer."
    return 0
  fi

  local target
  target="$(echo "$names" | fzf --height 40% --reverse --prompt="Supprimer quel profil ? > ")"
  if [[ -z "$target" ]]; then
    return 0
  fi

  if gum confirm --default=false "Confirmer la suppression définitive de '$target' ?"; then
    config_delete_profile "$target"
    keyring_delete_password "$target"
    gum style --foreground 82 "✓ Profil '$target' supprimé."
    sleep 1
  fi
}

ui_main_loop() {
  while true; do
    clear || true
    gum style \
      --border normal \
      --margin "1 0" \
      --padding "1 2" \
      --border-foreground 212 \
      "🖥️   omarchy-rdp" \
      "Gestionnaire de Sessions RDP pour Omarchy"

    local choice
    local options
    options="$(ui_build_menu_options)"
    
    if command -v fzf >/dev/null 2>&1; then
      choice="$(echo "$options" | fzf --height 50% --reverse --prompt="Rechercher ou sélectionner > " || true)"
    else
      choice="$(echo "$options" | gum choose --limit=1 || true)"
    fi

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
      "🚪  Quitter")
        clear || true
        exit 0
        ;;
      "➕  Nouveau profil")
        ui_new_profile
        ;;
      "✏️   Modifier un profil")
        ui_edit_profile
        ;;
      "🔑  Gérer le credential"|"🔑  Gérer un mot de passe")
        ui_manage_password
        ;;
      "🗑️   Supprimer un profil")
        ui_delete_profile
        ;;
      "🖥️   "*)
        local raw="${choice#🖥️   }"
        local name="${raw%%${DELIM}*}"
        # Detach session via systemd-run: closes this floating launcher window immediately!
        ui_launch_detached "$name"
        ;;
    esac
  done
}
