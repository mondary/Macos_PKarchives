# Changelog

---

## TODO — Roadmap

Statut : `2026.09.22` (menu du status item attaché nativement)

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

### [2026.09.22] - 2026-09-24
#### Changed
- Le menu de l'icône 📦 est attaché nativement au status item (`statusItem.menu`), comme PKwindowsManagement : rendu système fiable (icône Ko-fi, alignements, surlignage). Le clic gauche ouvre désormais ce menu ; « Ouvrir PKarchives » reste le premier item.
- Suppression de la ligne Ko-fi en vue personnalisée et du chemin `popUp`, à l'origine des rendus cassés.

### [2026.09.21] - 2026-09-24
#### Fixed
- Le logo Ko-fi est embarqué en base64 dans le binaire (`KofiLogo.swift`) : plus aucune dépendance au fichier de ressources au runtime, c'est la vraie tasse Ko-fi qui s'affiche.
- La ligne Ko-fi est alignée sur les autres items du menu : icône à l'endroit exact où commence le texte des lignes classiques, libellé juste après.

### [2026.09.20] - 2026-09-24
#### Fixed
- La ligne « Soutenir sur Ko-fi » du menu clic droit devient une vue dédiée (bouton AppKit avec image cuite 18×18 et survol en surbrillance) : les `NSMenuItem.image` ne se rendent pas dans un menu `popUp` de status item sur macOS 26, une vraie `NSView` s'affiche dans tous les cas.

### [2026.09.19] - 2026-09-24
#### Fixed
- L'icône Ko-fi du menu clic droit est cuite en raster 18×18 (`isTemplate = false`) au lieu d'un simple redimensionnement, avec repli sur le symbole système `cup.and.saucer.fill` : elle s'affiche désormais à gauche du libellé « Soutenir sur Ko-fi ».

### [2026.09.18] - 2026-09-24
#### Added
- Onglet « ❤️ Soutenir » dans le panneau latéral : en-tête cœur, carte Ko-fi avec bouton « Donner », liens GitHub et signalement (calqué sur la page Support de PKwindowsManagement).

#### Fixed
- Chargement de l'icône Ko-fi du menu clic droit rendu infaillible (repli sur le chemin direct des ressources).
- L'appcast `appcast.xml` est publié sur `main` : « Rechercher les mises à jour » ne renvoie plus d'erreur.

### [2026.09.17] - 2026-09-24
#### Added
- Le menu clic droit de l'icône 📦 affiche le numéro de version en en-tête (non cliquable).
- L'item « Soutenir sur Ko-fi » porte la vraie icône Ko-fi (logo rouge, 16×16).

#### Fixed
- L'appcast `appcast.xml` existe à la racine du dépôt : Sparkle ne renvoie plus « Update Error » lors de la recherche de mises à jour (la version publiée y est décrite, la recherche répond « à jour » tant qu'aucune release ne dépasse la version installée).

### [2026.09.16] - 2026-09-24
#### Added
- Panneau latéral à onglets inspiré de PKwindowsManagement : **Réglages**, **À propos** (icône, version, mot de PK, licence) et **Librairie** (cartes des autres apps PK : PKwindowsManagement, PKbrain, PKMediaDownloader, PKpowerlines, PKmonitor).
- Carte Ko-fi avec bouton « Donner » dans l'onglet À propos.
- Item « Soutenir sur Ko-fi » toujours présent dans le menu clic droit de l'icône menu bar 📦.

### [2026.09.15] - 2026-09-24
#### Fixed
- L'icône 📦 réapparaît dans la barre des menus macOS : le `NSStatusItem` était déclaré mais jamais créé, l'application pouvait tourner de façon invisible (ni Dock, ni cmd-tab, ni menu bar).
- La barre d'actions du bas (Fichiers / Fichiers + dossiers, Historique, Archiver les éléments) est fixée en bas de fenêtre : plus besoin de faire défiler la liste pour archiver.

### [2026.09.14] - 2026-09-24
#### Fixed
- L'arborescence des dossiers du Bureau est préservée lors de l'archivage : chaque dossier part vers Drive avec ses sous-dossiers (`Dossier/sous-dossier/fichier`) au lieu d'être aplati à la racine du mois.
- Plus de lien symbolique `DesktopArchive` laissé sur le Bureau après le montage du Drive.
- Historique lisible : échelle adaptée et journal coloré remonté en haut.

#### Changed
- Interface v2 : style keeby sobre et friendly, CTA orange visible.

### [2026.09.13] - 2026-09-10
#### Added
- Mise à jour automatique de l’application macOS avec Sparkle et appcast GitHub.
- Workflow GitHub Actions pour signer et publier les releases taguées.

#### Changed
- Le script de build télécharge et embarque Sparkle dans l’application.

### [2026.09.12] - 2026-09-08
#### Added
- Bouton « Monter le Drive » : rclone mount déclenchable à la demande, sans attendre un archivage.
#### Changed
- Bascule clair/sombre (thème Vesper) via un bouton en en-tête, préférence persistée.
- Le thème Vesper devient une feuille de style désactivable (`<style id="vesper">`) au lieu d'être appliquée en dur.

### [2026.09.11] - 2026-09-08
#### Added
- Clic sur un fichier archivé dans le panneau Drive ouvre directement son lien Google Drive (URL transmise du script shell vers Swift vers JS).
#### Changed
- Thème Vesper appliqué à l'interface : fond sombre monochrome, typhographie SF Pro, ombres et contrastes adaptés.
- Bannière store (`store/assets/banner-1544x500.png`) en en-tête des README FR/EN.
- Nouvelles captures promo et gifs d'animation dans `store/`.
- Store landing page (`store/site/`) et media-kit ajoutés.

### [2026.09.10] - 2026-09-05
#### Added
- L'aperçu du fichier (miniature/extrait) atterrit dans le panneau « Archivé vers Drive » après l'upload : la carte archivée y reste visible avec son visuel, bordure verte et coche.
#### Changed
- Vraie icône Finder macOS (macosicons.com) à la place du SVG dessiné.

### [2026.09.09] - 2026-09-05
#### Changed
- Vraies icônes Finder et Google Drive (assets SVG embarqués) dans les cartes de route et les boutons.
- Les deux CTA « Ouvrir dans Finder » et « Ouvrir Drive » passent en couleur (bleu Finder, vert Google).
- Panneau Réglages réorganisé en sections (pattern des autres projets PK) : en-tête avec ✕, champs groupés, note de configuration et bouton Enregistrer en pied de panneau.
- Captures du store régénérées.

### [2026.09.08] - 2026-09-05
#### Changed
- Google Drive est monté dans `~/DesktopArchive` (visible dans le home) au lieu d'être monté dans le dossier Bureau ; le Bureau ne contient plus qu'un lien symbolique vers ce dossier — un nettoyage du Bureau ne peut plus affecter le Drive.
- README FR/EN synchronisés sur ce comportement.

### [2026.09.07] - 2026-09-05
#### Fixed
- Ligne en pointillés qui traversait tout l'écran au niveau du panneau cloud.
#### Changed
- Le panneau cloud devient une vraie destination : en-tête « Archivé vers Drive », compteur contextuel, et chaque fichier archivé y arrive comme une carte pendant que le fantôme vole du Bureau vers le panneau.
- Captures du store régénérées.

### [2026.09.06] - 2026-09-04
#### Fixed
- Remplissage de la vignette visible même pour les fichiers rapides : départ à 10 % dès le début de l'upload, complétion à 100 % à l'archivage.

### [2026.09.05] - 2026-09-04
#### Added
- La vignette se remplit du bas vers le haut pendant l'upload, comme un verre (remplace la micro-barre de progression).
- Dossier `store/` : laius de présentation FR/EN et captures d'écran, intégrées aux README.

#### Fixed
- Panneau Historique restait vide : le JS référençait un élément supprimé du HTML.
- Espace libéré formaté en Ko/Mo/Go au lieu de Ko bruts.

### [2026.09.04] - 2026-09-04
#### Added
- Historique annuel avec sélecteur d'année, histogramme mensuel et libellés des mois.
- Cartes de route avec icônes Finder/Drive, logo dans l'en-tête et numéro de version injecté depuis `VERSION` au build.

#### Changed
- L'historique complet est transmis à l'interface, le filtrage par période se fait côté interface.

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
