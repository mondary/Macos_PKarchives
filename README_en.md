# PKarchives

![Project icon](icon.png)

[🇫🇷 FR](README.md) · [🇬🇧 EN](README_en.md)

Archive your Desktop to Google Drive via rclone, with a native macOS menu bar app.

## ✅ Features

- Native macOS menu bar (SwiftUI)
- Upload to Google Drive via rclone
- Automatic monthly archiving (`YYYY_MM_month`)
- Auto-delete after upload
- Files and folders support
- Real-time progress bar

## 🧠 Usage

### App
```bash
open build/PKarchives.app
```

### Script
```bash
./src/archive.sh files      # Files only
./src/archive.sh all        # Files + folders
```

## ⚙️ Configuration

1. Copy `secrets/.env.example` → `secrets/.env`
2. Fill in `PKARCHIVES_DRIVE_FOLDER_ID` with your Google Drive folder ID

```bash
cp secrets/.env.example secrets/.env
# Edit secrets/.env with your Drive Folder ID
```

### Available variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PKARCHIVES_DRIVE_FOLDER_ID` | *(required)* | Google Drive folder ID |
| `PKARCHIVES_DESKTOP_PATH` | `~/Desktop` | Folder to archive |
| `PKARCHIVES_DESKTOP_LINK_NAME` | `DesktopArchive` | Symlink to exclude |
| `PKARCHIVES_RCLONE_REMOTE` | `gdrive` | rclone remote name |

## 🧾 Requirements

- macOS 14.0+
- rclone (`brew install rclone`)
- rclone remote configured

## 📦 Build

```bash
./build.sh
```

## 📋 See [CHANGELOG](CHANGELOG.md) for full history

## 🔗 Links

- [Google Drive](https://drive.google.com)
- [rclone](https://rclone.org/)
