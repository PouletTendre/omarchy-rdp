#!/usr/bin/env bash
# Installation script for omarchy-rdp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# 2. Installation de l'exécutable
BIN_TARGET_DIR="$HOME/.local/bin"
mkdir -p "$BIN_TARGET_DIR"

ln -sf "$SCRIPT_DIR/bin/omarchy-rdp" "$BIN_TARGET_DIR/omarchy-rdp"
chmod +x "$BIN_TARGET_DIR/omarchy-rdp"
echo "✓ Lien créé : $BIN_TARGET_DIR/omarchy-rdp -> $SCRIPT_DIR/bin/omarchy-rdp"

# 3. Installation du lanceur d'applications .desktop
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"
cp "$SCRIPT_DIR/desktop/omarchy-rdp.desktop" "$DESKTOP_DIR/omarchy-rdp.desktop"
echo "✓ Fichier .desktop installé : $DESKTOP_DIR/omarchy-rdp.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# 4. Règle de fenêtrage Hyprland
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
echo "🎉 Installation terminée !"
echo "Vous pouvez lancer l'application via :"
echo "  - Terminal : omarchy-rdp"
echo "  - Raccourci : Super + Espace -> 'Omarchy RDP'"
