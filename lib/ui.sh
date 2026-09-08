#!/usr/bin/env bash
# Terminal User Interface for omarchy-rdp using Gum and FZF

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
      echo "🖥️   $name ($user@$host:$port)"
    done <<< "$names"
  fi

  echo "➕  Nouveau profil"
  if [[ -n "$names" ]]; then
    echo "✏️   Modifier un profil"
    echo "🔑  Gérer un mot de passe"
    echo "🗑️   Supprimer un profil"
  fi
  echo "🚪  Quitter"
}

ui_connect() {
  local name="$1"
  local pass="${2:-}"

  local prof
  prof="$(config_get_profile "$name")"
  if [[ -z "$prof" || "$prof" == "null" ]]; then
    ui_notify_error "Profil '$name' introuvable."
    return 1
  fi

  if [[ -z "$pass" ]]; then
    pass="$(keyring_get_password "$name" || true)"
  fi

  if [[ -z "$pass" ]]; then
    if command -v gum >/dev/null 2>&1 && [[ -t 0 ]]; then
      local user
      user="$(echo "$prof" | jq -r '.username')"
      pass="$(gum input --password --placeholder "Mot de passe Windows pour $user")"
      if [[ -n "$pass" ]] && gum confirm --default=true "Mémoriser ce mot de passe dans le trousseau sécurisé ?"; then
        keyring_set_password "$name" "$pass"
      fi
    fi
  fi

  rdp_setup_krb5

  local -a args=()
  while IFS= read -r arg; do
    [[ -n "$arg" ]] && args+=("$arg")
  done < <(rdp_build_args "$prof" "$pass")

  clear || true
  echo "Connexion à $name..."
  xfreerdp3 "${args[@]}"
  local exit_code=$?

  if (( exit_code != 0 )); then
    ui_notify_error "La session '$name' a échoué (code de sortie: $exit_code)."
    return $exit_code
  fi
  return 0
}

ui_new_profile() {
  echo ""
  gum style --foreground 212 --bold "➕ Création d'un nouveau profil RDP"

  local name host port username domain sound microphone clipboard share_path pass
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

  share_path="$(gum input --placeholder "Répertoire local partagé (laisser vide si aucun)" --prompt "Dossier partagé : ")"
  pass="$(gum input --password --placeholder "Mot de passe (laisser vide pour demander à la connexion)" --prompt "Mot de passe : ")"

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
    '{name: $name, host: $host, port: $port, username: $username, domain: $domain, sound: $sound, microphone: $microphone, clipboard: $clipboard, share_path: $share_path, ignore_cert: $ignore_cert}')"

  config_save_profile "$prof_json"

  if [[ -n "$pass" ]]; then
    keyring_set_password "$name" "$pass"
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
  target="$(gum choose --header="Sélectionnez le profil à modifier" $names)"
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

  host="$(gum input --value "$host" --prompt "Hôte : ")"
  port="$(gum input --value "$port" --prompt "Port : ")"
  username="$(gum input --value "$username" --prompt "Utilisateur : ")"
  domain="$(gum input --value "$domain" --prompt "Domaine : ")"
  share_path="$(gum input --value "$share_path" --prompt "Dossier partagé : ")"

  local updated_json
  updated_json="$(echo "$prof" | jq \
    --arg host "$host" \
    --argjson port "${port:-3389}" \
    --arg username "$username" \
    --arg domain "$domain" \
    --arg share_path "$share_path" \
    '.host = $host | .port = $port | .username = $username | .domain = $domain | .share_path = $share_path')"

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
  target="$(gum choose --header="Gérer le mot de passe pour quel profil ?" $names)"
  if [[ -z "$target" ]]; then
    return 0
  fi

  local pass
  pass="$(gum input --password --placeholder "Nouveau mot de passe" --prompt "Mot de passe : ")"
  if [[ -n "$pass" ]]; then
    keyring_set_password "$target" "$pass"
    gum style --foreground 82 "✓ Mot de passe mis à jour dans le trousseau."
  else
    if gum confirm "Supprimer le mot de passe enregistré du trousseau ?"; then
      keyring_delete_password "$target"
      gum style --foreground 214 "✓ Mot de passe supprimé du trousseau."
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
  target="$(gum choose --header="Supprimer quel profil ?" $names)"
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
      "Gestionnaire de Connexions Bureau à Distance pour Omarchy"

    local choice
    choice="$(ui_build_menu_options | gum choose --limit=1 || true)"
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
      "🔑  Gérer un mot de passe")
        ui_manage_password
        ;;
      "🗑️   Supprimer un profil")
        ui_delete_profile
        ;;
      "🖥️   "*)
        # Extract profile name between "🖥️   " and " ("
        local raw="${choice#🖥️   }"
        local name="${raw%% (*}"
        ui_connect "$name"
        read -rsp "Appuyez sur Entrée pour revenir au menu..." || true
        ;;
    esac
  done
}
