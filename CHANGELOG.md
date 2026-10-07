# Changelog

---

## TODO — Roadmap

Statut : `2026.09.25` (landing Ultra Crea 3, palette teal du fond fourni)

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

### [2026.10.27] - 2026-10-07
#### Added
- Fenêtre native de réglages inspirée du shell PK : navigation filtrable, réglages d’archivage, choix de langue, Project Library, soutien et À propos.
- Accès aux réglages depuis l’icône de la barre de menus et le bouton de l’interface.
- Ciblage explicite des actions AppKit et menu réordonné avec icônes, Ko-fi et À propos.
#### Changed
- Project Library, Soutenir et À propos reprennent les composants visuels PKmonitor ; cartes, captures, traductions et liens vérifiés sont embarqués dans l’app.
- Le build copie maintenant les visuels et le logo Ko-fi dans les ressources du bundle.
- Réglages, À propos et Project Library basculent dans l’unique fenêtre principale ; le lancement et « Retour à l’archive » ramènent à l’interface d’archivage.
- Canaux Sparkle Stable/Dev : appcasts distincts, Dev publié automatiquement depuis `main`, installation automatique des builds Dev et identifiants de build epoch pour comparer les deux canaux.
- Suppression de la scène SwiftUI `Settings` vide à l’entrée de l’app : AppKit gère l’unique fenêtre principale sans fenêtre de réglages fantôme au lancement.

---

## Releases

### [2026.10.21] - 2026-10-01
#### Added
- Installation CLI/TUI en une commande : `curl …/scripts/install-cli.sh | sh`, puis `pkarchives` depuis n'importe quel dossier. Binaire Apple Silicon ajouté à la release GitHub.
- `scripts/build-standalone.sh` génère à la demande une landing HTML autonome (images et vidéo inline, environ 3,6 Mo).
#### Changed
- README FR/EN simplifiés : retrait des commandes qui pointaient vers `release/` ignoré par Git et du script manuel réservé au dépôt cloné.
- Landing déplacée dans `store/website/` selon la réorganisation locale ; liens README et `PKSTACK.md` réalignés.


### [2026.10.20] - 2026-10-01
#### Fixed
- `film-poster.jpg` ajouté au bundle `website/PKarchives/media/` : l'affiche du film (attribut `poster`) manquait au dossier déployable.

### [2026.10.19] - 2026-10-01
#### Changed
- La landing vit désormais dans `website/PKarchives/` à la racine : dossier unique suivi par git, à la fois source et bundle FTP déployable (upload = envoyer le dossier `PKarchives/`). Suppression de `store/index.html` et de `scripts/website.sh`, fin de l'ignore git. Convention `website/<NomDuProjet>/` consignée dans la skill `premium-promo-media`.

### [2026.10.18] - 2026-10-01
#### Changed
- Bundle de déploiement FTP `store/website/PKarchives/` : un dossier nommé par projet, régénéré par `scripts/website.sh` et exclu du dépôt — la landing n'existe qu'en un exemplaire (`store/index.html`), plus de copie en double dans git. Convention consignée dans la skill `premium-promo-media`.

### [2026.10.17] - 2026-10-01
#### Added
- `store/website/` : bundle de déploiement FTP autonome (index.html + media/background.jpg + media/ultracrea2-promo.mp4, ~1,9 Mo) avec son README de maintenance.

### [2026.10.16] - 2026-10-01
#### Fixed
- Lien licence du pied de page redirigé vers le `LICENSE` GitHub : le déploiement FTP autonome de la landing n'a plus de 404.

### [2026.10.15] - 2026-10-01
#### Changed
- `PKSTACK` renommé en `PKSTACK.md` pour un rendu Markdown correct sur GitHub.

### [2026.10.14] - 2026-10-01
#### Added
- Fichier `PKSTACK` à la racine : cartographie des skills du hub utilisées sur le projet (landing, release, cask, convention, accessibilité, Sparkle) et de leurs livrables.

### [2026.10.13] - 2026-10-01
#### Changed
- Store : options d'installation DMG, Homebrew et PKG/curl regroupées et alignées ; FAQ déployée sur toute la largeur.
- Barre macOS de démonstration : icône 📦 avant le Wi-Fi, menu ancré sur l'icône et flèche seule qui disparaît à l'ouverture.
- Icône Ko-fi blanche sur le bouton rouge et simulation du hero agrandie.
- README FR/EN : le GIF reste en tête, les deux captures sont réparties dans les sections Fonctionnalités et Utilisation.
- Tasse Ko-fi blanche et cliquable dans la barre de menu de la landing, à côté de l'icône 📦.
- Mini-démo du hero en deux zones : chaque fichier se charge à gauche (Bureau) puis vole visiblement vers la zone droite (Drive) où il atterrit ; compteurs synchronisés.
- Actions du hero réorganisées : bouton principal Télécharger le DMG, puis deux liens discrets « Essayer la démo interactive » et « Soutenir sur Ko-fi » sous forme de puces icône + texte.
#### Fixed
- Liens DMG et PKG directs et versionnés pour la release d'application `2026.10.12`.

### [2026.10.12] - 2026-10-01
#### Changed
- Landing `store/index.html` : flèche dessinée persistante vers le menu 📦, téléchargement direct du DMG et installateur `.pkg` en double-clic ; commandes `brew` / `curl` copiables.
- Pipeline de release versionnée pour DMG et installateur `.pkg` Apple Silicon ; le cask Homebrew sera publié avec le SHA-256 du DMG final.
- Licence MIT déclarée dans `LICENSE` à la racine et dans les README FR/EN. Le feed Sparkle invalide (signature placeholder, taille nulle) est neutralisé ; aucune mise à jour Sparkle n'est annoncée sans ZIP EdDSA signé.
#### Fixed
- Les boutons DMG et `.pkg` vérifient les assets GitHub réels, tandis que les commandes de `curl` et Homebrew sont copiables.

### [2026.10.10] - 2026-10-01
#### Changed
- Landings archivées simplifiées : `v1.html`, `v2.html` et `v3.html` directement dans `store/archive/site/`; assets et pipeline V2 rangés dans `store/archive/media-kit/ultracrea2-film/`.
- Variantes vidéo conservées déplacées dans `store/archive/screenshots/` à la demande ; les GIF et vidéos déjà supprimés par l'utilisateur restent supprimés. Suppression des pages 404/privacy/terms demandée.
#### Fixed
- Chemins médias de V2 réparés et liens supprimés vers privacy/terms retirés de V3 ; chemins locaux des pages vérifiés.

### [2026.10.9] - 2026-10-01
#### Changed
- `store/archive/site/` devient le conservatoire des versions web : `ultracrea/` et `ultracrea2/` (avec son pipeline de film) vivent désormais dedans, aux côtés des pages du site. Toutes les captures regroupées dans `store/archive/screenshots/` (y compris les captures multi-projets). `media-kit/` conservé.
#### Fixed
- Références réparées sur toutes les pages archivées (site, 404, privacy, terms, ultracrea2, pipeline de rendu) : icône, gif et captures pointent vers les emplacements réels, gifs d'archive restaurés — vérifié par script, chaque cible existe.

### [2026.10.8] - 2026-10-01
#### Fixed
- Restauration complète du contenu supprimé par erreur dans `store/` à la 2026.10.7 : anciennes landings, brouillon `site/`, `media-kit/`, gifs et vidéos non référencés, captures et cartes sociales — tout vit désormais dans `store/archive/` (cartes actives dans `store/media/`). Vérification exhaustive : chaque fichier de la 2026.10.6 a son équivalent, zéro perte.

### [2026.10.7] - 2026-10-01
#### Changed
- `store/` réduit à l'essentiel : la landing `store/index.html`, sa description `store/description-store.md` et un unique dossier `store/media/` (banner, fond, affiche, captures, gif, film). Suppression réelle des anciennes landing archivées, du mini-site `site/` (brouillon FR non déployé, doublon d'index) et des variantes médias non référencées — récupérables via l'historique git si besoin.

### [2026.10.6] - 2026-10-01
#### Changed
- Refacto de `store/` : la landing Ultra Crea 3 (version courante) est promue `store/index.html` (média dans `store/assets/`), les générations précédentes (`ultracrea/`, `ultracrea2/` et son pipeline de film) et les captures multi-projets non référencées sont déplacées dans `store/archive/`. Liens des README FR/EN actualisés.

### [2026.10.5] - 2026-10-01
#### Changed
- Bandeau des README FR/EN : ligne de version synchronisée avec le CHANGELOG et lien direct vers celui-ci.

### [2026.10.4] - 2026-10-01
#### Changed
- Mode par défaut au démarrage : « Fichiers + dossiers » au lieu de « Fichiers » (interface, scan initial et côté natif alignés).

### [2026.10.3] - 2026-10-01
#### Added
- Barre de progression centrale pendant l'archivage : position dans la file (ex. « 1 / 23 »), nom du fichier en cours et pourcentage avec barre de progression, dans un bandeau proéminent entre la route Bureau → Drive et les panneaux.
#### Changed
- Fin de la triple duplication du statut : le détail (fichier, position, %) vit uniquement dans la barre centrale ; le statut sous le titre n'affiche plus que l'état global (« Prêt » / « Archivage en cours… » / « Terminé · N archivé(s) ») ; la ligne de journal n'est plus écrasée par les statuts d'upload ; l'en-tête du panneau Drive affiche un simple compteur « N archivé(s) ».

### [2026.10.2] - 2026-10-01
#### Changed
- Racine du dépôt allégée : `build.sh`, `setup.sh` et `sandbox.sh` déplacés dans `scripts/` (README FR/EN et workflow GitHub mis à jour). La racine ne conserve que `CHANGELOG.md`, `README.md`, `README_en.md`, `ROADMAP.md`, `icon.png` et `appcast.xml` (requis à la racine : URL du feed Sparkle).
#### Removed
- Fichier `VERSION` : la version vit uniquement dans `CHANGELOG.md` (dernier en-tête versionné), lu par `scripts/build.sh` et le script de release.
- `image.png` (non référencé) et `.DS_Store` traqués (`.github/.DS_Store` désuivé, `**/.DS_Store` ré-ignoré après les ré-inclusions `.github`).

### [2026.10.1] - 2026-10-01
#### Added
- Montage automatique du Drive au lancement de l'app (désactivable via `PKARCHIVES_AUTO_MOUNT=0`), en plus du montage post-archivage existant.
#### Fixed
- État de montage cohérent partout : le bouton « Monter le Drive » reflète désormais l'état réel (Montage… / ✓ Drive monté / Réessayer) et devient cliquable pour ouvrir le volume une fois monté. Le statut sous le titre se résout correctement (fini le « Montage… » clignotant contradictoire avec « monté »).
- Nom unique du volume : le montage utilise le nom configuré (`DesktopArchive`) comme `--volname` Finder, identique au dossier `~/DesktopArchive`, au journal et à l'interface (avant : volume Finder « PKarchives » ≠ dossier « DesktopArchive »).

### [2026.09.25] - 2026-09-28
#### Added
- Landing `store/ultracrea3/` : structure Ultra Crea complète (démo interactive fidèle incluse), hero sur le fond d'écran fourni et palette intégralement teal dérivée de ce fond (accent menthe, encres menthe, papiers teal) — aucune couleur crépuscule. Couleurs sémantiques (Drive, Finder, Ko-fi) conservées.

### [2026.09.24] - 2026-09-28
#### Added
- Landing alternative `store/ultracrea2/` : thème turquoise et ambre basé sur le visuel fourni, transitions et parallaxe, sections épurées, version FR/EN.
- Démo interactive guidée par le bouton « Archiver les éléments », avec archivage simulé, échec conservé, mode dossiers et historique.
- Nouveau film 16:9 de 18 secondes et ses sources de montage, intégré à la landing.

### [2026.09.23] - 2026-09-24
#### Fixed
- L'icône Ko-fi est cuite dans un bitmap 32×32px à taille logique 16pt (au lieu d'un `size` fixé sur l'image décodée, ignoré au rendu du menu) : elle tient dans la ligne, nets sur écrans Retina.
- La copie du PNG dans les ressources de l'app est retirée du build : le logo vit uniquement en base64 dans le binaire.

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
