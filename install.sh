#!/usr/bin/env bash
# Installation script for omarchy-rdp

set -euo pipefail

REPO_URL="https://github.com/PouletTendre/omarchy-rdp"
RAW_URL="https://raw.githubusercontent.com/PouletTendre/omarchy-rdp/main"

# Safe script directory detection (supports both local git clone and curl | bash pipe)
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  LOCAL_REPO_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
else
  LOCAL_REPO_DIR=""
fi

echo "=== Installation de omarchy-rdp ==="

# 1. Verification des dépendances
echo "Vérification des dépendances système..."
deps=(jq gum fzf xfreerdp3 secret-tool foot)
missing=()
for dep in "${deps[@]}"; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    missing+=("$dep")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "⚠️  Attention : les dépendances suivantes sont manquantes : ${missing[*]}"
  echo "   Installez-les via pacman (ex: sudo pacman -S ${missing[*]})"
else
  echo "✓ Toutes les dépendances sont installées."
fi

# 2. Emplacements d'installation
INSTALL_BASE="$HOME/.local/share/omarchy-rdp"
BIN_TARGET_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$BIN_TARGET_DIR" "$DESKTOP_DIR"

if [[ -n "$LOCAL_REPO_DIR" && -d "$LOCAL_REPO_DIR/bin" && -d "$LOCAL_REPO_DIR/lib" ]]; then
  # Local clone mode: link directly to development/repo directory
  SOURCE_DIR="$LOCAL_REPO_DIR"
  echo "Installation depuis le dépôt local ($SOURCE_DIR)..."
else
  # Remote curl | bash mode: download files to ~/.local/share/omarchy-rdp
  SOURCE_DIR="$INSTALL_BASE"
  echo "Installation distante dans $SOURCE_DIR..."
  mkdir -p "$SOURCE_DIR/bin" "$SOURCE_DIR/lib" "$SOURCE_DIR/desktop"
  
  curl -fsSL "$RAW_URL/bin/omarchy-rdp" -o "$SOURCE_DIR/bin/omarchy-rdp"
  curl -fsSL "$RAW_URL/lib/config.sh" -o "$SOURCE_DIR/lib/config.sh"
  curl -fsSL "$RAW_URL/lib/keyring.sh" -o "$SOURCE_DIR/lib/keyring.sh"
  curl -fsSL "$RAW_URL/lib/rdp.sh" -o "$SOURCE_DIR/lib/rdp.sh"
  curl -fsSL "$RAW_URL/lib/ui.sh" -o "$SOURCE_DIR/lib/ui.sh"
  curl -fsSL "$RAW_URL/desktop/omarchy-rdp.desktop" -o "$SOURCE_DIR/desktop/omarchy-rdp.desktop"
  chmod +x "$SOURCE_DIR/bin/omarchy-rdp" "$SOURCE_DIR/lib/"*.sh
fi

# 3. Lien exécutable
ln -sf "$SOURCE_DIR/bin/omarchy-rdp" "$BIN_TARGET_DIR/omarchy-rdp"
chmod +x "$BIN_TARGET_DIR/omarchy-rdp"
echo "✓ Exécutable installé : $BIN_TARGET_DIR/omarchy-rdp"

# 4. Fichier desktop
cp "$SOURCE_DIR/desktop/omarchy-rdp.desktop" "$DESKTOP_DIR/omarchy-rdp.desktop"
echo "✓ Fichier .desktop installé : $DESKTOP_DIR/omarchy-rdp.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# 5. Règle de fenêtrage Hyprland
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
RULE_LINE='o.window("^(omarchy-rdp)$", { float = true, center = true, size = { 850, 650 } })'

if [[ -f "$HYPR_LUA" ]]; then
  if ! grep -q "omarchy-rdp" "$HYPR_LUA"; then
    echo "" >> "$HYPR_LUA"
    echo "-- Règle de fenêtre pour omarchy-rdp" >> "$HYPR_LUA"
    echo "$RULE_LINE" >> "$HYPR_LUA"
    echo "✓ Règle Hyprland ajoutée à $HYPR_LUA"
  else
    echo "✓ Règle Hyprland déjà présente dans $HYPR_LUA"
  fi
fi

echo ""
echo "🎉 Installation terminée avec succès !"
echo "Vous pouvez lancer l'application via :"
echo "  - Terminal : omarchy-rdp"
echo "  - Raccourci : Super + Espace -> 'Omarchy RDP'"
