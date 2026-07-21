# PKarchives

![Project icon](icon.png)

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

Archive du Bureau vers Google Drive via rclone, avec interface native macOS (menu bar).

## ✅ Fonctionnalités

- Menu bar native macOS (SwiftUI)
- Upload vers Google Drive via rclone
- Archivage par mois automatique (`YYYY_MM_mois`)
- Suppression auto après upload
- Support fichiers et dossiers
- Barre de progression en temps réel

## 🧠 Utilisation

### App
```bash
# Depuis le binaire compilé
open build/PKarchives.app
```

### Script
```bash
./src/archive.sh files      # Fichiers seulement
./src/archive.sh all        # Fichiers + dossiers
```

## ⚙️ Configuration

1. Copier `secrets/.env.example` → `secrets/.env`
2. Remplir `PKARCHIVES_DRIVE_FOLDER_ID` avec l'ID de votre dossier Google Drive

```bash
cp secrets/.env.example secrets/.env
# Éditer secrets/.env avec votre Drive Folder ID
```

### Variables disponibles

| Variable | Défaut | Description |
|----------|--------|-------------|
| `PKARCHIVES_DRIVE_FOLDER_ID` | *(obligatoire)* | ID du dossier Google Drive |
| `PKARCHIVES_DESKTOP_PATH` | `~/Desktop` | Dossier à archiver |
| `PKARCHIVES_DESKTOP_LINK_NAME` | `DesktopArchive` | Symlink à exclure |
| `PKARCHIVES_RCLONE_REMOTE` | `gdrive` | Nom du remote rclone |

## 🧾 Prérequis

- macOS 14.0+
- rclone (`brew install rclone`)
- Remote rclone configuré

## 📦 Build

```bash
./build.sh
```

## 📋 Voir le [CHANGELOG](CHANGELOG.md) pour l'historique complet

## 🔗 Liens

- [Google Drive](https://drive.google.com)
- [rclone](https://rclone.org/)
