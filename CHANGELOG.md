# Changelog

---

## TODO — Roadmap

Statut : `2026.09.03` (dashboard V2)

### Sécurité & Publication GitHub
- [x] Supprimer les binaire compilé et .app du repo
- [x] Ajouter .gitignore complet (secrets, build artifacts, IDE, OS)
- [x] Externaliser le Google Drive Folder ID dans secrets/.env
- [x] Externaliser le remote rclone, le chemin du Bureau, le nom du symlink
- [x] Rendre le fichier /tmp prédictible (PID-based)
- [x] Supprimer les chemins personnels hardcodés
- [ ] README FR + EN synchronisé
- [ ] Lien vers CHANGELOG dans README
- [x] Dashboard SwiftUI et TUI avec statistiques et historique
- [x] Graphique d'activité des archivages
- [x] Navigation paramètres/historique dans les deux interfaces

---

## Releases

### [2026.09.03] - 2026-09-04
#### Fixed
- Clic gauche sur l'icône menu ouvre l'application, clic droit affiche le menu contextuel.

### [2026.09.02] - 2026-09-04
#### Added
- Journal mensuel v2 avec statistiques et histogramme des archivages.
- Rafraîchissement automatique du scan après interaction dans l’application.

#### Changed
- Version affichée au format `YYYY.MM.PATCH`.

#### Fixed
- Détection des exclusions Finder et des fichiers cachés alignée sur `archive.sh`.

### [🔥v1.2026.2] - 2026-07-22
#### Added
- Dashboard TUI Go inspiré de Riptide avec menu, cartes, historique et sparkline
- Dashboard SwiftUI avec statistiques, graphique d'activité et historique
- Historique JSON partagé dans `~/.config/pkarchives/history.json`
- Paramètres éditables dans les deux interfaces

#### Changed
- Les deux interfaces affichent désormais le même état d'archivage
- Structure séparée `src/macos`, `src/cli`, `src/shared` et `release/macos`, `release/cli`

#### Fixed
- Format d'historique Swift aligné sur celui du CLI Go

### [🔥v1.2026.1] - 2026-07-21
#### Added
- App SwiftUI menu bar pour archiver le Bureau vers Google Drive
- Script bash archive.sh avec upload rclone et suppression auto
- Fichier secrets/.env pour la configuration sensible
- Fichier secrets/.env.example comme template
- Lecture de la config via env vars ou secrets/.env

#### Changed
- Toute la config sensible externalisée (Drive Folder ID, remote rclone, etc.)
- Fichier /tmp renommé avec PID pour éviter les attaques par symlink
- Recherche du script: env var > app bundle > ~/.config/pkarchives/

#### Fixed
- Suppression du binaire compilé et du .app bundle du repo
- .gitignore complet (secrets/, release/, *.app/, .vscode/, etc.)
- Suppression des chemins personnels hardcodés (Documents/GitHub/...)
