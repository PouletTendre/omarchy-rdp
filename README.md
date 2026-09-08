# omarchy-rdp 🖥️

Gestionnaire de connexions Bureau à Distance (RDP) interactif et ultra-rapide pour **Omarchy Linux** (Arch Linux / Hyprland).

---

## 🌟 Fonctionnalités

- **Interface TUI Réactive** : Menu interactif au clavier (`gum` & `fzf`) avec sélection instantanée et Quick-Connect.
- **Sécurité Maximale (Trousseau Linux)** : Vos mots de passe sont stockés et chiffrés dans le Secret Service Linux (`secret-tool` / GNOME Keyring), jamais écrits en clair sur le disque.
- **Intégration Hyprland & Wayland** :
  - **Dynamic Resolution** : adaptation automatique de la résolution lors du redimensionnement de la fenêtre.
  - **Détection automatique du Display Scale** : calcul du facteur d'échelle à partir de l'écran focalisé (`hyprctl monitors`) et application automatique de `/scale:140` ou `/scale:180` sur les écrans HiDPI.
  - **Contournement du délai NLA Kerberos** : élimine le délai d'attente de 23 secondes lié aux requêtes DNS KDC de FreeRDP 3 sous Linux.
  - **Presse-papier partagé et Audio** activés par défaut.
  - **Redirection microphone et partage de dossiers locaux** optionnels par profil.
- **Intégration Système Omarchy** :
  - Lançable via le raccourci Omarchy `Super + Espace` dans une fenêtre flottante centrée (`foot --app-id=omarchy-rdp`).
  - Commandes non-interactives en ligne de commande pour scripts et raccourcis personnalisés.

---

## 🚀 Installation

Exécutez le script d'installation :

```bash
./install.sh
```

Le script :
1. Vérifie les dépendances système (`jq`, `gum`, `fzf`, `xfreerdp3`, `secret-tool`, `foot`).
2. Crée un lien symbolique vers `~/.local/bin/omarchy-rdp`.
3. Installe le lanceur `.desktop` dans `~/.local/share/applications/`.
4. Ajoute la règle de fenêtrage flottante dans `~/.config/hypr/hyprland.lua`.

---

## 💡 Utilisation

### Mode Interactif (TUI)

Lancez simplement :

```bash
omarchy-rdp
```

Ou utilisez `Super + Espace` et cherchez **Omarchy RDP**.

### Commandes CLI (Scripting / Raccourcis)

```bash
# Lister les profils enregistrés
omarchy-rdp --list

# Se connecter directement à un profil
omarchy-rdp --connect "Mon PC Bureau"

# Afficher les arguments FreeRDP 3 générés
omarchy-rdp --get-args "Mon PC Bureau"

# Définir un mot de passe dans le trousseau de clés
omarchy-rdp --set-password "Mon PC Bureau" "MonMotDePasse"

# Supprimer un profil et ses identifiants
omarchy-rdp --delete "Mon PC Bureau"
```

---

## 🧪 Tests

Pour exécuter la suite de tests complète :

```bash
./tests/run_all_tests.sh
```
