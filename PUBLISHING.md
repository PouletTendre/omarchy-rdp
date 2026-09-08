# Guide de Publication : GitHub & AUR 📦

Ce guide explique pas-à-pas comment publier `omarchy-rdp` sur votre compte GitHub et sur le dépôt officiel **AUR (Arch User Repository)** pour le rendre accessible à tous les utilisateurs d'Omarchy et d'Arch Linux via `yay -S omarchy-rdp`.

---

## 1. Publication sur GitHub

### Étape 1.1 : Authentification GitHub
Si vous n'êtes pas encore connecté à GitHub en ligne de commande :

```bash
gh auth login
```
*(Suivez les instructions à l'écran en choisissant GitHub.com -> SSH ou HTTPS -> Connexion via le navigateur)*

### Étape 1.2 : Création du dépôt public et premier Push

Dans le dossier du projet :

```bash
# Créer le dépôt public sur votre compte GitHub et pousser le code
gh repo create PouletTendre/omarchy-rdp --public --source=. --remote=origin --push
```

*(Ou si vous créez le dépôt manuellement sur github.com :)*
```bash
git push -u origin master
```

### Étape 1.3 : Créer la Release v1.0.0

```bash
git tag -a v1.0.0 -m "Release 1.0.0: Initial release of omarchy-rdp"
git push origin v1.0.0
```

---

## 2. Publication sur l'AUR (Arch User Repository)

Le nom de paquet `omarchy-rdp` est **100% disponible et libre** sur l'AUR.

### Étape 2.1 : Prérequis AUR
1. Créez un compte sur [aur.archlinux.org](https://aur.archlinux.org/register) si ce n'est pas déjà fait.
2. Dans vos paramètres de compte AUR, ajoutez votre clé publique SSH (`~/.ssh/id_ed25519.pub` ou générez-en une avec `ssh-keygen -t ed25519`).

### Étape 2.2 : Cloner le dépôt AUR vide

```bash
cd /tmp
git clone ssh://aur@aur.archlinux.org/omarchy-rdp.git
cd omarchy-rdp
```

### Étape 2.3 : Copier les fichiers de paquet préparés

Depuis le dossier de votre projet `Rdp-App` :

```bash
cp /home/noah/Work/Rdp-App/packaging/aur/PKGBUILD .
cp /home/noah/Work/Rdp-App/packaging/aur/.SRCINFO .
```

*(Facultatif : tester la construction locale du paquet)*
```bash
makepkg -si
```

### Étape 2.4 : Pousser sur l'AUR

```bash
git add PKGBUILD .SRCINFO
git commit -m "Initial release of omarchy-rdp 1.0.0"
git push origin master
```

🎉 **C'est tout !** 
Le paquet `omarchy-rdp` sera immédiatement indexé par l'AUR. Tous les utilisateurs pourront désormais installer votre application via :

```bash
yay -S omarchy-rdp
```
