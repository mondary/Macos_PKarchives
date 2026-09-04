# PKarchives — Dossier du store

Matériel de présentation de l'application.
Captures : `store/screenshots/` (données de démo, desktop).

---

## Nom

**PKarchives**

## Tagline

**Votre Bureau, archivé vers Drive en un clic.**
*Your Desktop, archived to Drive in one click.*

## Description courte (≤ 150 caractères)

FR :
> Archive automatiquement le Bureau vers Google Drive via rclone : aperçu des fichiers, historique annuel, réglages partagés avec la CLI.

EN :
> Automatically archives your Desktop to Google Drive via rclone: file previews, yearly history, settings shared with the CLI.

## Description longue

### FR

**PKarchives** garde votre Bureau propre sans effort : un clic, et tous les fichiers éligibles partent dans votre Google Drive, rangés dans un dossier par mois, puis disparaissent du Bureau.

#### ✨ Ce que fait l'application

- **Vue source → destination** — le Bureau d'un côté, le dossier Drive de l'autre, avec le nombre d'éléments archivables en temps réel.
- **Cartes de fichiers avec aperçu** — miniatures pour les images, extrait lisible pour les textes, icônes pour le reste.
- **Suivi de transfert animé** — la vignette se remplit comme un verre pendant l'upload, la carte s'envole vers Drive quand c'est terminé.
- **Historique annuel** — histogramme mois par mois des fichiers archivés et de l'espace libéré, sélecteur d'année.
- **Deux modes** — fichiers seuls, ou fichiers + dossiers.
- **Réglages partagés avec la CLI** — ID du dossier Drive, chemin du Bureau, remote rclone : une seule configuration pour l'app et la ligne de commande.
- **Menu bar** — l'application vit dans la barre des menus et se lance au besoin.

#### 🔒 Sûr par conception

- Transferts via **rclone**, outil de référence pour Google Drive.
- Configuration externalisée (`secrets/.env`) : aucun identifiant dans le code.
- Suppression locale après upload : corbeille ou définitif, au choix.

### EN

**PKarchives** keeps your Desktop clean effortlessly: one click, and every eligible file goes to your Google Drive, sorted into a per-month folder, then disappears from your Desktop.

#### ✨ What the app does

- **Source → destination view** — Desktop on one side, Drive folder on the other, with a live count of archivable items.
- **File cards with previews** — thumbnails for images, readable excerpts for text files, icons for the rest.
- **Animated transfer tracking** — the thumbnail fills up like a glass during upload, then the card flies to Drive when done.
- **Yearly history** — month-by-month chart of archived files and freed space, with a year selector.
- **Two modes** — files only, or files + folders.
- **Settings shared with the CLI** — Drive folder ID, Desktop path, rclone remote: one configuration for both the app and the command line.
- **Menu bar** — the app lives in the menu bar and is ready when you need it.

#### 🔒 Safe by design

- Transfers powered by **rclone**, the reference tool for Google Drive.
- Externalized configuration (`secrets/.env`): no credentials in the code.
- Local deletion after upload: trash or permanent, your choice.

## Tags

`macos` `google-drive` `rclone` `desktop` `archivage` `menu-bar` `swift` `productivité`

## FAQ

### L'application supprime-t-elle mes fichiers ?
Après un upload confirmé, oui : c'est le but (libérer le Bureau). Vous choisissez la suppression corbeille (récupérable) ou définitive dans les réglages.

### Mes fichiers sont-ils rangés quelque part ?
Oui : un dossier par mois dans le dossier Drive configuré (ex. `2026_09_septembre`), rien n'est mis à plat.

### Ça marche sans rclone ?
L'app utilise le binaire rclone (`~/.local/share/pkarchives/bin/rclone` ou celui du système). Installez rclone et authentifiez votre Drive une fois.

### La CLI et l'app partagent quoi ?
La configuration (`secrets/.env`) et l'historique (`~/.config/pkarchives/history.json`) : les deux interfaces montrent le même état.

## Captures

| Fichier | Sujet |
|---------|-------|
| `screenshots/01-vue-principale.png` | Vue principale : source Bureau → destination Drive, cartes de fichiers |
| `screenshots/02-historique-annuel.png` | Panneau Historique annuel : stats + histogramme mensuel |
