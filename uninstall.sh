#!/usr/bin/env bash
# Uninstallation script for omarchy-rdp

set -euo pipefail

PURGE=false
for arg in "$@"; do
  if [[ "$arg" == "--purge" ]]; then
    PURGE=true
  fi
done

echo "=== Désinstallation de omarchy-rdp ==="

BIN_TARGET="$HOME/.local/bin/omarchy-rdp"
DESKTOP_FILE="$HOME/.local/share/applications/omarchy-rdp.desktop"
INSTALL_BASE="$HOME/.local/share/omarchy-rdp"
CONFIG_DIR="$HOME/.config/omarchy-rdp"
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"

# 1. Suppression du lien exécutable
if [[ -L "$BIN_TARGET" || -f "$BIN_TARGET" ]]; then
  rm -f "$BIN_TARGET"
  echo "✓ Exécutable supprimé : $BIN_TARGET"
else
  echo "- Aucun exécutable trouvé dans $BIN_TARGET"
fi

# 2. Suppression du fichier desktop et rafraîchissement
if [[ -f "$DESKTOP_FILE" ]]; then
  rm -f "$DESKTOP_FILE"
  echo "✓ Fichier .desktop supprimé : $DESKTOP_FILE"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$(dirname "$DESKTOP_FILE")" 2>/dev/null || true
  fi
else
  echo "- Aucun fichier desktop trouvé dans $DESKTOP_FILE"
fi

# 3. Suppression du répertoire d'installation autonome si présent
if [[ -d "$INSTALL_BASE" ]]; then
  rm -rf "$INSTALL_BASE"
  echo "✓ Répertoire d'installation supprimé : $INSTALL_BASE"
fi

# 4. Retrait de la règle de fenêtrage Hyprland
if [[ -f "$HYPR_LUA" ]] && grep -q "omarchy-rdp" "$HYPR_LUA"; then
  temp_lua="$(mktemp)"
  grep -v -E '(omarchy-rdp|-- Règle de fenêtre pour omarchy-rdp)' "$HYPR_LUA" > "$temp_lua" || true
  mv "$temp_lua" "$HYPR_LUA"
  echo "✓ Règle de fenêtre retirée de $HYPR_LUA"
fi

# 5. Gestion des profils et identifiants
if [[ "$PURGE" == "true" ]]; then
  if [[ -d "$CONFIG_DIR" ]]; then
    rm -rf "$CONFIG_DIR"
    echo "✓ Configuration et profils supprimés : $CONFIG_DIR"
  fi
  if command -v secret-tool >/dev/null 2>&1; then
    secret-tool clear service "omarchy-rdp" 2>/dev/null || true
    echo "✓ Identifiants du trousseau de clés révoqués"
  fi
else
  if [[ -d "$CONFIG_DIR" ]]; then
    echo "ℹ️  Les profils de configuration ont été conservés dans $CONFIG_DIR"
    echo "   Pour supprimer également les profils et les identifiants, utilisez : --purge"
  fi
fi

echo ""
echo "✓ Désinstallation terminée."
