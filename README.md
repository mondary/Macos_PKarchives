# PKarchives

![PKarchives — Un Bureau toujours net](store/media/banner-1544x500.png)

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

**Version du projet : 2026.10.34** · App disponible : 2026.10.30 · [Changelog](CHANGELOG.md) · [Licence MIT](LICENSE)

Archive du Bureau vers Google Drive via rclone, avec interface macOS et interface CLI/TUI.

![Démonstration animée de PKarchives](store/media/03-interface-dynamic.gif)

## Structure

```text
src/
├── macos/       # Application SwiftUI/menu bar
├── cli/         # Application Go/TUI
└── shared/      # Script d'archivage commun

release/
├── macos/       # PKarchives-<YYYY.MM.PATCH>.app
└── cli/         # Binaire pkarchives
```

## ✅ Fonctionnalités

- Menu bar native macOS (SwiftUI)
- Interface CLI/TUI Go
- Upload vers Google Drive via rclone
- Archivage par mois automatique (`YYYY_MM_mois`)
- Suppression auto après upload
- Support fichiers et dossiers
- Barre de progression en temps réel
- Réglages natifs avec recherche, langues, librairie de projets PK, soutien et informations de version
- À propos compare la version installée aux dernières builds Stable/Dev, avec statut par canal et vérification manuelle sur un flux actualisé
- Rubrique dédiée Crédits & inspirations, avec liens vers les outils, dépendances et projets référents

![Vue principale : le Bureau archivé vers Google Drive](store/media/01-promo-vue-principale.png)

## 🧠 Utilisation

### Premier setup (automatisé)

```bash
./scripts/setup.sh
```

Le script interactif vous guide pour :
1. Saisir votre Google Drive Folder ID
2. Configurer le dossier à archiver (défaut : `~/Desktop`)
3. Définir le remote rclone (défaut : `gdrive`)
4. Vérifier que rclone est installé et configuré
5. Build et lancer l'app

### L'app

Installée depuis le DMG ou le `.pkg` (voir Installation ci-dessous), l'app vit dans la barre
des menus. Pour compiler soi-même : `./scripts/build.sh`.

![Historique annuel des archivages](store/media/02-promo-historique-annuel.png)

## Installation — Mac Apple Silicon

- **DMG** : [Télécharger PKarchives pour Mac](https://github.com/mondary/Macos_PKarchives/releases/latest/download/PKarchives.dmg), puis ouvrir le DMG et glisser l'app dans Applications.
- **Installation directe** : [Télécharger l’installateur .pkg](https://github.com/mondary/Macos_PKarchives/releases/latest/download/PKarchives.pkg), puis double-cliquer sur le fichier.
- **Homebrew** : `brew install --cask mondary/tap/pkarchives`
- **curl** : `curl -fL https://github.com/mondary/Macos_PKarchives/releases/latest/download/PKarchives.pkg -o "$HOME/Downloads/PKarchives.pkg"`

Le build publié est pour Apple Silicon (arm64). L’app et l’installateur ne sont pas notariés ; macOS peut demander une autorisation à l’installation et au premier lancement.

### La CLI/TUI, partout dans le terminal

Une commande, puis `pkarchives` fonctionne depuis n'importe quel dossier :

```bash
curl -fsSL https://raw.githubusercontent.com/mondary/Macos_PKarchives/main/scripts/install-cli.sh | sh
pkarchives
```

## ⚙️ Configuration

La configuration est générée automatiquement par `scripts/setup.sh` dans `secrets/.env`.

### Variables disponibles

| Variable | Défaut | Description |
|----------|--------|-------------|
| `PKARCHIVES_DRIVE_FOLDER_ID` | *(obligatoire)* | ID du dossier Google Drive |
| `PKARCHIVES_DESKTOP_PATH` | `~/Desktop` | Dossier à archiver |
| `PKARCHIVES_DESKTOP_LINK_NAME` | `DesktopArchive` | Nom du volume monté |
| `PKARCHIVES_RCLONE_REMOTE` | `gdrive` | Nom du remote rclone |
| `PKARCHIVES_AUTO_MOUNT` | `1` | Monter le Drive automatiquement au lancement (`0` pour désactiver) |

Le Drive est monté dans `~/DesktopArchive` (volume Finder « DesktopArchive », volontairement hors du Bureau pour que la suppression des fichiers du Bureau ne puisse jamais traverser vers le Drive). Le montage est tenté automatiquement au lancement de l'app, puis après chaque archivage réussi.

## 🧾 Prérequis

- macOS 14.0+
- rclone (`brew install rclone`)
- Remote rclone configuré

## 📦 Build

```bash
./scripts/build.sh
```

## Licence

PKarchives est distribué sous licence [MIT](LICENSE), qui autorise notamment l'usage commercial et la redistribution sous réserve de conserver la notice de copyright et de licence.

## 📋 Voir le [CHANGELOG](CHANGELOG.md) pour l'historique complet

## 🔗 Liens

- [Landing](store/website/index.html) · [film de présentation](store/media/ultracrea2-promo.mp4) · [anciennes versions](store/archive)
- [Google Drive](https://drive.google.com)
- [rclone](https://rclone.org/)
- ❤️ Soutenir ce projet sur [Ko-fi](https://ko-fi.com/pouark)
