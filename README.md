# omarchy-rdp 🖥️

Gestionnaire de connexions Bureau à Distance (RDP) interactif, ultra-rapide et sécurisé, spécialement conçu pour **Omarchy Linux** (Arch Linux / Wayland / Hyprland).

---

## 🌟 Fonctionnalités

- **Interface TUI Réactive & Filtrage Instantané** : Menu interactif au clavier avec `fzf` et `gum` pour filtrer et lancer vos profils en 1 frappe.
- **Cycle de Vie Éphémère (Zero Clutter)** : Le Launcher se ferme immédiatement dès que la session démarre, ne laissant **aucune fenêtre de terminal flottante parasite** sur votre écran.
- **Watchdog de Récupération** : Si la session RDP échoue ou s'interrompt prématurément (< 3s), une notification système est envoyée et le Launcher se rouvre automatiquement.
- **Sécurité Maximale (Trousseau Linux)** : Vos identifiants sont chiffrés et stockés dans le Secret Service Linux (`secret-tool` / GNOME Keyring), jamais enregistrés en clair sur le disque.
- **Intégration Hyprland & Wayland** :
  - **Dynamic Resolution** : la résolution Windows s'adapte automatiquement au redimensionnement sous le tiling Hyprland.
  - **Détection automatique du Display Scale** : calcul du ratio à partir de l'écran focalisé (`hyprctl monitors`) et application automatique de `/scale:140` ou `/scale:180` sur les écrans HiDPI.
  - **Contournement du délai NLA Kerberos** : élimine le délai d'attente de 23 secondes propre à FreeRDP 3 sous Linux.
  - **Presse-papier partagé et Audio** activés par défaut.
  - **Redirection microphone et Shares locaux** optionnels par profil.
- **Intégration Système Omarchy** :
  - Lançable via le raccourci `Super + Espace` dans une fenêtre flottante centrée (`foot --app-id=omarchy-rdp`).
  - Commandes non-interactives en ligne de commande pour le scripting et les raccourcis personnalisés.

---

## 🚀 Installation

### Méthode 1 : Via l'AUR (Recommandé sous Arch / Omarchy)

```bash
yay -S omarchy-rdp
```

### Méthode 2 : Installation en une ligne (Script direct)

```bash
curl -fsSL https://raw.githubusercontent.com/PouletTendre/omarchy-rdp/main/install.sh | bash
```

### Méthode 3 : Installation manuelle depuis les sources

```bash
git clone https://github.com/PouletTendre/omarchy-rdp.git
cd omarchy-rdp
./install.sh
```

---

## 💡 Utilisation

### Mode Interactif (TUI)

Lancez simplement :

```bash
omarchy-rdp
```

Ou utilisez `Super + Espace` et cherchez **Omarchy RDP**.

### Commandes CLI

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

## 📦 Publication & Maintenance

Consultez [PUBLISHING.md](PUBLISHING.md) pour les instructions détaillées sur la publication sur GitHub et l'AUR.

---

## 🧪 Tests

Pour exécuter la suite de tests automatisée complète :

```bash
./tests/run_all_tests.sh
```

---

## 📄 Licence

MIT License - Copyright (c) 2026 PouletTendre
