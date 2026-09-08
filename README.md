# omarchy-rdp

Gestionnaire interactif de connexions Bureau à Distance (RDP) optimisé pour Omarchy Linux (Arch Linux / Wayland / Hyprland).

---

## Fonctionnalités

- **Interface TUI au clavier** : Recherche et filtrage instantanés des profils de connexion via `fzf` et formulaires interactifs via `gum`.
- **Fenêtre éphémère** : Fermeture immédiate du terminal lanceur lors du démarrage de la session RDP pour éviter les fenêtres résiduelles sous Hyprland.
- **Surveillance de session** : Détection des sorties prématurées (< 3s) ou des échecs de connexion, notification sur le bureau et réouverture automatique de l'interface.
- **Stockage sécurisé des identifiants** : Les mots de passe sont conservés dans le trousseau de clés Linux (`secret-tool` / Secret Service) et ne sont jamais enregistrés en clair.
- **Optimisations Wayland & Hyprland** :
  - Résolution dynamique adaptée aux redimensionnements de fenêtres.
  - Calcul et transmission automatique du facteur d'échelle (`/scale`) d'après l'écran focalisé (`hyprctl monitors`).
  - Contournement de la latence NLA/Kerberos de FreeRDP 3.
  - Presse-papier partagé, redirection audio, microphone et dossiers locaux.
- **Intégration système** :
  - Raccourci `Super + Espace` (lanceur d'applications) avec règle de fenêtrage flottante dédiée.
  - Commandes non-interactives en ligne de commande pour l'automatisation et les scripts.

---

## Prérequis

Les dépendances système requises sont :
- `bash` (>= 4.4)
- `jq`
- `gum`
- `fzf`
- `freerdp` (FreeRDP 3 / `xfreerdp3`)
- `libsecret` (`secret-tool`)
- `foot`

Sous Arch Linux / Omarchy, installez-les via :

```bash
sudo pacman -S bash jq gum fzf freerdp libsecret foot
```

---

## Installation

### Méthode 1 : Paquet AUR (recommandé)

```bash
yay -S omarchy-rdp
```

### Méthode 2 : Script autonome en ligne de commande

```bash
curl -fsSL https://raw.githubusercontent.com/PouletTendre/omarchy-rdp/main/install.sh | bash
```

### Méthode 3 : Installation depuis les sources

```bash
git clone https://github.com/PouletTendre/omarchy-rdp.git
cd omarchy-rdp
./install.sh
```

---

## Désinstallation

### Paquet AUR

Si vous avez installé `omarchy-rdp` via l'AUR ou `pacman` :

```bash
yay -R omarchy-rdp
# ou
sudo pacman -R omarchy-rdp
```

### Installation par script

Si vous avez utilisé le script d'installation :

- **Depuis le dépôt local cloné :**

  ```bash
  ./uninstall.sh
  ```

- **À distance via curl :**

  ```bash
  curl -fsSL https://raw.githubusercontent.com/PouletTendre/omarchy-rdp/main/uninstall.sh | bash
  ```

- **Suppression complète incluant profils et mots de passe (`--purge`) :**

  Par défaut, les profils de connexion (`~/.config/omarchy-rdp`) et les identifiants stockés dans le trousseau sont conservés. Pour supprimer également toutes les données utilisateur :

  ```bash
  ./uninstall.sh --purge
  # ou via curl :
  curl -fsSL https://raw.githubusercontent.com/PouletTendre/omarchy-rdp/main/uninstall.sh | bash -s -- --purge
  ```

---

## Utilisation

### Mode interactif (TUI)

Lancez l'interface interactive :

```bash
omarchy-rdp
```

L'application est également accessible depuis le lanceur système via `Super + Espace` en recherchant **Omarchy RDP**.

### Commandes CLI

```bash
# Lister les profils enregistrés
omarchy-rdp --list

# Se connecter directement à un profil
omarchy-rdp --connect "Mon Profil"

# Afficher les arguments FreeRDP 3 générés (sans mot de passe)
omarchy-rdp --get-args "Mon Profil"

# Définir le mot de passe d'un profil dans le trousseau
omarchy-rdp --set-password "Mon Profil" "MonMotDePasse"

# Supprimer un profil et ses identifiants associés
omarchy-rdp --delete "Mon Profil"
```

---

## Architecture

- `bin/omarchy-rdp` : point d'entrée exécutable, gestionnaire de cycle de vie et mode non-interactif.
- `lib/config.sh` : gestion du magasin de profils JSON (`~/.config/omarchy-rdp/profiles.json`).
- `lib/keyring.sh` : interface avec le trousseau Secret Service (`secret-tool`).
- `lib/rdp.sh` : détection d'affichage Hyprland et construction des arguments FreeRDP 3.
- `lib/ui.sh` : interface utilisateur TUI (`gum` et `fzf`).
- `docs/adr/` : fiches de décisions architecturales (Architecture Decision Records).

---

## Tests

Pour exécuter la suite de tests d'intégration automatisée :

```bash
./tests/run_all_tests.sh
```

---

## Licence

MIT License. Voir [LICENSE](LICENSE) pour plus de détails.
